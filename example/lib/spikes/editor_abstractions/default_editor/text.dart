import 'dart:collection';
import 'dart:math';

import 'package:example/spikes/editor_abstractions/core/edit_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/attributed_text.dart';
import '../core/document.dart';
import '../core/document_editor.dart';
import '../core/document_layout.dart';
import '../core/document_selection.dart';
import '../selectable_text/selectable_text.dart';
import '_text_tools.dart';
import 'document_interaction.dart';
import 'multi_node_editing.dart';

class TextNode with ChangeNotifier implements DocumentNode {
  TextNode({
    @required this.id,
    AttributedText text,
    Map<String, dynamic> metadata,
  })  : _text = text,
        _metadata = metadata ?? {};

  @override
  final String id;

  AttributedText _text;
  AttributedText get text => _text;
  set text(AttributedText newText) {
    if (newText != _text) {
      print('Text changed. Notifying listeners.');
      _text = newText;
      notifyListeners();
    }
  }

  final Map<String, dynamic> _metadata;
  Map<String, dynamic> get metadata => _metadata;

  @override
  TextPosition get beginningPosition => TextPosition(offset: 0);

  @override
  TextPosition get endPosition => TextPosition(offset: text.text.length);

  @override
  TextSelection computeSelection({
    @required dynamic base,
    @required dynamic extent,
  }) {
    assert(base is TextPosition);
    assert(extent is TextPosition);

    return TextSelection(
      baseOffset: (base as TextPosition).offset,
      extentOffset: (extent as TextPosition).offset,
    );
  }

  @override
  String copyContent(dynamic selection) {
    assert(selection is TextSelection);

    return (selection as TextSelection).textInside(text.text);
  }
}

