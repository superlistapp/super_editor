import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '../core/document.dart';
import '../core/document_selection.dart';
import '../core/document_editor.dart';
import 'document_interaction.dart';
import 'paragraph.dart';
import 'styles.dart';
import 'text.dart';

final _log = Logger(scope: 'blockquote.dart');

/// Displays a blockquote in a document.
class BlockquoteComponent extends StatelessWidget {
  const BlockquoteComponent({
    Key? key,
    required this.textKey,
    required this.text,
    required this.styleBuilder,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFFEEEEEE),
      ),
      child: TextComponent(
        key: textKey,
        text: text,
        textStyleBuilder: styleBuilder,
        textSelection: textSelection,
        selectionColor: selectionColor,
        showCaret: showCaret,
        caretColor: caretColor,
        showDebugPaint: showDebugPaint,
      ),
    );
  }
}

ExecutionInstruction convertBlockquoteToParagraphWhenBackspaceIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.editor.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }
  if (node.metadata['blockType'] != 'blockquote') {
    return ExecutionInstruction.continueExecution;
  }

  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = editContext.composer.selection!.extent.nodePosition;
  if (textPosition is! TextPosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.editor.executeCommand(
    ConvertBlockquoteToParagraphCommand(nodeId: node.id),
  );

  return ExecutionInstruction.haltExecution;
}

class ConvertBlockquoteToParagraphCommand implements EditorCommand {
  ConvertBlockquoteToParagraphCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final node = document.getNodeById(nodeId);
    final blockquote = node as ParagraphNode;
    final newParagraphNode = ParagraphNode(
      id: blockquote.id,
      text: blockquote.text,
    );
    final blockquoteNodeIndex = document.getNodeIndex(blockquote);
    transaction
      ..deleteNodeAt(blockquoteNodeIndex)
      ..insertNodeAt(blockquoteNodeIndex, newParagraphNode);
  }
}

ExecutionInstruction insertNewlineInBlockquote({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  if (!keyEvent.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.editor.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }
  if (node.metadata['blockType'] != 'blockquote') {
    return ExecutionInstruction.continueExecution;
  }

  final textNode = editContext.editor.document.getNode(editContext.composer.selection!.extent) as TextNode;
  final initialTextOffset = (editContext.composer.selection!.extent.nodePosition as TextPosition).offset;

  editContext.editor.executeCommand(
    InsertTextCommand(
      documentPosition: editContext.composer.selection!.extent,
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
}

ExecutionInstruction splitBlockquoteWhenEnterPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.editor.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }
  if (node.metadata['blockType'] != 'blockquote') {
    return ExecutionInstruction.continueExecution;
  }

  final newNodeId = DocumentEditor.createNodeId();

  editContext.editor.executeCommand(
    SplitBlockquoteCommand(
      nodeId: node.id,
      splitPosition: editContext.composer.selection!.extent.nodePosition as TextPosition,
      newNodeId: newNodeId,
    ),
  );

  // Place the caret at the beginning of the new paragraph node.
  editContext.composer.selection = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: newNodeId,
      nodePosition: TextPosition(offset: 0),
    ),
  );

  return ExecutionInstruction.haltExecution;
}

class SplitBlockquoteCommand implements EditorCommand {
  SplitBlockquoteCommand({
    required this.nodeId,
    required this.splitPosition,
    required this.newNodeId,
  });

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final node = document.getNodeById(nodeId);
    final blockquote = node as ParagraphNode;
    final text = blockquote.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = splitPosition.offset < text.text.length ? text.copyText(splitPosition.offset) : AttributedText();

    // Change the current node's content to just the text before the caret.
    // TODO: figure out how node changes should work in terms of
    //       a DocumentEditorTransaction (#67)
    blockquote.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final isNewNodeABlockquote = endText.text.isNotEmpty;
    final newNode = ParagraphNode(
      id: newNodeId,
      text: endText,
      metadata: isNewNodeABlockquote ? {'blockType': 'blockquote'} : {},
    );

    // Insert the new node after the current node.
    transaction.insertNodeAfter(
      previousNode: node,
      newNode: newNode,
    );
  }
}

Widget? blockquoteBuilder(ComponentContext componentContext) {
  final blockquoteNode = componentContext.documentNode;
  if (blockquoteNode is! ParagraphNode) {
    return null;
  }
  if (blockquoteNode.metadata['blockType'] != 'blockquote') {
    return null;
  }

  final textSelection = componentContext.nodeSelection?.nodeSelection as TextSelection;
  final showCaret = componentContext.showCaret && (componentContext.nodeSelection?.isExtent ?? false);

  return BlockquoteComponent(
    textKey: componentContext.componentKey,
    text: blockquoteNode.text,
    styleBuilder: componentContext.extensions[textStylesExtensionKey],
    textSelection: textSelection,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    showCaret: showCaret,
    caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
  );
}
