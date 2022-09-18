import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/ime_input_owner.dart';

import 'attributions.dart';
import 'document_input_keyboard.dart';
import 'list_items.dart';

/// Governs document input that comes from the operating system's
/// Input Method Engine (IME).
///
/// IME input is the only form of input that can come from a mobile
/// device's software keyboard. In a desktop environment with a
/// physical keyboard, developers can choose to respond to IME input
/// or individual key presses on the keyboard. For key press input,
/// see super_editor's keyboard input support.

/// Document interactor that changes a document based on IME input
/// from the operating system.
class DocumentImeInteractor extends StatefulWidget {
  const DocumentImeInteractor({
    Key? key,
    this.focusNode,
    this.autofocus = false,
    required this.editContext,
    required this.softwareKeyboardHandler,
    this.hardwareKeyboardActions = const [],
    this.floatingCursorController,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;

  final bool autofocus;

  final EditContext editContext;

  final SoftwareKeyboardHandler softwareKeyboardHandler;

  /// All the actions that the user can execute with physical hardware
  /// keyboard keys.
  ///
  /// [keyboardActions] operates as a Chain of Responsibility. Starting
  /// from the beginning of the list, a [DocumentKeyboardAction] is
  /// given the opportunity to handle the currently pressed keys. If that
  /// [DocumentKeyboardAction] reports the keys as handled, then execution
  /// stops. Otherwise, execution continues to the next [DocumentKeyboardAction].
  final List<DocumentKeyboardAction> hardwareKeyboardActions;

  final FloatingCursorController? floatingCursorController;

  final Widget child;

  @override
  State createState() => _DocumentImeInteractorState();
}

class _DocumentImeInteractorState extends State<DocumentImeInteractor> implements DeltaTextInputClient, ImeInputOwner {
  late FocusNode _focusNode;

  TextInputConnection? _inputConnection;

  @override
  void initState() {
    super.initState();

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    widget.editContext.composer.selectionNotifier.addListener(_onComposerChange);
    widget.editContext.composer.imeConfiguration.addListener(_onClientWantsDifferentImeConfiguration);
  }

  @override
  void didUpdateWidget(DocumentImeInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
    }

    if (widget.editContext.composer.selectionNotifier != oldWidget.editContext.composer.selectionNotifier) {
      oldWidget.editContext.composer.selectionNotifier.removeListener(_onComposerChange);
      widget.editContext.composer.selectionNotifier.addListener(_onComposerChange);
    }
    if (widget.editContext.composer.imeConfiguration != oldWidget.editContext.composer.imeConfiguration) {
      oldWidget.editContext.composer.imeConfiguration.removeListener(_onClientWantsDifferentImeConfiguration);
      oldWidget.editContext.composer.imeConfiguration.addListener(_onClientWantsDifferentImeConfiguration);
    }
  }

  @override
  void dispose() {
    _detachFromIme();

    widget.editContext.composer.imeConfiguration.removeListener(_onClientWantsDifferentImeConfiguration);
    widget.editContext.composer.selectionNotifier.removeListener(_onComposerChange);

    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  @override
  DeltaTextInputClient get imeClient => this;

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      editorImeLog.info('Gained focus');
      _attachToIme();
    } else {
      editorImeLog.info('Lost focus');
      _detachFromIme();
    }
  }

  void _onComposerChange() {
    final selection = widget.editContext.composer.selection;
    editorImeLog.info("Document composer (${widget.editContext.composer.hashCode}) changed. New selection: $selection");

    if (selection == null) {
      _detachFromIme();
    } else {
      if (isAttachedToIme && !_isApplyingDeltas) {
        // Note: ^ We don't re-serialize and send to IME while we're in the middle
        // of applying deltas because we might be in an inconsistent state. A sync
        // will be done when all the deltas have been applied.
        _inputConnection!.show();
        editorImeLog.fine(
            "Document composer changed while attached to IME. Re-serializing the document and sending to the IME.");
        _syncImeWithDocumentAndComposer();
      } else if (!isAttachedToIme) {
        _attachToIme();
      }
    }
  }

  void _onClientWantsDifferentImeConfiguration() {
    if (!isAttachedToIme) {
      return;
    }

    editorImeLog.fine(
        "Updating IME to use new config with action button: ${widget.editContext.composer.imeConfiguration.value.keyboardActionButton}");
    _inputConnection!.updateConfig(_createInputConfiguration());
  }

  bool get isAttachedToIme => _inputConnection?.attached == true;

  void _attachToIme() {
    if (isAttachedToIme) {
      // We're already connected to the IME.
      return;
    }

    editorImeLog.info('Attaching TextInputClient to TextInput');

    _inputConnection = TextInput.attach(
      this,
      _createInputConfiguration(),
    );

    _syncImeWithDocumentAndComposer();

    _inputConnection!
      ..show()
      ..setEditingState(currentTextEditingValue);

    editorImeLog.fine('Is attached to input client? ${_inputConnection!.attached}');
  }

  TextInputConfiguration _createInputConfiguration() {
    final imeConfig = widget.editContext.composer.imeConfiguration.value;

    return TextInputConfiguration(
      enableDeltaModel: true,
      inputType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: imeConfig.enableAutocorrect,
      enableSuggestions: imeConfig.enableSuggestions,
      inputAction: imeConfig.keyboardActionButton,
      keyboardAppearance: imeConfig.keyboardBrightness ?? MediaQuery.of(context).platformBrightness,
    );
  }

