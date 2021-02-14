import 'package:example/spikes/editor_abstractions/default_editor/horizontal_rule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/document_editor.dart';
import '../core/document_composer.dart';
import '../core/document.dart';
import '../core/document_selection.dart';
import '../core/attributed_text.dart';
import '_text_tools.dart';
import 'text.dart';
import 'list_items.dart';

class ParagraphNode extends TextNode {
  ParagraphNode({
    @required String id,
    AttributedText text,
    Map<String, dynamic> metadata,
  }) : super(
          id: id,
          text: text,
          metadata: metadata,
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

/// Splits the `ParagraphNode` affiliated with the given `nodeId` at the
/// given `splitPosition`, placing all text after `splitPosition` in a
/// new `ParagraphNode` with the given `newNodeId`, inserted after the
/// original node.
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
    }

    final hrMatch = RegExp(r'^---*\s$');
    final hasHrMatch = hrMatch.hasMatch(textBeforeCaret);
    if (hasHrMatch) {
      print('Paragraph has an HR match');
      // Insert an HR before this paragraph and then clear the
      // paragraph's content.
      final document = composerContext.document;
      final paragraphNodeIndex = document.getNodeIndex(node);

      document.insertNodeAt(
        paragraphNodeIndex,
        HorizontalRuleNode(
          id: RichTextDocument.createNodeId(),
        ),
      );

      node.text = AttributedText();

      composerContext.currentSelection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextPosition(offset: 0),
        ),
      );
    }

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

class DeleteParagraphsCommand implements EditorCommand {
  DeleteParagraphsCommand({
    this.nodeId,
  }) : assert(nodeId != null);

  final String nodeId;

  void execute(RichTextDocument document) {
    print('Executing DeleteParagraphsCommand');
    print(' - deleting "$nodeId"');
    final node = document.getNodeById(nodeId);
    if (node is! TextNode) {
      print('WARNING: Cannot delete node of type: $node.');
      return;
    }

    bool didRemove = document.deleteNode(node);
    if (!didRemove) {
      print('ERROR: Failed to delete node "$node" from the document.');
    }
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

ExecutionInstruction deleteEmptyParagraphWhenBackspaceIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
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
  final paragraphNode = node as ParagraphNode;

  if (paragraphNode.text.text.isNotEmpty) {
    return ExecutionInstruction.continueExecution;
  }

  final nodeAbove = composerContext.document.getNodeBefore(paragraphNode);
  if (nodeAbove == null) {
    return ExecutionInstruction.continueExecution;
  }
  final newDocumentPosition = DocumentPosition(
    nodeId: nodeAbove.id,
    nodePosition: nodeAbove.endPosition,
  );

  composerContext.editor.executeCommand(
    DeleteParagraphsCommand(nodeId: node.id),
  );

  composerContext.currentSelection.value = DocumentSelection.collapsed(
    position: newDocumentPosition,
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction moveParagraphSelectionUpWhenBackspaceIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
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
  final paragraphNode = node as ParagraphNode;

  if (paragraphNode.text.text.isEmpty) {
    return ExecutionInstruction.continueExecution;
  }

  final nodeAbove = composerContext.document.getNodeBefore(paragraphNode);
  if (nodeAbove == null) {
    return ExecutionInstruction.continueExecution;
  }
  final newDocumentPosition = DocumentPosition(
    nodeId: nodeAbove.id,
    nodePosition: nodeAbove.endPosition,
  );

  composerContext.currentSelection.value = DocumentSelection.collapsed(
    position: newDocumentPosition,
  );

  return ExecutionInstruction.haltExecution;
}