/// Displays text in a document.
///
/// This is the standard component for text display.
class TextComponent extends StatefulWidget {
  const TextComponent({
    Key key,
    this.text,
    this.textAlign,
    @required this.textStyleBuilder,
    this.metadata = const {},
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.hasCaret = false,
    this.caretColor = Colors.black,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final AttributedText text;
  final TextAlign textAlign;
  final AttributionStyleBuilder textStyleBuilder;
  final Map<String, dynamic> metadata;
  final TextSelection textSelection;
  final Color selectionColor;
  final bool hasCaret;
  final Color caretColor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  _TextComponentState createState() => _TextComponentState();
}

class _TextComponentState extends State<TextComponent> with DocumentComponent implements TextComposable {
  final _selectableTextKey = GlobalKey<SelectableTextState>();

  @override
  TextPosition getPositionAtOffset(Offset localOffset) {
    final textLayout = _selectableTextKey.currentState;
    return textLayout.getPositionAtOffset(localOffset);
  }

  @override
  Offset getOffsetForPosition(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState.getOffsetForPosition(nodePosition);
  }

  @override
  Rect getRectForPosition(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    // TODO: factor in line height for position rect
    final offset = getOffsetForPosition(nodePosition);
    return Rect.fromLTWH(offset.dx, offset.dy, 0, 0);
  }

  @override
  TextPosition getBeginningPosition() {
    return TextPosition(offset: 0);
  }

  @override
  TextPosition getBeginningPositionNearX(double x) {
    return _selectableTextKey.currentState.getPositionInFirstLineAtX(x);
  }

  @override
  TextPosition movePositionLeft(dynamic currentPosition, [Map<String, dynamic> movementModifiers]) {
    if (currentPosition is! TextPosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    final textPosition = currentPosition as TextPosition;
    if (textPosition.offset < 1 || textPosition.offset > widget.text.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    if (movementModifiers['movement_unit'] == 'line') {
      return getPositionAtStartOfLine(
        TextPosition(offset: textPosition.offset),
      );
    } else if (movementModifiers['movement_unit'] == 'word') {
      final text = getContiguousTextAt(textPosition);
      int newOffset = textPosition.offset;
      newOffset -= 1; // we always want to jump at least 1 character.
      while (newOffset > 0 && latinCharacters.contains(text[newOffset])) {
        newOffset -= 1;
      }
      return TextPosition(offset: newOffset);
    } else {
      return TextPosition(offset: textPosition.offset - 1);
    }
  }

  @override
  TextPosition movePositionRight(dynamic currentPosition, [Map<String, dynamic> movementModifiers]) {
    if (currentPosition is! TextPosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    final textPosition = currentPosition as TextPosition;
    if (textPosition.offset >= widget.text.text.length) {
      // Can't move further forward.
      return null;
    }

    if (movementModifiers['movement_unit'] == 'line') {
      final endOfLine = getPositionAtEndOfLine(
        TextPosition(offset: textPosition.offset),
      );

      final TextPosition endPosition = getEndPosition();
      final String text = getContiguousTextAt(endOfLine);
      // Note: we compare offset values because we don't care if the affinitys are equal
      final isAutoWrapLine = endOfLine.offset != endPosition.offset && (text[endOfLine.offset] != '\n');

      // Note: For lines that auto-wrap, moving the cursor to `offset` causes the
      //       cursor to jump to the next line because the cursor is placed after
      //       the final selected character. We don't want this, so in this case
      //       we `-1`.
      //
      //       However, if the line that is selected ends with an explicit `\n`,
      //       or if the line is the terminal line for the paragraph then we don't
      //       want to `-1` because that would leave a dangling character after the
      //       selection.
      // TODO: this is the concept of text affinity. Implement support for affinity.
      // TODO: with affinity, ensure it works as expected for right-aligned text
      // TODO: this logic fails for justified text - find a solution for that
      return isAutoWrapLine ? TextPosition(offset: endOfLine.offset - 1) : endOfLine;
    } else if (movementModifiers['movement_unit'] == 'word') {
      final text = getContiguousTextAt(textPosition);
      int newOffset = textPosition.offset;
      newOffset += 1; // we always want to jump at least 1 character.
      while (newOffset < text.length && latinCharacters.contains(text[newOffset])) {
        newOffset += 1;
      }
      return TextPosition(offset: newOffset);
    } else {
      return TextPosition(offset: textPosition.offset + 1);
    }
  }

  @override
  TextPosition movePositionUp(dynamic currentPosition) {
    if (currentPosition is! TextPosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    final textPosition = currentPosition as TextPosition;
    if (textPosition.offset < 0 || textPosition.offset > widget.text.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    return getPositionOneLineUp(textPosition);
  }

  @override
  TextPosition movePositionDown(dynamic currentPosition) {
    if (currentPosition is! TextPosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    final textPosition = currentPosition as TextPosition;
    if (textPosition.offset < 0 || textPosition.offset > widget.text.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    return getPositionOneLineDown(textPosition);
  }

  @override
  TextPosition getEndPosition() {
    return TextPosition(offset: widget.text.text.length);
  }

  @override
  TextPosition getEndPositionNearX(double x) {
    return _selectableTextKey.currentState.getPositionInLastLineAtX(x);
  }

  @override
  TextSelection getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    final textLayout = _selectableTextKey.currentState;
    return textLayout.getSelectionInRect(localBaseOffset, localExtentOffset);
  }

  @override
  TextSelection getCollapsedSelectionAt(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return TextSelection.fromPosition(nodePosition);
  }

  @override
  TextSelection getSelectionBetween({
    @required dynamic basePosition,
    @required dynamic extentPosition,
  }) {
    if (basePosition is! TextPosition || extentPosition is! TextPosition) {
      return null;
    }

    return TextSelection(
      baseOffset: (basePosition as TextPosition).offset,
      extentOffset: (extentPosition as TextPosition).offset,
    );
  }

  @override
  TextSelection getSelectionOfEverything() {
    return TextSelection(
      baseOffset: 0,
      extentOffset: widget.text.text.length,
    );
  }

  @override
  MouseCursor getDesiredCursorAtOffset(Offset localOffset) {
    final textLayout = _selectableTextKey.currentState;
    return textLayout.isTextAtOffset(localOffset) ? SystemMouseCursors.text : null;
  }

  @override
  TextSelection getWordSelectionAt(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState.getWordSelectionAt(nodePosition as TextPosition);
  }

  @override
  String getContiguousTextAt(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    // This component only displays a single contiguous span of text.
    // Therefore, all of our text is contiguous regardless of position.
    return widget.text.text;
  }

  TextPosition getPositionOneLineUp(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState.getPositionOneLineUp(
      currentPosition: nodePosition,
    );
  }

  TextPosition getPositionOneLineDown(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }

    return _selectableTextKey.currentState.getPositionOneLineDown(
      currentPosition: nodePosition,
    );
  }

  @override
  TextPosition getPositionAtEndOfLine(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState.getPositionAtEndOfLine(currentPosition: nodePosition);
  }

  @override
  TextPosition getPositionAtStartOfLine(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      return null;
    }
    return _selectableTextKey.currentState.getPositionAtStartOfLine(currentPosition: nodePosition);
  }

  @override
  Widget build(BuildContext context) {
    print('Building a TextComponent with key: ${widget.key}');

    final blockType = widget.metadata['blockType'];
    // final blockLevelStyleBuilder = createBlockLevelStyleBuilder(widget.styleBuilder, blockType);

    // Surround the text with block level attributions.
    final blockText = widget.text.copyText(0)
      ..addAttribution(
        blockType,
        TextRange(start: 0, end: widget.text.text.length - 1),
      );
    final richText = blockText.computeTextSpan(widget.textStyleBuilder);

    // final richText = widget.text.computeTextSpan(blockLevelStyleBuilder);

    return SelectableText(
      key: _selectableTextKey,
      richText: richText,
      textAlign: widget.textAlign,
      textSelection: widget.textSelection,
      selectionColor: widget.selectionColor,
      hasCaret: widget.hasCaret,
      caretColor: widget.caretColor,
      highlightWhenEmpty: widget.highlightWhenEmpty,
      showDebugPaint: widget.showDebugPaint,
    );
  }
}

/// Applies the given `attributions` to the given `documentSelection`,
/// if none of the content in the selection contains any of the
/// given `attributions`. Otherwise, all the given `attributions`
/// are removed from the content within the `documentSelection`.
class ToggleTextAttributionsCommand implements EditorCommand {
  ToggleTextAttributionsCommand({
    @required this.documentSelection,
    @required this.attributions,
  }) : assert(documentSelection != null);

  final DocumentSelection documentSelection;
  final Set<String> attributions;

  void execute(Document document, DocumentEditor editor) {
    print('Executing ToggleTextAttributionsCommand');
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);
    if (nodes == null) {
      print(' - Bad DocumentSelection. Could not get range of nodes. Selection: $documentSelection');
      return;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = document.getRangeBetween(documentSelection.base, documentSelection.extent);
    print(' - node range: $nodeRange');

    final nodesAndSelections = LinkedHashMap<TextNode, TextRange>();
    bool alreadyHasAttributions = false;

    for (final node in nodes) {
      if (node is! TextNode) {
        continue;
      }

      final textNode = node as TextNode;
      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        print(' - the selection is within a single node: ${node.id}');
        final baseOffset = (documentSelection.base.nodePosition as TextPosition).offset;
        final extentOffset = (documentSelection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        print(' - selecting part of the first node: ${node.id}');
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        print(' - toggling part of the last node: ${node.id}');
        startOffset = 0;
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset;
      } else {
        // Handle full node selection.
        print(' - toggling full node: ${node.id}');
        startOffset = 0;
        endOffset = max(textNode.text.text.length - 1, 0);
      }

      // The attribution range needs the `start` and `end` to
      // be inclusive. Make sure the `endOffset` isn't equal
      // to the text length.
      if (endOffset == textNode.text.text.length) {
        endOffset = textNode.text.text.length - 1;
      }

      final selectionRange = TextRange(start: startOffset, end: endOffset);

      alreadyHasAttributions = alreadyHasAttributions ||
          textNode.text.hasAttributionsWithin(
            attributions: attributions,
            range: selectionRange,
          );

      nodesAndSelections.putIfAbsent(node, () => selectionRange);
    }

    // Toggle attributions.
    for (final entry in nodesAndSelections.entries) {
      for (String attribution in attributions) {
        final node = entry.key;
        final range = entry.value;
        print(' - toggling attribution: $attribution. Range: $range');
        node.text.toggleAttribution(
          attribution,
          range,
        );
      }
    }

    print(' - done toggling attributions');
  }
}

class InsertTextCommand implements EditorCommand {
  InsertTextCommand({
    @required this.documentPosition,
    @required this.textToInsert,
    @required this.attributions,
  })  : assert(documentPosition != null),
        assert(documentPosition.nodePosition is TextPosition);

  final DocumentPosition documentPosition;
  final String textToInsert;
  final Set<dynamic> attributions;

  void execute(Document document, DocumentEditor editor) {
    final node = document.getNodeById(documentPosition.nodeId);
    if (node is! TextNode) {
      print('ERROR: can\'t insert text in a node that isn\'t a TextNode: $node');
      return;
    }

    final textNode = node as TextNode;
    final textOffset = (documentPosition.nodePosition as TextPosition).offset;
    textNode.text = textNode.text.insertString(
      textToInsert: textToInsert,
      startOffset: textOffset,
      applyAttributions: attributions,
    );
  }
}

ExecutionInstruction insertCharacterInTextComposable({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.isMetaPressed || keyEvent.isAltPressed || keyEvent.isControlPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (isTextEntryNode(document: editContext.document, selection: editContext.composer.selection) &&
      isCharacterKey(keyEvent.logicalKey) &&
      editContext.composer.selection.isCollapsed) {
    final textNode = editContext.document.getNode(editContext.composer.selection.extent) as TextNode;
    final initialTextOffset = (editContext.composer.selection.extent.nodePosition as TextPosition).offset;

    editContext.editor.executeCommand(
      InsertTextCommand(
        documentPosition: editContext.composer.selection.extent,
        textToInsert: keyEvent.character,
        attributions: editContext.composer.preferences.currentStyles,
      ),
    );

    editContext.composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: textNode.id,
        nodePosition: TextPosition(
          offset: initialTextOffset + 1,
        ),
      ),
    );

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction deleteCharacterWhenBackspaceIsPressed({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!isTextEntryNode(document: editContext.document, selection: editContext.composer.selection)) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if ((editContext.composer.selection.extent.nodePosition as TextPosition).offset <= 0) {
    return ExecutionInstruction.continueExecution;
  }

  final textNode = editContext.document.getNode(editContext.composer.selection.extent) as TextNode;
  final currentTextPosition = editContext.composer.selection.extent.nodePosition as TextPosition;
  final newSelectionPosition = DocumentPosition(
    nodeId: textNode.id,
    nodePosition: TextPosition(offset: currentTextPosition.offset - 1),
  );

  // Delete the selected content.
  editContext.editor.executeCommand(
    DeleteSelectionCommand(
      documentSelection: DocumentSelection(
        base: DocumentPosition(
          nodeId: textNode.id,
          nodePosition: currentTextPosition,
        ),
        extent: DocumentPosition(
          nodeId: textNode.id,
          nodePosition: TextPosition(offset: currentTextPosition.offset - 1),
        ),
      ),
    ),
  );

  print(' - new document selection position: ${newSelectionPosition.nodePosition}');
  editContext.composer.selection = DocumentSelection.collapsed(position: newSelectionPosition);

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction deleteCharacterWhenDeleteIsPressed({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!isTextEntryNode(document: editContext.document, selection: editContext.composer.selection)) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  final textNode = editContext.document.getNode(editContext.composer.selection.extent) as TextNode;
  final text = textNode.text;
  final currentTextPosition = (editContext.composer.selection.extent.nodePosition as TextPosition);
  if (currentTextPosition.offset >= text.text.length) {
    return ExecutionInstruction.continueExecution;
  }

  // Delete the selected content.
  editContext.editor.executeCommand(
    DeleteSelectionCommand(
      documentSelection: DocumentSelection(
        base: DocumentPosition(
          nodeId: textNode.id,
          nodePosition: currentTextPosition,
        ),
        extent: DocumentPosition(
          nodeId: textNode.id,
          nodePosition: TextPosition(offset: currentTextPosition.offset + 1),
        ),
      ),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction insertNewlineInParagraph({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (isTextEntryNode(document: editContext.document, selection: editContext.composer.selection) &&
      keyEvent.logicalKey == LogicalKeyboardKey.enter &&
      keyEvent.isShiftPressed &&
      editContext.composer.selection.isCollapsed) {
    final textNode = editContext.document.getNode(editContext.composer.selection.extent) as TextNode;
    final initialTextOffset = (editContext.composer.selection.extent.nodePosition as TextPosition).offset;

    editContext.editor.executeCommand(
      InsertTextCommand(
        documentPosition: editContext.composer.selection.extent,
        textToInsert: '\n',
        attributions: editContext.composer.preferences.currentStyles,
      ),
    );

    editContext.composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: textNode.id,
        nodePosition: TextPosition(
          offset: initialTextOffset + 1,
        ),
      ),
    );

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}