  void _detachFromIme() {
    if (!isAttachedToIme) {
      return;
    }

    editorImeLog.info('Detaching TextInputClient from TextInput.');

    widget.editContext.composer.selection = null;

    _inputConnection!.close();
  }

  @override
  // TODO: implement currentAutofillScope
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue get currentTextEditingValue => _currentTextEditingValue;
  TextEditingValue _currentTextEditingValue = const TextEditingValue();
  DocumentImeSerializer? _currentImeSerialization;
  TextEditingValue? _lastTextEditingValueSentToOs;
  set currentTextEditingValue(TextEditingValue newValue) {
    _currentTextEditingValue = newValue;
    if (newValue != _lastTextEditingValueSentToOs && !_isApplyingDeltas) {
      editorImeLog.info("Sending new text editing value to OS: $_currentTextEditingValue");
      _inputConnection?.setEditingState(_currentTextEditingValue);
      _lastTextEditingValueSentToOs = _currentTextEditingValue;
    } else if (_isApplyingDeltas) {
      editorImeLog.fine("Ignoring new TextEditingValue because we're applying deltas");
    } else {
      editorImeLog.fine("Ignoring new TextEditingValue because it's the same as the existing one: $newValue");
    }
  }

  bool _isApplyingDeltas = false;

  void _syncImeWithDocumentAndComposer([TextRange? newComposingRegion]) {
    final selection = widget.editContext.composer.selection;
    if (selection != null) {
      editorImeLog.fine("Syncing IME with Doc and Composer, given composing region: $newComposingRegion");

      final newDocSerialization = DocumentImeSerializer(
        widget.editContext.editor.document,
        selection,
      );

      editorImeLog.fine("Previous doc serialization did prepend? ${_currentImeSerialization?.didPrependPlaceholder}");
      editorImeLog.fine("Desired composing region: $newComposingRegion");
      editorImeLog.fine("Did new doc prepend placeholder? ${newDocSerialization.didPrependPlaceholder}");
      TextRange composingRegion = newComposingRegion ?? currentTextEditingValue.composing;
      if (_currentImeSerialization != null &&
          _currentImeSerialization!.didPrependPlaceholder &&
          composingRegion.isValid &&
          !newDocSerialization.didPrependPlaceholder) {
        // The IME's desired composing region includes the prepended placeholder.
        // The updated IME value doesn't have a prepended placeholder, adjust
        // the composing region bounds.
        composingRegion = TextRange(
          start: composingRegion.start - 2,
          end: composingRegion.end - 2,
        );
      }

      _currentImeSerialization = newDocSerialization;
      currentTextEditingValue = newDocSerialization.toTextEditingValue().copyWith(composing: composingRegion);
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    editorImeLog.info("Received new TextEditingValue from OS: $value");
    setState(() {
      _currentTextEditingValue = value;
    });
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Received edit deltas from platform: ${textEditingDeltas.length} deltas");
    for (final delta in textEditingDeltas) {
      editorImeLog.info("$delta");
    }

    final imeValueBeforeChange = currentTextEditingValue;
    editorImeLog.fine("IME value before applying deltas: $imeValueBeforeChange");

    _isApplyingDeltas = true;
    widget.softwareKeyboardHandler.applyDeltas(textEditingDeltas);
    _isApplyingDeltas = false;

    editorImeLog.fine("Done applying deltas. Serializing the document and sending to IME.");
    _syncImeWithDocumentAndComposer(textEditingDeltas.last.composing);

    editorImeLog.fine("IME value after applying deltas: $currentTextEditingValue");

    final hasDestructiveUpdate =
        textEditingDeltas.where((element) => element is! TextEditingDeltaNonTextUpdate).toList().isNotEmpty;
    if (hasDestructiveUpdate && imeValueBeforeChange == currentTextEditingValue) {
      // Sometimes the IME reports changes to us, but our document doesn't change
      // in ways that's reflected in the IME. In this case, we need to "reset"
      // the IME value to what it was before the deltas.
      //
      // Example: The user has a caret in an empty paragraph. That empty paragraph
      // includes a couple hidden characters, so the IME value might look like:
      //
      //     ". |"
      //
      // The ". " substring is invisible to the user and the "|" represents the caret at
      // the beginning of the empty paragraph.
      //
      // Then the user inserts a newline "\n". This causes Super Editor to insert a new,
      // empty paragraph node, and place the caret in the new, empty paragraph. At this
      // point, we have an issue:
      //
      // This class still sees the TextEditingValue as: ". |"
      //
      // However, the OS IME thinks the TextEditingValue is: ". |\n"
      //
      // In this situation, even though our TextEditingValue looks identical to what it
      // was before, we need to send our TextEditingValue to the OS so that the OS doesn't
      // think there's a "\n" sitting in the edit region.
      editorImeLog.fine(
          "Sending forceful update to IME because our local TextEditingValue didn't change, but the IME may have");
      _inputConnection!.setEditingState(currentTextEditingValue);
    }
  }

  @override
  void performAction(TextInputAction action) {
    editorImeLog.fine("IME says to perform action: $action");
    widget.softwareKeyboardHandler.performAction(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // TODO: implement performPrivateCommand
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // TODO: implement showAutocorrectionPromptRect
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
      case FloatingCursorDragState.Update:
        widget.floatingCursorController?.offset = point.offset;
        break;
      case FloatingCursorDragState.End:
        widget.floatingCursorController?.offset = null;
        break;
    }
  }

  @override
  void insertTextPlaceholder(Size size) {
    // No-op: this is for scribble
  }

  @override
  void removeTextPlaceholder() {
    // No-op: this is for scribble
  }

  @override
  void showToolbar() {
    // No-op: this is for scribble
  }

  @override
  void connectionClosed() {
    editorImeLog.info("IME connection closed");
    _inputConnection = null;
  }

  KeyEventResult _onKeyPressed(FocusNode node, RawKeyEvent keyEvent) {
    if (keyEvent is! RawKeyDownEvent) {
      editorKeyLog.finer("Received key event, but ignoring because it's not a down event: $keyEvent");
      return KeyEventResult.handled;
    }

    editorKeyLog.info("Handling key press: $keyEvent");
    ExecutionInstruction instruction = ExecutionInstruction.continueExecution;
    int index = 0;
    while (instruction == ExecutionInstruction.continueExecution && index < widget.hardwareKeyboardActions.length) {
      instruction = widget.hardwareKeyboardActions[index](
        editContext: widget.editContext,
        keyEvent: keyEvent,
      );
      index += 1;
    }

    switch (instruction) {
      case ExecutionInstruction.haltExecution:
        return KeyEventResult.handled;
      case ExecutionInstruction.continueExecution:
      case ExecutionInstruction.blocked:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKey: widget.hardwareKeyboardActions.isEmpty ? null : _onKeyPressed,
      child: widget.child,
    );
  }
}

class DocumentImeSerializer {
  static const _leadingCharacter = '. ';

