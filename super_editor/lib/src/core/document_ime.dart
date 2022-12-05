import 'dart:math';

import 'package:flutter/services.dart';
import 'package:super_editor/src/default_editor/document_input_ime.dart';
// TODO: get default editor imports out of here. This is a core class.
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';

import 'document.dart';
import 'document_selection.dart';

/// A [TextInputClient] that applies IME delta operations to a [Document] through a
/// [DocumentEditor].
class EditorImeClient with TextInputClient, DeltaTextInputClient {
  EditorImeClient({
    required this.softwareKeyboardHandler,
    FloatingCursorController? floatingCursorController,
    required this.sendDocumentToIme,
  }) {
    _floatingCursorController = floatingCursorController;
  }

  final SoftwareKeyboardHandler softwareKeyboardHandler;

  /// Called whenever this object wants the current [Document] content to
  /// be serialized and sent to the IME.
  final void Function([TextRange? composingRegion]) sendDocumentToIme;

  TextInputConnection? _inputConnection;
  late FloatingCursorController? _floatingCursorController;

  @override
  // TODO: implement currentAutofillScope
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue get currentTextEditingValue => _currentTextEditingValue;
  TextEditingValue _currentTextEditingValue = const TextEditingValue();
  TextEditingValue? _lastTextEditingValueSentToOs;
  set currentTextEditingValue(TextEditingValue newValue) {
    _currentTextEditingValue = newValue;
    if (newValue != _lastTextEditingValueSentToOs && !isApplyingDeltas) {
      editorImeLog.info("Sending new text editing value to OS: $_currentTextEditingValue");
      _inputConnection?.setEditingState(_currentTextEditingValue);
      _lastTextEditingValueSentToOs = _currentTextEditingValue;
    } else if (isApplyingDeltas) {
      editorImeLog.fine("Ignoring new TextEditingValue because we're applying deltas");
    } else {
      editorImeLog.fine("Ignoring new TextEditingValue because it's the same as the existing one: $newValue");
    }
  }

  // TODO: make this private again
  bool isApplyingDeltas = false;

  @override
  void updateEditingValue(TextEditingValue value) {
    editorImeLog.info("Received new TextEditingValue from OS: $value");
    _currentTextEditingValue = value;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    editorImeLog.info("Received edit deltas from platform: ${textEditingDeltas.length} deltas");
    for (final delta in textEditingDeltas) {
      editorImeLog.info("$delta");
    }

    final imeValueBeforeChange = currentTextEditingValue;
    editorImeLog.fine("IME value before applying deltas: $imeValueBeforeChange");

    isApplyingDeltas = true;
    softwareKeyboardHandler.applyDeltas(textEditingDeltas);
    isApplyingDeltas = false;

    editorImeLog.fine("Done applying deltas. Serializing the document and sending to IME.");
    sendDocumentToIme(textEditingDeltas.last.composing);

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
    softwareKeyboardHandler.performAction(action);
  }

  @override
  void performSelector(String selectorName) {
    // TODO: implement this method starting with Flutter 3.3.4
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
        _floatingCursorController?.offset = point.offset;
        break;
      case FloatingCursorDragState.End:
        _floatingCursorController?.offset = null;
        break;
    }
  }

  @override
  void connectionClosed() {
    editorImeLog.info("IME connection closed");
    _inputConnection = null;
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
    this.keyboardBrightness = Brightness.light,
    this.keyboardActionButton = TextInputAction.newline,
    this.clearSelectionWhenImeDisconnects = false,
  });

  /// Whether the OS should offer auto-correction options to the user.
  final bool enableAutocorrect;

  /// Whether the OS should offer text completion suggestions to the user.
  final bool enableSuggestions;

  /// The brightness of the software keyboard (only applies to platforms
  /// with a software keyboard).
  final Brightness keyboardBrightness;

  /// The action button that's displayed on a software keyboard, e.g.,
  /// new-line, done, go, etc.
  final TextInputAction keyboardActionButton;

  /// Whether the document's selection should be cleared (removed) when the
  /// IME disconnects, i.e., the software keyboard closes.
  ///
  /// Typically, on devices with software keyboards, the keyboard is critical
  /// to all document editing. In such cases, it should be reasonable to clear
  /// the selection when the keyboard closes.
  ///
  /// Some apps include editing features that can operate when the keyboard is
  /// closed. For example, some apps display special editing options behind the
  /// keyboard. The user closes the keyboard, uses the special options, and then
  /// re-opens the keyboard. In this case, the document selection **shouldn't**
  /// be cleared when the keyboard closes, because the special options behind the
  /// keyboard still need to operate on that selection.
  final bool clearSelectionWhenImeDisconnects;

  ImeConfiguration copyWith({
    bool? enableAutocorrect,
    bool? enableSuggestions,
    Brightness? keyboardBrightness,
    TextInputAction? keyboardActionButton,
    bool? clearSelectionWhenImeDisconnects,
  }) {
    return ImeConfiguration(
      enableAutocorrect: enableAutocorrect ?? this.enableAutocorrect,
      enableSuggestions: enableSuggestions ?? this.enableSuggestions,
      keyboardBrightness: keyboardBrightness ?? this.keyboardBrightness,
      keyboardActionButton: keyboardActionButton ?? this.keyboardActionButton,
      clearSelectionWhenImeDisconnects: clearSelectionWhenImeDisconnects ?? this.clearSelectionWhenImeDisconnects,
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

/// Serializes a [Document] and [DocumentSelection] into a form that's understood by
/// the Input Method Engine (IME), and vis-a-versa.
///
/// The IME only understands strings of plain text. Therefore, to make [Document] content
/// available for IME editing, the [Document] structure needs to be serialized into a run of text.
///
/// When the IME alters the given content, that plain text needs to be deserialized back into
/// a [Document] structure.
///
/// This class implements both [Document] serialization and deserialization for the IME.
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
    final selectedNodeIndex = _doc.getNodeIndexById(selectedNode.id);
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
    final baseNodeIndex = _doc.getNodeIndexById(baseNode.id);
    final extentNode = _doc.getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = _doc.getNodeIndexById(extentNode.id);

    final startNode = baseNodeIndex <= extentNodeIndex ? baseNode : extentNode;
    final startNodeIndex = _doc.getNodeIndexById(startNode.id);
    final startPosition =
        baseNodeIndex <= extentNodeIndex ? selection.base.nodePosition : selection.extent.nodePosition;
    final endNode = baseNodeIndex <= extentNodeIndex ? extentNode : baseNode;
    final endNodeIndex = _doc.getNodeIndexById(endNode.id);
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
    final baseNodeIndex = _doc.getNodeIndexById(baseNode.id);
    final extentNode = _doc.getNodeById(selection.extent.nodeId)!;
    final extentNodeIndex = _doc.getNodeIndexById(extentNode.id);

    final selectionStartNode = baseNodeIndex <= extentNodeIndex ? baseNode : extentNode;
    final selectionStartNodeIndex = _doc.getNodeIndexById(selectionStartNode.id);
    final startNodeIndex = max(selectionStartNodeIndex - 1, 0);

    final selectionEndNode = baseNodeIndex <= extentNodeIndex ? extentNode : baseNode;
    final selectionEndNodeIndex = _doc.getNodeIndexById(selectionEndNode.id);
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
