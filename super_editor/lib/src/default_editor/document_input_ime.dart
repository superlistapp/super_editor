import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/super_editor.dart';

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
    required this.child,
  }) : super(key: key);

  final FocusNode? focusNode;
  final EditContext editContext;
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

    _attachToIme();
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
  }

  @override
  void dispose() {
    _detachFromIme();

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
      // currentTextEditingValue = const TextEditingValue();
      _detachFromIme();
    } else {
      if (isAttachedToIme) {
        _syncImeWithDocumentAndComposer();
      } else {
        _attachToIme();
      }
    }
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
        const TextInputConfiguration(
          // TODO: make this configurable
          autocorrect: true,
          enableDeltaModel: true,
          // TODO: make this configurable
          enableSuggestions: true,
          // TODO: make this configurable
          inputAction: TextInputAction.newline,
        ));

    _syncImeWithDocumentAndComposer();

    _inputConnection!
      ..show()
      ..setEditingState(currentTextEditingValue);

    editorImeLog.fine('Is attached to input client? ${_inputConnection!.attached}');
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
    print("New text editing value: $newValue");
    print("Existing text editing value: $_currentTextEditingValue");
    if (newValue != _currentTextEditingValue) {
      _currentTextEditingValue = newValue;
      editorImeLog.info("Sending new text editing value to OS: $_currentTextEditingValue");
      _inputConnection?.setEditingState(_currentTextEditingValue);
    }
  }

  void _syncImeWithDocumentAndComposer() {
    final selection = widget.editContext.composer.selection;
    if (selection != null) {
      print("Syncing IME with Doc and Composer");
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
        editorImeLog.fine("Inserting text: ${delta.textInserted}");

        final docSerializer = DocumentImeSerializer(
          widget.editContext.editor.document,
          widget.editContext.composer.selection!,
        );
        final insertionSelection =
            docSerializer.imeToDocumentSelection(TextSelection.collapsed(offset: delta.insertionOffset));
        widget.editContext.composer.selection = insertionSelection;

        if (delta.textInserted == "\n") {
          widget.editContext.commonOps.insertBlockLevelNewline();
          return;
        }

        final didInsert = widget.editContext.commonOps.insertPlainText(delta.textInserted);
        editorImeLog.fine("Insertion successful? $didInsert");
      } else if (delta is TextEditingDeltaReplacement) {
        editorImeLog.fine("Replacing text: ${delta.textReplaced}");
        editorImeLog.fine("With new text: ${delta.replacementText}");

        final docSerializer = DocumentImeSerializer(
          widget.editContext.editor.document,
          widget.editContext.composer.selection!,
        );
        final replacementSelection = docSerializer.imeToDocumentSelection(TextSelection(
          baseOffset: delta.replacedRange.start,
          // TODO: the delta API is wrong for TextRange.end, it should be exclusive,
          //       but it's implemented as inclusive. Change this code when Flutter
          //       fixes the problem.
          extentOffset: delta.replacedRange.end,
        ));
        widget.editContext.composer.selection = replacementSelection;

        if (delta.replacementText == "\n") {
          widget.editContext.commonOps.deleteSelection();
          widget.editContext.commonOps.insertBlockLevelNewline();
          return;
        }

        widget.editContext.commonOps.insertPlainText(delta.replacementText);
      } else if (delta is TextEditingDeltaDeletion) {
        editorImeLog.fine("Deleting text: ${delta.textDeleted}");
        editorImeLog.fine("Deleted range: ${delta.deletedRange}");

        final rangeToDelete = delta.deletedRange;
        final docSerializer = DocumentImeSerializer(
          widget.editContext.editor.document,
          widget.editContext.composer.selection!,
        );
        final docSelectionToDelete = docSerializer.imeToDocumentSelection(TextSelection(
          baseOffset: rangeToDelete.start,
          extentOffset: rangeToDelete.end,
        ));
        editorImeLog.fine("Doc selection to delete: $docSelectionToDelete");

        if (docSelectionToDelete == null) {
          final selectedNodeIndex = widget.editContext.editor.document.getNodeIndexById(
            widget.editContext.composer.selection!.extent.nodeId,
          );
          if (selectedNodeIndex > 0) {
            // The user is trying to delete upstream at the start of a node.
            // This action requires intervention because the IME doesn't know
            // that there's more content before this node. Instruct the editor
            // to run a delete action upstream, which will take the desired
            // "backspace" behavior at the start of this node.
            widget.editContext.commonOps.deleteUpstream();
            print("Deleted upstream. New selection: ${widget.editContext.composer.selection}");
            _syncImeWithDocumentAndComposer();
            return;
          }
        }

        widget.editContext.composer.selection = docSelectionToDelete;
        widget.editContext.commonOps.deleteSelection();
        _syncImeWithDocumentAndComposer();
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
    // TODO: implement performAction
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
    // TODO: implement updateFloatingCursor
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
  static const _leadingCharacters = ['*', '^', '~', '`'];
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
  final _textNodes = <TextNode>[];
  late String _imeText;
  late bool _didPrependPlaceholder;
  String? _prependedCharacter;

  void _serialize() {
    final buffer = StringBuffer();
    int characterCount = 0;

    if (_shouldPrependPlaceholder()) {
      editorImeLog.fine("Prepending upstream character for IME");
      // Put an arbitrary character at the front of the text so that
      // the IME will report backspace buttons when the caret sits at
      // the beginning of the node. For example, the caret is at the
      // beginning of some text and we want to combine this text with
      // the text above it when the user presses backspace.
      //
      //     Text above...
      //     |The selected text node.
      _prependedCharacter = _nextLeadingCharacter();
      buffer.write(_prependedCharacter);
      characterCount = 1;
      _didPrependPlaceholder = true;
    } else {
      _didPrependPlaceholder = false;
      _prependedCharacter = null;
    }

    final selectedNodes = _doc.getNodesInContentOrder(_selection);
    for (int i = 0; i < selectedNodes.length; i += 1) {
      final node = selectedNodes[i];
      if (node is! TextNode) {
        continue;
      }

      _textNodes.add(node);

      // Append a newline character before appending another node's text.
      //
      // The choice to separate each node with a newline was a judgement call.
      // There is no OS-level expectation for how structured content should
      // collapse down to IME content.
      if (node != _textNodes.first) {
        buffer.write('\n');
        characterCount += 1;
      }

      // Cache mappings between the IME text range and the document position
      // so that we can easily convert between the two, when requested.
      final imeRange = TextRange(start: characterCount, end: characterCount + node.text.text.length);
      _imeRangesToDocTextNodes[imeRange] = node.id;
      _docTextNodesToImeRanges[node.id] = imeRange;

      // Concatenate this node's text with the previous nodes.
      buffer.write(node.text.text);
      characterCount += buffer.length;
    }

    _imeText = buffer.toString();
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
      if ((imeSelection.isCollapsed && imeSelection.extentOffset == 1) ||
          (imeSelection.start == 0 && imeSelection.end == 1)) {
        editorImeLog.fine("Returning null doc selection");
        return null;
      }

      editorImeLog.fine("Removing arbitrary character from IME selection");
      imeSelection = imeSelection.copyWith(
        baseOffset: imeSelection.affinity == TextAffinity.downstream ? 1 : imeSelection.baseOffset,
        extentOffset: imeSelection.affinity == TextAffinity.downstream ? imeSelection.extentOffset : 1,
      );
    } else {
      editorImeLog.fine("Returning doc selection without modification");
    }

    return DocumentSelection(
      base: _imeToDocumentPosition(imeSelection.base),
      extent: _imeToDocumentPosition(imeSelection.extent),
    );
  }

  DocumentPosition _imeToDocumentPosition(TextPosition imePosition) {
    for (final range in _imeRangesToDocTextNodes.keys) {
      if (imePosition.offset >= range.start && imePosition.offset <= range.end) {
        return DocumentPosition(
          nodeId: _imeRangesToDocTextNodes[range]!,
          nodePosition: TextNodePosition(offset: imePosition.offset - range.start),
        );
      }
    }

    throw Exception("Couldn't map an IME position to a document position. IME position: $imePosition");
  }

  TextSelection documentToImeSelection(DocumentSelection docSelection) {
    return TextSelection(
      baseOffset: _documentToImePosition(docSelection.base).offset,
      extentOffset: _documentToImePosition(docSelection.extent).offset,
    );
  }

  TextPosition _documentToImePosition(DocumentPosition docPosition) {
    if (docPosition.nodePosition is! TextNodePosition) {
      throw Exception(
          "Can't map the given docPosition to an IME position because the docPosition.nodePosition is not a TextNodePosition: $docPosition");
    }

    final imeRange = _docTextNodesToImeRanges[docPosition.nodeId];
    print("Doc node ${docPosition.nodeId} has IME range: $imeRange");
    if (imeRange == null) {
      throw Exception("No such document position in the IME content: $docPosition");
    }

    return TextPosition(offset: imeRange.start + (docPosition.nodePosition as TextNodePosition).offset);
  }

  TextEditingValue toTextEditingValue() {
    final docTextSelection = _constrictToTextSelectionEndCaps(_selection);

    // Note: If there is no selected text, then only non-text content is
    // selected. We still need to provide at least 1 character of IME content
    // so that the IME will report a delete key press. We send a "*". The
    // zero-width unicode character seemed more appropriate, but the IME wasn't
    // sending delete deltas for that character.
    final selectedContent = docTextSelection != null ? _imeText : "*";
    final imeSelection = docTextSelection != null
        ? TextSelection(
            baseOffset: _documentToImePosition(docTextSelection.base).offset,
            extentOffset: _documentToImePosition(docTextSelection.extent).offset,
          )
        : const TextSelection.collapsed(offset: 1);

    return TextEditingValue(
      text: selectedContent,
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
      int restrictedEndNodeIndex = endNodeIndex + 1;
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

class KeyboardEditingToolbar extends StatelessWidget {
  const KeyboardEditingToolbar({
    Key? key,
    required this.document,
    required this.composer,
    required this.commonOps,
  }) : super(key: key);

  final Document document;
  final DocumentComposer composer;
  final CommonEditorOperations commonOps;

  void _convertToHeader1() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    selectedNode.metadata['blockType'] = header1Attribution;
    selectedNode.notifyListeners();
  }

  void _convertToHeader2() {
    final selectedNode = document.getNodeById(composer.selection!.extent.nodeId)! as TextNode;

    selectedNode.metadata['blockType'] = header2Attribution;
    selectedNode.notifyListeners();
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

    return Material(
      child: Container(
        width: double.infinity,
        height: 48,
        color: const Color(0xFFDDDDDD),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
    );
  }
}