  DocumentImeSerializer(this._doc, this._selection) {
    _serialize();
  }

  final Document _doc;
  final DocumentSelection _selection;
  final _imeRangesToDocTextNodes = <TextRange, String>{};
  final _docTextNodesToImeRanges = <String, TextRange>{};
  final _selectedNodes = <DocumentNode>[];
  late String _imeText;
  String _prependedPlaceholder = '';

  void _serialize() {
    editorImeLog.fine("Creating an IME model from document and selection");
    final buffer = StringBuffer();
    int characterCount = 0;

    if (_shouldPrependPlaceholder()) {
      // Put an arbitrary character at the front of the text so that
      // the IME will report backspace buttons when the caret sits at
      // the beginning of the node. For example, the caret is at the
      // beginning of some text and we want to combine this text with
      // the text above it when the user presses backspace.
      //
      //     Text above...
      //     |The selected text node.
      _prependedPlaceholder = _leadingCharacter;
      buffer.write(_prependedPlaceholder);
      characterCount = _prependedPlaceholder.length;
    } else {
      _prependedPlaceholder = '';
    }

    _selectedNodes.clear();
    _selectedNodes.addAll(_doc.getNodesInContentOrder(_selection));
    for (int i = 0; i < _selectedNodes.length; i += 1) {
      // Append a newline character before appending another node's text.
      //
      // The choice to separate each node with a newline was a judgement call.
      // There is no OS-level expectation for how structured content should
      // collapse down to IME content.
      if (i != 0) {
        buffer.write('\n');
        characterCount += 1;
      }

      final node = _selectedNodes[i];
      if (node is! TextNode) {
        buffer.write('~');
        characterCount += 1;

        final imeRange = TextRange(start: characterCount - 1, end: characterCount);
        _imeRangesToDocTextNodes[imeRange] = node.id;
        _docTextNodesToImeRanges[node.id] = imeRange;

        continue;
      }

      // Cache mappings between the IME text range and the document position
      // so that we can easily convert between the two, when requested.
      final imeRange = TextRange(start: characterCount, end: characterCount + node.text.text.length);
      _imeRangesToDocTextNodes[imeRange] = node.id;
      _docTextNodesToImeRanges[node.id] = imeRange;

      // Concatenate this node's text with the previous nodes.
      buffer.write(node.text.text);
      characterCount += node.text.text.length;
    }

    _imeText = buffer.toString();
    editorImeLog.fine("IME serialization:\n'$_imeText'");
  }

  bool _shouldPrependPlaceholder() {
    // We want to prepend an arbitrary placeholder character whenever the
    // user's selection is collapsed at the beginning of a node, and there's
    // another node above the selected node. Without the arbitrary character,
    // the IME would assume that there's no content before the current node and
    // therefore it wouldn't report the backspace button.
    final selectedNode = _doc.getNode(_selection.extent)!;
    final selectedNodeIndex = _doc.getNodeIndex(selectedNode);
    return selectedNodeIndex > 0 &&
        _selection.isCollapsed &&
        _selection.extent.nodePosition == selectedNode.beginningPosition;
  }

  bool get didPrependPlaceholder => _prependedPlaceholder.isNotEmpty;

