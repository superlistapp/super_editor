import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/document/document_editor.dart';
import '../core/composition/document_composer.dart';
import '../core/document/rich_text_document.dart';
import '../core/selection/editor_selection.dart';
import '../selectable_text/attributed_text.dart';
import '_text_tools.dart';
import 'text.dart';
import 'list_items.dart';

class ParagraphNode extends TextNode {
  ParagraphNode({
    @required String id,
    AttributedText text,
    TextAlign textAlign = TextAlign.left,
    String textType = 'paragraph',
  }) : super(
          id: id,
          text: text,
          textAlign: textAlign,
          textType: textType,
        );
}

/// Combines two consecutive `ParagraphNode`s, indicated by `firstNodeId`
/// and `secondNodeId`, respectively.
///
/// If the specified nodes are not sequential, or are sequential
/// in reverse order, the command fizzles.
///
/// If both nodes are not `ParagraphNode`s, the command fizzles.
class CombineParagraphsCommand implements EditorCommand {
  CombineParagraphsCommand({
    this.firstNodeId,
    this.secondNodeId,
  })  : assert(firstNodeId != null),
        assert(secondNodeId != null),
        assert(firstNodeId != secondNodeId);

  final String firstNodeId;
  final String secondNodeId;

  void execute(RichTextDocument document) {
    print('Executing CombineParagraphsCommand');
    print(' - merging "$firstNodeId" <- "$secondNodeId"');
    final secondNode = document.getNodeById(secondNodeId);
    if (secondNode is! TextNode) {
      print('WARNING: Cannot merge node of type: $secondNode into node above.');
      return;
    }
    final paragraphNode = secondNode as TextNode;

    final nodeAbove = document.getNodeBefore(paragraphNode);
    if (nodeAbove == null) {
      print('At top of document. Cannot merge with node above.');
      return;
    }
    if (nodeAbove.id != firstNodeId) {
      print('The specified `firstNodeId` is not the node before `secondNodeId`.');
      return;
    }
    if (nodeAbove is! TextNode) {
      print('Cannot merge ParagraphNode into node of type: $nodeAbove');
      return;
    }

    final paragraphNodeAbove = nodeAbove as TextNode;

    // Combine the text and delete the currently selected node.
    paragraphNodeAbove.text = paragraphNodeAbove.text.copyAndAppend(paragraphNode.text);
    bool didRemove = document.deleteNode(paragraphNode);
    if (!didRemove) {
      print('ERROR: Failed to delete the currently selected node from the document.');
    }
  }
}

/// Combines two consecutive `ParagraphNode`s, indicated by `firstNodeId`
/// and `secondNodeId`, respectively.
///
/// If the specified nodes are not sequential, or are sequential
/// in reverse order, the command fizzles.
///
/// If both nodes are not `ParagraphNode`s, the command fizzles.
class SplitParagraphCommand implements EditorCommand {
  SplitParagraphCommand({
    @required this.nodeId,
    @required this.splitPosition,
    @required this.newNodeId,
  })  : assert(nodeId != null),
        assert(splitPosition != null),
        assert(newNodeId != null);

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;

  void execute(RichTextDocument document) {
    print('Executing SplitParagraphCommand');

    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      print('WARNING: Cannot split paragraph for node of type: $node.');
      return;
    }
    final paragraphNode = node as ParagraphNode;

    final text = paragraphNode.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = text.copyText(splitPosition.offset);
    print('Splitting paragraph:');
    print(' - start text: "${startText.text}"');
    print(' - end text: "${endText.text}"');

    // Change the current nodes content to just the text before the caret.
    print(' - changing the original paragraph text due to split');
    paragraphNode.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = ParagraphNode(
      id: newNodeId,
      text: endText,
      textAlign: paragraphNode.textAlign,
    );

    // Insert the new node after the current node.
    print(' - inserting new node in document');
    document.insertNodeAfter(
      previousNode: node,
      newNode: newNode,
    );

    print(' - inserted new node: ${newNode.id} after old one: ${node.id}');
  }
}

ExecutionInstruction insertCharacterInParagraph({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  final node = composerContext.document.getNodeById(composerContext.currentSelection.value.extent.nodeId);
  if (node is ParagraphNode &&
      isCharacterKey(keyEvent.logicalKey) &&
      composerContext.currentSelection.value.isCollapsed) {
    print(' - this is a paragraph');
    // Delegate the action to the standard insert-character behavior.
    insertCharacterInTextComposable(
      composerContext: composerContext,
      keyEvent: keyEvent,
    );

    final text = node.text;
    final textSelection = composerContext.currentSelection.value.extent.nodePosition as TextPosition;

    // TODO: refactor to make prefix matching extensible
    final textBeforeCaret = text.text.substring(0, textSelection.offset);

    final unorderedListItemMatch = RegExp(r'^\s*[\*-]\s+$');
    final hasUnorderedListItemMatch = unorderedListItemMatch.hasMatch(textBeforeCaret);

    final orderedListItemMatch = RegExp(r'^\s*[1].*\s+$');
    final hasOrderedListItemMatch = orderedListItemMatch.hasMatch(textBeforeCaret);

    print(' - text before caret: "$textBeforeCaret"');
    if (hasUnorderedListItemMatch || hasOrderedListItemMatch) {
      print(' - found unordered list item prefix');
      int startOfNewText = textBeforeCaret.length;
      while (startOfNewText < node.text.text.length && node.text.text[startOfNewText] == ' ') {
        startOfNewText += 1;
      }
      // final adjustedText = node.text.text.substring(startOfNewText);
      final adjustedText = node.text.copyText(startOfNewText);
      final newNode = hasUnorderedListItemMatch
          ? ListItemNode.unordered(id: node.id, text: adjustedText)
          : ListItemNode.ordered(id: node.id, text: adjustedText);
      final nodeIndex = composerContext.document.getNodeIndex(node);
      composerContext.document
        ..deleteNodeAt(nodeIndex)
        ..insertNodeAt(nodeIndex, newNode);

      // We removed some text at the beginning of the list item.
      // Move the selection back by that same amount.
      final textPosition = composerContext.currentSelection.value.extent.nodePosition as TextPosition;
      composerContext.currentSelection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextPosition(offset: textPosition.offset - startOfNewText),
        ),
      );
    } else {
      print(' - prefix match');
    }

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

ExecutionInstruction splitParagraphWhenEnterPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }
  if (composerContext.currentSelection.value == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!composerContext.currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = composerContext.document.getNodeById(composerContext.currentSelection.value.extent.nodeId);
  if (node is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }

  final newNodeId = RichTextDocument.createNodeId();

  composerContext.editor.executeCommand(
    SplitParagraphCommand(
      nodeId: node.id,
      splitPosition: composerContext.currentSelection.value.extent.nodePosition as TextPosition,
      newNodeId: newNodeId,
    ),
  );

  // Place the caret at the beginning of the new paragraph node.
  composerContext.currentSelection.value = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: newNodeId,
      nodePosition: TextPosition(offset: 0),
    ),
  );

  return ExecutionInstruction.haltExecution;
}
