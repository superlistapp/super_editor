import 'dart:math';

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
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import 'attributions.dart';
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
    required this.editContext,
    required this.softwareKeyboardHandler,
    this.floatingCursorController,
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;
  final EditContext editContext;
  final SoftwareKeyboardHandler softwareKeyboardHandler;
  final FloatingCursorController? floatingCursorController;
  final Widget child;

  @override
  _DocumentImeInteractorState createState() => _DocumentImeInteractorState();
}

class _DocumentImeInteractorState extends State<DocumentImeInteractor> implements DeltaTextInputClient {
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
      if (isAttachedToIme) {
        _syncImeWithDocumentAndComposer();
      } else {
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
  set currentTextEditingValue(TextEditingValue newValue) {
    if (newValue != _currentTextEditingValue) {
      _currentTextEditingValue = newValue;
      editorImeLog.info("Sending new text editing value to OS: $_currentTextEditingValue");
      _inputConnection?.setEditingState(_currentTextEditingValue);
    }
  }

  void _syncImeWithDocumentAndComposer() {
    final selection = widget.editContext.composer.selection;
    if (selection != null) {
      editorImeLog.fine("Syncing IME with Doc and Composer");
      currentTextEditingValue = DocumentImeSerializer(
        widget.editContext.editor.document,
        selection,
      ).toTextEditingValue();
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
    editorImeLog.info("Received edit deltas from platform");
    for (final delta in textEditingDeltas) {
      editorImeLog.info("$delta");
    }

    for (final delta in textEditingDeltas) {
      editorImeLog.info("Applying delta: $delta");
      if (delta is TextEditingDeltaInsertion) {
        if (delta.textInserted == "\n") {
          // On iOS, newlines are reported here and also to performAction().
          // On Android, newlines are only reported here. So, on Android only,
          // we forward the newline action to performAction.
          if (defaultTargetPlatform == TargetPlatform.android) {
            editorImeLog.fine("Received a newline insertion on Android. Forwarding to newline input action.");
            widget.softwareKeyboardHandler.performAction(TextInputAction.newline);
          } else {
            editorImeLog.fine("Skipping insertion delta because its a newline");
          }
          continue;
        }

        editorImeLog.fine("Inserting text: ${delta.textInserted}, insertion offset: ${delta.insertionOffset}");

        final imeValueBeforeChange = currentTextEditingValue;
        widget.softwareKeyboardHandler.insert(delta.insertionOffset, delta.textInserted);

        if (delta.textInserted == "\n" && imeValueBeforeChange == currentTextEditingValue) {
          // The newline action didn't change the current IME content or
          // selection. This can happen, for example, when an empty list
          // item is converted to a paragraph. Here, we explicitly reset
          // the IME value to what it was before the newline so that the
          // IME doesn't think there's a "\n" character in the content.
          _inputConnection!.setEditingState(currentTextEditingValue);
        }
      } else if (delta is TextEditingDeltaReplacement) {
        editorImeLog.fine("Replacing text: ${delta.textReplaced}");
        editorImeLog.fine("With new text: ${delta.replacementText}");
        editorImeLog.fine("Replaced range: ${delta.replacedRange}");
        editorImeLog.fine("New selection: ${delta.selection}");

        if (delta.replacementText == "\n") {
          // On iOS, newlines are reported here and also to performAction().
          // On Android, newlines are only reported here. So, on Android only,
          // we forward the newline action to performAction.
          if (defaultTargetPlatform == TargetPlatform.android) {
            editorImeLog.fine("Received a newline replacement on Android. Forwarding to newline input action.");
            widget.softwareKeyboardHandler.performAction(TextInputAction.newline);
          } else {
            editorImeLog.fine("Skipping replacement delta because its a newline");
          }
          continue;
        }

        widget.softwareKeyboardHandler.replace(delta.replacedRange, delta.replacementText);
      } else if (delta is TextEditingDeltaDeletion) {
        editorImeLog.fine("Deleting text: ${delta.textDeleted}");
        editorImeLog.fine("Deleted range: ${delta.deletedRange}");

        widget.softwareKeyboardHandler.delete(delta.deletedRange);

        _syncImeWithDocumentAndComposer();
        editorImeLog.fine("Deletion operation complete");
      } else if (delta is TextEditingDeltaNonTextUpdate) {
        editorImeLog.fine("Non-text change:");
        editorImeLog.fine("App-side selection - ${currentTextEditingValue.selection}");
        editorImeLog.fine("App-side composing - ${currentTextEditingValue.composing}");
        editorImeLog.fine("OS-side selection - ${delta.selection}");
        editorImeLog.fine("OS-side composing - ${delta.composing}");
        currentTextEditingValue = _currentTextEditingValue.copyWith(composing: delta.composing);
      } else {
        editorImeLog.shout("Unknown IME delta type: ${delta.runtimeType}");
      }
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
  void connectionClosed() {
    editorImeLog.info("IME connection closed");
    _inputConnection = null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: widget.child,
    );
  }
}

class DocumentImeSerializer {
  static const _leadingCharacters = ['*', '^', '`'];
  static int _nextLeadingCharacterIndex = 0;
  static String _nextLeadingCharacter() {
    final nextCharacter = _leadingCharacters[_nextLeadingCharacterIndex];
    _nextLeadingCharacterIndex = (_nextLeadingCharacterIndex + 1) % _leadingCharacters.length;
    return nextCharacter;
  }

  DocumentImeSerializer(this._doc, this._selection) {
    _serialize();
  }

  final Document _doc;
  final DocumentSelection _selection;
  final _imeRangesToDocTextNodes = <TextRange, String>{};
  final _docTextNodesToImeRanges = <String, TextRange>{};
  final _selectedNodes = <DocumentNode>[];
  late String _imeText;
  late bool _didPrependPlaceholder;
  String? _prependedCharacter;

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
      _prependedCharacter = _nextLeadingCharacter();
      editorImeLog.fine("Prepending upstream character for IME: $_prependedCharacter");
      buffer.write(_prependedCharacter);
      characterCount = 1;
      _didPrependPlaceholder = true;
    } else {
      editorImeLog.fine("No prepended upstream character is needed");
      _didPrependPlaceholder = false;
      _prependedCharacter = null;
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
        editorImeLog.fine("Appending a special character to represent a non-text node: $node");
        buffer.write('~');
        characterCount += 1;

        final imeRange = TextRange(start: characterCount - 1, end: characterCount);
        editorImeLog.fine("Node ${node.id} occupies the following IME range: $imeRange");
        _imeRangesToDocTextNodes[imeRange] = node.id;
        _docTextNodesToImeRanges[node.id] = imeRange;

        continue;
      }

      editorImeLog.fine("Appending a text node to IME content: $node");
      // Cache mappings between the IME text range and the document position
      // so that we can easily convert between the two, when requested.
      final imeRange = TextRange(start: characterCount, end: characterCount + node.text.text.length);
      editorImeLog.fine("Node ${node.id} occupies the following IME range: $imeRange");
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

  DocumentSelection? imeToDocumentSelection(TextSelection imeSelection) {
    editorImeLog.fine("Creating doc selection from IME selection: $imeSelection");
    if (_didPrependPlaceholder &&
        ((!imeSelection.isCollapsed && imeSelection.start == 0) ||
            (imeSelection.isCollapsed && imeSelection.extentOffset == 1))) {
      // The IME is trying to select our artificial prepended character.
      // If that's the only character that the IME is trying to select, then
      // return a null selection to indicate that there's nothing to select.
      // If the selection is expanded, then remove the arbitrary character from
      // the selection.
      if ((imeSelection.isCollapsed && imeSelection.extentOffset == 0) ||
          (imeSelection.start == 0 && imeSelection.end == 1)) {
        editorImeLog.fine("Returning null doc selection");
        return null;
      } else {
        editorImeLog.fine("Removing arbitrary character from IME selection");
        imeSelection = imeSelection.copyWith(
          baseOffset: imeSelection.affinity == TextAffinity.downstream ? 1 : imeSelection.baseOffset,
          extentOffset: imeSelection.affinity == TextAffinity.downstream ? imeSelection.extentOffset : 1,
        );
      }
    } else {
      editorImeLog.fine("Returning doc selection without modification");
    }

    return DocumentSelection(
      base: _imeToDocumentPosition(imeSelection.base, isUpstream: true),
      extent: _imeToDocumentPosition(imeSelection.extent, isUpstream: false),
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
          if (isUpstream) {
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

    final startPosition = selectionAffinity == TextAffinity.downstream ? docSelection.base : docSelection.extent;
    final startOffset = _documentToImePosition(startPosition, isUpstream: true).offset;

    final endPosition = selectionAffinity == TextAffinity.downstream ? docSelection.extent : docSelection.base;
    final endOffset = _documentToImePosition(endPosition, isUpstream: false).offset;

    editorImeLog.fine("Start offset: $startOffset");
    editorImeLog.fine("End offset: $endOffset");
    return TextSelection(
      baseOffset: startOffset,
      extentOffset: endOffset,
    );
  }

  TextPosition _documentToImePosition(DocumentPosition docPosition, {required bool isUpstream}) {
    final imeRange = _docTextNodesToImeRanges[docPosition.nodeId];
    if (imeRange == null) {
      throw Exception("No such document position in the IME content: $docPosition");
    }

    if (docPosition.nodePosition is! TextNodePosition) {
      if (isUpstream) {
        // Return the text position before the special character,
        // e.g., "|~".
        return TextPosition(offset: imeRange.start);
      } else {
        // Return the text position after the special character,
        // e.g., "~|".
        return TextPosition(offset: imeRange.start + 1);
      }
    }

    return TextPosition(offset: imeRange.start + (docPosition.nodePosition as TextNodePosition).offset);
  }

  TextEditingValue toTextEditingValue() {
    editorImeLog.fine("Creating TextEditingValue from document. Selection: $_selection");
    editorImeLog.fine("Text:\n$_imeText");
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

  void insert(int insertionOffset, String textInserted) {
    if (textInserted == "\n") {
      // Newlines are handled in performAction()
      return;
    }

    final docSerializer = DocumentImeSerializer(
      editor.document,
      composer.selection!,
    );
    final insertionSelection = docSerializer.imeToDocumentSelection(
      TextSelection.collapsed(offset: insertionOffset),
    );
    composer.selection = insertionSelection;

    final didInsert = commonOps.insertPlainText(textInserted);
    editorImeLog.fine("Insertion successful? $didInsert");
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

    composer.selection ??= replacementSelection;

    if (replacementText == "\n") {
      performAction(TextInputAction.newline);
      return;
    }

    commonOps.insertPlainText(replacementText);
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
      selectedNode.metadata['blockType'] = header1Attribution;
      selectedNode.notifyListeners();
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
      selectedNode.metadata['blockType'] = header2Attribution;
      selectedNode.notifyListeners();
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

    final selectedNode = document.getNodeById(selection.extent.nodeId);
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
                    child: Row(
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
                          onPressed: selection.isCollapsed &&
                                  (selectedNode is TextNode && selectedNode.metadata['blockType'] != header1Attribution)
                              ? _convertToHeader1
                              : null,
                          icon: const Icon(Icons.title),
                        ),
                        IconButton(
                          onPressed: selection.isCollapsed &&
                                  (selectedNode is TextNode && selectedNode.metadata['blockType'] != header2Attribution)
                              ? _convertToHeader2
                              : null,
                          icon: const Icon(Icons.title),
                          iconSize: 18,
                        ),
                        IconButton(
                          onPressed: selection.isCollapsed &&
                                  ((selectedNode is ParagraphNode && selectedNode.metadata['blockType'] != null) ||
                                      (selectedNode is TextNode && selectedNode is! ParagraphNode))
                              ? _convertToParagraph
                              : null,
                          icon: const Icon(Icons.wrap_text),
                        ),
                        IconButton(
                          onPressed: selection.isCollapsed &&
                                  (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                      (selectedNode is ListItemNode && selectedNode.type != ListItemType.ordered))
                              ? _convertToOrderedListItem
                              : null,
                          icon: const Icon(Icons.looks_one_rounded),
                        ),
                        IconButton(
                          onPressed: selection.isCollapsed &&
                                  (selectedNode is TextNode && selectedNode is! ListItemNode ||
                                      (selectedNode is ListItemNode && selectedNode.type != ListItemType.unordered))
                              ? _convertToUnorderedListItem
                              : null,
                          icon: const Icon(Icons.list),
                        ),
                        IconButton(
                          onPressed: selection.isCollapsed &&
                                  selectedNode is TextNode &&
                                  (selectedNode is! ParagraphNode ||
                                      selectedNode.metadata['blockType'] != blockquoteAttribution)
                              ? _convertToBlockquote
                              : null,
                          icon: const Icon(Icons.format_quote),
                        ),
                        IconButton(
                          onPressed:
                              selection.isCollapsed && selectedNode is ParagraphNode && selectedNode.text.text.isEmpty
                                  ? _convertToHr
                                  : null,
                          icon: const Icon(Icons.horizontal_rule),
                        ),
                      ],
                    ),
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