  DocumentSelection? imeToDocumentSelection(TextSelection imeSelection) {
    editorImeLog.fine("Creating doc selection from IME selection: $imeSelection");
    if (didPrependPlaceholder &&
        ((!imeSelection.isCollapsed && imeSelection.start < _prependedPlaceholder.length) ||
            (imeSelection.isCollapsed && imeSelection.extentOffset <= _prependedPlaceholder.length))) {
      // The IME is trying to select our artificial prepended character.
      // If that's the only character that the IME is trying to select, then
      // return a null selection to indicate that there's nothing to select.
      // If the selection is expanded, then remove the arbitrary character from
      // the selection.
      if ((imeSelection.isCollapsed && imeSelection.extentOffset < _prependedPlaceholder.length) ||
          (imeSelection.start < _prependedPlaceholder.length && imeSelection.end == _prependedPlaceholder.length)) {
        editorImeLog.fine("Returning null doc selection");
        return null;
      } else {
        editorImeLog.fine("Removing arbitrary character from IME selection");
        imeSelection = imeSelection.copyWith(
          baseOffset: min(imeSelection.baseOffset, _prependedPlaceholder.length),
          extentOffset: min(imeSelection.extentOffset, _prependedPlaceholder.length),
        );
        editorImeLog.fine("Adjusted IME selection is: $imeSelection");
      }
    } else {
      editorImeLog.fine("Mapping the IME base/extent to their corresponding doc positions without modification.");
    }

    return DocumentSelection(
      base: _imeToDocumentPosition(
        imeSelection.base,
        isUpstream: imeSelection.base.affinity == TextAffinity.upstream,
      ),
      extent: _imeToDocumentPosition(
        imeSelection.extent,
        isUpstream: imeSelection.extent.affinity == TextAffinity.upstream,
      ),
    );
  }

  DocumentPosition _imeToDocumentPosition(TextPosition imePosition, {required bool isUpstream}) {
    for (final range in _imeRangesToDocTextNodes.keys) {
      if (imePosition.offset >= range.start && imePosition.offset <= range.end) {
        final node = _doc.getNodeById(_imeRangesToDocTextNodes[range]!)!;

        if (node is TextNode) {
          return DocumentPosition(
            nodeId: _imeRangesToDocTextNodes[range]!,
            nodePosition: TextNodePosition(offset: imePosition.offset - range.start),
          );
        } else {
          if (imePosition.offset <= range.start) {
            // Return a position at the start of the node.
            return DocumentPosition(
              nodeId: node.id,
              nodePosition: node.beginningPosition,
            );
          } else {
            // Return a position at the end of the node.
            return DocumentPosition(
              nodeId: node.id,
              nodePosition: node.endPosition,
            );
          }
        }
      }
    }

    editorImeLog.shout(
        "Couldn't map an IME position to a document position. IME position: $imePosition. The selected offset range is: ${_imeRangesToDocTextNodes.keys.last.start} -> ${_imeRangesToDocTextNodes.keys.last.end}");
    throw Exception("Couldn't map an IME position to a document position. IME position: $imePosition");
  }

  TextSelection documentToImeSelection(DocumentSelection docSelection) {
    editorImeLog.fine("Converting doc selection to ime selection: $docSelection");
    final selectionAffinity = _doc.getAffinityForSelection(docSelection);

    final startDocPosition = selectionAffinity == TextAffinity.downstream ? docSelection.base : docSelection.extent;
    final startImePosition = _documentToImePosition(startDocPosition);

    final endDocPosition = selectionAffinity == TextAffinity.downstream ? docSelection.extent : docSelection.base;
    final endImePosition = _documentToImePosition(endDocPosition);

    editorImeLog.fine("Start IME position: $startImePosition");
    editorImeLog.fine("End IME position: $endImePosition");
    return TextSelection(
      baseOffset: startImePosition.offset,
      extentOffset: endImePosition.offset,
      affinity: startImePosition == endImePosition ? endImePosition.affinity : TextAffinity.downstream,
    );
  }

  TextPosition _documentToImePosition(DocumentPosition docPosition) {
    editorImeLog.fine("Converting DocumentPosition to IME TextPosition: $docPosition");
    final imeRange = _docTextNodesToImeRanges[docPosition.nodeId];
    if (imeRange == null) {
      throw Exception("No such document position in the IME content: $docPosition");
    }

    final nodePosition = docPosition.nodePosition;

    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.upstream) {
        editorImeLog.fine("The doc position is an upstream position on a block.");
        // Return the text position before the special character,
        // e.g., "|~".
        return TextPosition(offset: imeRange.start);
      } else {
        editorImeLog.fine("The doc position is a downstream position on a block.");
        // Return the text position after the special character,
        // e.g., "~|".
        return TextPosition(offset: imeRange.start + 1);
      }
    }

    if (nodePosition is TextNodePosition) {
      return TextPosition(offset: imeRange.start + (docPosition.nodePosition as TextNodePosition).offset);
    }

    throw Exception("Super Editor doesn't know how to convert a $nodePosition into an IME-compatible selection");
  }

  TextEditingValue toTextEditingValue() {
    editorImeLog.fine("Creating TextEditingValue from document. Selection: $_selection");
    editorImeLog.fine("Text:\n'$_imeText'");
    final imeSelection = documentToImeSelection(_selection);
    editorImeLog.fine("Selection: $imeSelection");

    return TextEditingValue(
      text: _imeText,
      selection: imeSelection,
    );
  }

  /// Narrows the given [selection] until the base and extent both point to
  /// `TextNode`s.
  ///
  /// If the given [selection] base and/or extent already point to a `TextNode`
  /// then those same end-caps are retained in the returned `DocumentSelection`.
  ///
  /// If there is no text content within the [selection], `null` is returned.
  DocumentSelection? _constrictToTextSelectionEndCaps(DocumentSelection selection) {
    final baseNode = _doc.getNodeById(selection.base.nodeId)!;
    final baseNodeIndex = _doc.getNodeIndex(baseNode);
    final extentNode = _doc.getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = _doc.getNodeIndex(extentNode);

    final startNode = baseNodeIndex <= extentNodeIndex ? baseNode : extentNode;
    final startNodeIndex = _doc.getNodeIndex(startNode);
    final startPosition =
        baseNodeIndex <= extentNodeIndex ? selection.base.nodePosition : selection.extent.nodePosition;
    final endNode = baseNodeIndex <= extentNodeIndex ? extentNode : baseNode;
    final endNodeIndex = _doc.getNodeIndex(endNode);
    final endPosition = baseNodeIndex <= extentNodeIndex ? selection.extent.nodePosition : selection.base.nodePosition;

    if (startNodeIndex == endNodeIndex) {
      // The document selection is all in one node.
      if (startNode is! TextNode) {
        // The only content selected is non-text. Return null.
        return null;
      }

      // Part of a single TextNode is selected, therefore, the given selection
      // is already restricted to text end caps.
      return selection;
    }

    DocumentNode? restrictedStartNode;
    TextNodePosition? restrictedStartPosition;
    if (startNode is TextNode) {
      restrictedStartNode = startNode;
      restrictedStartPosition = startPosition as TextNodePosition;
    } else {
      int restrictedStartNodeIndex = startNodeIndex + 1;
      while (_doc.getNodeAt(restrictedStartNodeIndex) is! TextNode && restrictedStartNodeIndex <= endNodeIndex) {
        restrictedStartNodeIndex += 1;
      }

      if (_doc.getNodeAt(restrictedStartNodeIndex) is TextNode) {
        restrictedStartNode = _doc.getNodeAt(restrictedStartNodeIndex);
        restrictedStartPosition = const TextNodePosition(offset: 0);
      }
    }

    DocumentNode? restrictedEndNode;
    TextNodePosition? restrictedEndPosition;
    if (endNode is TextNode) {
      restrictedEndNode = endNode;
      restrictedEndPosition = endPosition as TextNodePosition;
    } else {
      int restrictedEndNodeIndex = endNodeIndex - 1;
      while (_doc.getNodeAt(restrictedEndNodeIndex) is! TextNode && restrictedEndNodeIndex >= startNodeIndex) {
        restrictedEndNodeIndex -= 1;
      }

      if (_doc.getNodeAt(restrictedEndNodeIndex) is TextNode) {
        restrictedEndNode = _doc.getNodeAt(restrictedEndNodeIndex);
        restrictedEndPosition = TextNodePosition(offset: (restrictedEndNode as TextNode).text.text.length);
      }
    }

    // If there was no text between the selection end-caps, return null.
    if (restrictedStartPosition == null || restrictedEndPosition == null) {
      return null;
    }

    return DocumentSelection(
      base: DocumentPosition(
        nodeId: restrictedStartNode!.id,
        nodePosition: restrictedStartPosition,
      ),
      extent: DocumentPosition(
        nodeId: restrictedEndNode!.id,
        nodePosition: restrictedEndPosition,
      ),
    );
  }

  /// Serializes just enough document text to serve the needs of the IME.
  ///
  /// The serialized text includes all the content of all partially selected
  /// nodes, plus one node on either side to allow for upstream and downstream
  /// deletions. For example, the user press backspace at the beginning of a
  /// paragraph. We need to tell the IME that there's content before the paragraph
  /// so that the IME sends us the delete delta.
  String _getMinimumTextForIME(DocumentSelection selection) {
    final baseNode = _doc.getNodeById(selection.base.nodeId)!;
    final baseNodeIndex = _doc.getNodeIndex(baseNode);
    final extentNode = _doc.getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = _doc.getNodeIndex(extentNode);

    final selectionStartNode = baseNodeIndex <= extentNodeIndex ? baseNode : extentNode;
    final selectionStartNodeIndex = _doc.getNodeIndex(selectionStartNode);
    final startNodeIndex = max(selectionStartNodeIndex - 1, 0);

    final selectionEndNode = baseNodeIndex <= extentNodeIndex ? extentNode : baseNode;
    final selectionEndNodeIndex = _doc.getNodeIndex(selectionEndNode);
    final endNodeIndex = min(selectionEndNodeIndex + 1, _doc.nodes.length - 1);

    final buffer = StringBuffer();
    for (int i = startNodeIndex; i <= endNodeIndex; i += 1) {
      final node = _doc.getNodeAt(i);
      if (node is! TextNode) {
        continue;
      }

      if (buffer.length > 0) {
        buffer.write('\n');
      }

      buffer.write(node.text.text);
    }

    return buffer.toString();
  }
}

/// Input Method Engine (IME) configuration for document text input.
///
/// The IME is an operating system component that observes text that's
/// being edited, and intercepts keyboard input to apply transforms to
/// the user's input. The alternative to IME input is for an app to
/// listen and respond to each individual keyboard key. On mobile, IME
/// input is the only available input system because there is no physical
/// keyboard.
class ImeConfiguration {
  const ImeConfiguration({
    this.enableAutocorrect = true,
    this.enableSuggestions = true,
    this.keyboardBrightness,
    this.keyboardActionButton = TextInputAction.newline,
  });

  /// Whether the OS should offer auto-correction options to the user.
  final bool enableAutocorrect;

  /// Whether the OS should offer text completion suggestions to the user.
  final bool enableSuggestions;

  /// The brightness of the software keyboard (only applies to platforms
  /// with a software keyboard).
  final Brightness? keyboardBrightness;

  /// The action button that's displayed on a software keyboard, e.g.,
  /// new-line, done, go, etc.
  final TextInputAction keyboardActionButton;

  ImeConfiguration copyWith({
    bool? enableAutocorrect,
    bool? enableSuggestions,
    Brightness? keyboardBrightness,
    TextInputAction? keyboardActionButton,
  }) {
    return ImeConfiguration(
      enableAutocorrect: enableAutocorrect ?? this.enableAutocorrect,
      enableSuggestions: enableSuggestions ?? this.enableSuggestions,
      keyboardBrightness: keyboardBrightness ?? this.keyboardBrightness,
      keyboardActionButton: keyboardActionButton ?? this.keyboardActionButton,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImeConfiguration &&
          runtimeType == other.runtimeType &&
          enableAutocorrect == other.enableAutocorrect &&
          enableSuggestions == other.enableSuggestions &&
          keyboardBrightness == other.keyboardBrightness &&
          keyboardActionButton == other.keyboardActionButton;

  @override
  int get hashCode =>
      enableAutocorrect.hashCode ^
      enableSuggestions.hashCode ^
      keyboardBrightness.hashCode ^
      keyboardActionButton.hashCode;
}

/// Applies software keyboard edits to a document.
class SoftwareKeyboardHandler {
  const SoftwareKeyboardHandler({
    required this.editor,
    required this.composer,
    required this.commonOps,
  });

  final DocumentEditor editor;
  final DocumentComposer composer;
  final CommonEditorOperations commonOps;

  /// Applies the given [textEditingDeltas] to the [Document].
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Applying ${textEditingDeltas.length} IME deltas to document");

    for (final delta in textEditingDeltas) {
      editorImeLog.info("Applying delta: $delta");
      if (delta is TextEditingDeltaInsertion) {
        _applyInsertion(delta);
      } else if (delta is TextEditingDeltaReplacement) {
        _applyReplacement(delta);
      } else if (delta is TextEditingDeltaDeletion) {
        _applyDeletion(delta);
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        _applyNonTextChange(delta);
      } else {
        editorImeLog.shout("Unknown IME delta type: ${delta.runtimeType}");
      }
    }
  }

  void _applyInsertion(TextEditingDeltaInsertion delta) {
    editorImeLog.fine('Inserted text: "${delta.textInserted}"');
    editorImeLog.fine("Insertion offset: ${delta.insertionOffset}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.textInserted == "\n") {
      // On iOS, newlines are reported here and also to performAction().
      // On Android and web, newlines are only reported here. So, on Android and web,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) {
        editorImeLog.fine("Received a newline insertion on Android. Forwarding to newline input action.");
        performAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping insertion delta because its a newline");
      }
      return;
    }

    if (delta.textInserted == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();
      return;
    }

    editorImeLog.fine(
        "Inserting text: ${delta.textInserted}, insertion offset: ${delta.insertionOffset}, ime selection: ${delta.selection}");

    insert(
      TextPosition(offset: delta.insertionOffset, affinity: delta.selection.affinity),
      delta.textInserted,
    );
  }

  void _applyReplacement(TextEditingDeltaReplacement delta) {
    editorImeLog.fine("Text replaced: '${delta.textReplaced}'");
    editorImeLog.fine("Replacement text: '${delta.replacementText}'");
    editorImeLog.fine("Replaced range: ${delta.replacedRange}");
    editorImeLog.fine("Selection: ${delta.selection}");
    editorImeLog.fine("Composing: ${delta.composing}");
    editorImeLog.fine('Old text: "${delta.oldText}"');

    if (delta.replacementText == "\n") {
      // On iOS, newlines are reported here and also to performAction().
      // On Android and web, newlines are only reported here. So, on Android and web,
      // we forward the newline action to performAction.
      if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) {
        editorImeLog.fine("Received a newline replacement on Android. Forwarding to newline input action.");
        performAction(TextInputAction.newline);
      } else {
        editorImeLog.fine("Skipping replacement delta because its a newline");
      }
      return;
    }

    if (delta.replacementText == "\t" && (defaultTargetPlatform == TargetPlatform.iOS)) {
      // On iOS, tabs pressed at the the software keyboard are reported here.
      commonOps.indentListItem();
      return;
    }

    replace(delta.replacedRange, delta.replacementText);
  }

  void _applyDeletion(TextEditingDeltaDeletion delta) {
    editorImeLog.fine("Delete delta:\n"
        "Text deleted: '${delta.textDeleted}'\n"
        "Deleted Range: ${delta.deletedRange}\n"
        "Selection: ${delta.selection}\n"
        "Composing: ${delta.composing}\n"
        "Old text: '${delta.oldText}'");

    delete(delta.deletedRange);

    editorImeLog.fine("Deletion operation complete");
  }

  void _applyNonTextChange(TextEditingDeltaNonTextUpdate delta) {
    editorImeLog.fine("Non-text change:");
    // editorImeLog.fine("App-side selection - ${currentTextEditingValue.selection}");
    // editorImeLog.fine("App-side composing - ${currentTextEditingValue.composing}");
    editorImeLog.fine("OS-side selection - ${delta.selection}");
    editorImeLog.fine("OS-side composing - ${delta.composing}");
    // currentTextEditingValue = _currentTextEditingValue.copyWith(composing: delta.composing);
  }

  void insert(TextPosition insertionPosition, String textInserted) {
    if (textInserted == "\n") {
      // Newlines are handled in performAction()
      return;
    }

    editorImeLog.fine('Inserting "$textInserted" at position "$insertionPosition"');
    editorImeLog.fine("Serializing document to perform IME operation");
    final docSerializer = DocumentImeSerializer(
      editor.document,
      composer.selection!,
    );
    editorImeLog.fine("Converting IME insertion offset into a DocumentSelection");
    final insertionSelection = docSerializer.imeToDocumentSelection(
      TextSelection.fromPosition(insertionPosition),
    );
    editorImeLog
        .fine("Updating the Document Composer's selection to place caret at insertion offset:\n$insertionSelection");
    final selectionBeforeInsertion = composer.selection;
    composer.selection = insertionSelection;

    editorImeLog.fine("Inserting the text at the Document Composer's selection");
    final didInsert = commonOps.insertPlainText(textInserted);
    editorImeLog.fine("Insertion successful? $didInsert");

    if (!didInsert) {
      editorImeLog.fine("Failed to insert characters. Restoring previous selection.");
      composer.selection = selectionBeforeInsertion;
    }

    commonOps.convertParagraphByPatternMatching(
      composer.selection!.extent.nodeId,
    );
  }

  void replace(TextRange replacedRange, String replacementText) {
    final docSerializer = DocumentImeSerializer(
      editor.document,
      composer.selection!,
    );

    final replacementSelection = docSerializer.imeToDocumentSelection(TextSelection(
      baseOffset: replacedRange.start,
      // TODO: the delta API is wrong for TextRange.end, it should be exclusive,
      //       but it's implemented as inclusive. Change this code when Flutter
      //       fixes the problem.
      extentOffset: replacedRange.end,
    ));

    if (replacementSelection != null) {
      composer.selection = replacementSelection;
    }
    editorImeLog.fine("Replacing selection: $replacementSelection");
    editorImeLog.fine('With text: "$replacementText"');

    if (replacementText == "\n") {
      performAction(TextInputAction.newline);
      return;
    }

    commonOps.insertPlainText(replacementText);

    commonOps.convertParagraphByPatternMatching(
      composer.selection!.extent.nodeId,
    );
  }

  void delete(TextRange deletedRange) {
    final rangeToDelete = deletedRange;
    final docSerializer = DocumentImeSerializer(
      editor.document,
      composer.selection!,
    );
    final docSelectionToDelete = docSerializer.imeToDocumentSelection(TextSelection(
      baseOffset: rangeToDelete.start,
      extentOffset: rangeToDelete.end,
    ));
    editorImeLog.fine("Doc selection to delete: $docSelectionToDelete");

    if (docSelectionToDelete == null) {
      final selectedNodeIndex = editor.document.getNodeIndexById(
        composer.selection!.extent.nodeId,
      );
      if (selectedNodeIndex > 0) {
        // The user is trying to delete upstream at the start of a node.
        // This action requires intervention because the IME doesn't know
        // that there's more content before this node. Instruct the editor
        // to run a delete action upstream, which will take the desired
        // "backspace" behavior at the start of this node.
        commonOps.deleteUpstream();
        editorImeLog.fine("Deleted upstream. New selection: ${composer.selection}");
        return;
      }
    }

    editorImeLog.fine("Running selection deletion operation");
    composer.selection = docSelectionToDelete;
    commonOps.deleteSelection();
  }

  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        if (!composer.selection!.isCollapsed) {
          commonOps.deleteSelection();
        }
        commonOps.insertBlockLevelNewline();
        break;
      case TextInputAction.none:
        // no-op
        break;
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.search:
      case TextInputAction.send:
      case TextInputAction.next:
      case TextInputAction.previous:
      case TextInputAction.continueAction:
      case TextInputAction.join:
      case TextInputAction.route:
      case TextInputAction.emergencyCall:
      case TextInputAction.unspecified:
        editorImeLog.warning("User pressed unhandled action button: $action");
        break;
    }
  }
}

/// Toolbar that provides document editing capabilities, like converting
/// paragraphs to blockquotes and list items, and inserting horizontal
/// rules.
///
/// This toolbar is intended to be placed just above the keyboard on a
/// mobile device.
class KeyboardEditingToolbar extends StatelessWidget {
  const KeyboardEditingToolbar({
    Key? key,
    required this.document,
    required this.composer,
    required this.commonOps,
    this.brightness,
  }) : super(key: key);

  final Document document;
  final DocumentComposer composer;
  final CommonEditorOperations commonOps;
  final Brightness? brightness;

  bool get _isBoldActive => _doesSelectionHaveAttributions({boldAttribution});
  void _toggleBold() => _toggleAttributions({boldAttribution});

  bool get _isItalicsActive => _doesSelectionHaveAttributions({italicsAttribution});
  void _toggleItalics() => _toggleAttributions({italicsAttribution});

  bool get _isUnderlineActive => _doesSelectionHaveAttributions({underlineAttribution});
  void _toggleUnderline() => _toggleAttributions({underlineAttribution});

  bool get _isStrikethroughActive => _doesSelectionHaveAttributions({strikethroughAttribution});
  void _toggleStrikethrough() => _toggleAttributions({strikethroughAttribution});

  bool _doesSelectionHaveAttributions(Set<Attribution> attributions) {
    final selection = composer.selection;
    if (selection == null) {
      return false;
    }

    if (selection.isCollapsed) {
      return composer.preferences.currentAttributions.containsAll(attributions);
    }

    return document.doesSelectedTextContainAttributions(selection, attributions);
  }

  void _toggleAttributions(Set<Attribution> attributions) {
    final selection = composer.selection;
    if (selection == null) {
      return;
    }

    selection.isCollapsed
        ? commonOps.toggleComposerAttributions(attributions)
        : commonOps.toggleAttributionsOnSelection(attributions);
  }

  void _convertToHeader1() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId);
    if (selectedNode is! TextNode) {
      return;
    }

    if (selectedNode is ListItemNode) {
      commonOps.convertToParagraph(
        newMetadata: {
          'blockType': header1Attribution,
        },
      );
    } else {
      selectedNode.putMetadataValue('blockType', header1Attribution);
    }
  }

  void _convertToHeader2() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId);
    if (selectedNode is! TextNode) {
      return;
    }

    if (selectedNode is ListItemNode) {
      commonOps.convertToParagraph(
        newMetadata: {
          'blockType': header2Attribution,
        },
      );
    } else {
      selectedNode.putMetadataValue('blockType', header2Attribution);
    }
  }

  void _convertToParagraph() {
    commonOps.convertToParagraph();
  }

  void _convertToOrderedListItem() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToListItem(ListItemType.ordered, selectedNode.text);
  }

  void _convertToUnorderedListItem() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToListItem(ListItemType.unordered, selectedNode.text);
  }

  void _convertToBlockquote() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    commonOps.convertToBlockquote(selectedNode.text);
  }

  void _convertToHr() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    selectedNode.text = AttributedText(text: '--- ');
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: selectedNode.id,
        nodePosition: const TextNodePosition(offset: 4),
      ),
    );
    commonOps.convertParagraphByPatternMatching(selectedNode.id);
  }

  void _closeKeyboard() {
    composer.selection = null;
  }

  @override
  Widget build(BuildContext context) {
    final selection = composer.selection;

    if (selection == null) {
      return const SizedBox();
    }

    final brightness = this.brightness ?? MediaQuery.of(context).platformBrightness;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: brightness,
        disabledColor: brightness == Brightness.light ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
      ),
      child: IconTheme(
        data: IconThemeData(
          color: brightness == Brightness.light ? Colors.black : Colors.white,
        ),
        child: Material(
          child: Container(
            width: double.infinity,
            height: 48,
            color: brightness == Brightness.light ? const Color(0xFFDDDDDD) : const Color(0xFF222222),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ListenableBuilder(
                        listenable: composer,
                        builder: (context) {
                          final selectedNode = document.getNodeById(selection.extent.nodeId);
                          final isSingleNodeSelected = selection.extent.nodeId == selection.base.nodeId;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleBold : null,
                                icon: const Icon(Icons.format_bold),
                                color: _isBoldActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleItalics : null,
                                icon: const Icon(Icons.format_italic),
                                color: _isItalicsActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleUnderline : null,
                                icon: const Icon(Icons.format_underline),
                                color: _isUnderlineActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: selectedNode is TextNode ? _toggleStrikethrough : null,
                                icon: const Icon(Icons.strikethrough_s),
                                color: _isStrikethroughActive ? Theme.of(context).primaryColor : null,
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode &&
                                            selectedNode.getMetadataValue('blockType') != header1Attribution)
                                    ? _convertToHeader1
                                    : null,
                                icon: const Icon(Icons.title),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode &&
                                            selectedNode.getMetadataValue('blockType') != header2Attribution)
                                    ? _convertToHeader2
                                    : null,
                                icon: const Icon(Icons.title),
                                iconSize: 18,
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        ((selectedNode is ParagraphNode &&
                                                selectedNode.hasMetadataValue('blockType')) ||
                                            (selectedNode is TextNode && selectedNode is! ParagraphNode))
                                    ? _convertToParagraph
                                    : null,
                                icon: const Icon(Icons.wrap_text),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                            (selectedNode is ListItemNode && selectedNode.type != ListItemType.ordered))
                                    ? _convertToOrderedListItem
                                    : null,
                                icon: const Icon(Icons.looks_one_rounded),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                            (selectedNode is ListItemNode &&
                                                selectedNode.type != ListItemType.unordered))
                                    ? _convertToUnorderedListItem
                                    : null,
                                icon: const Icon(Icons.list),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        selectedNode is TextNode &&
                                        (selectedNode is! ParagraphNode ||
                                            selectedNode.getMetadataValue('blockType') != blockquoteAttribution)
                                    ? _convertToBlockquote
                                    : null,
                                icon: const Icon(Icons.format_quote),
                              ),
                              IconButton(
                                onPressed: isSingleNodeSelected &&
                                        selectedNode is ParagraphNode &&
                                        selectedNode.text.text.isEmpty
                                    ? _convertToHr
                                    : null,
                                icon: const Icon(Icons.horizontal_rule),
                              ),
                            ],
                          );
                        }),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFCCCCCC),
                ),
                IconButton(
                  onPressed: _closeKeyboard,
                  icon: const Icon(Icons.keyboard_hide),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
