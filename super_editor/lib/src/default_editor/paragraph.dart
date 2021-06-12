import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/document_interaction.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

import 'styles.dart';
import 'text_tools.dart';

final _log = Logger(scope: 'paragraph.dart');

class ParagraphNode extends TextNode {
  ParagraphNode({
    required String id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
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
    required this.firstNodeId,
    required this.secondNodeId,
  }) : assert(firstNodeId != secondNodeId);

  final String firstNodeId;
  final String secondNodeId;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    _log.log('CombineParagraphsCommand', 'Executing CombineParagraphsCommand');
    _log.log('CombineParagraphsCommand', ' - merging "$firstNodeId" <- "$secondNodeId"');
    final secondNode = document.getNodeById(secondNodeId);
    if (secondNode is! TextNode) {
      _log.log('CombineParagraphsCommand', 'WARNING: Cannot merge node of type: $secondNode into node above.');
      return;
    }

    final nodeAbove = document.getNodeBefore(secondNode);
    if (nodeAbove == null) {
      _log.log('CombineParagraphsCommand', 'At top of document. Cannot merge with node above.');
      return;
    }
    if (nodeAbove.id != firstNodeId) {
      _log.log('CombineParagraphsCommand', 'The specified `firstNodeId` is not the node before `secondNodeId`.');
      return;
    }
    if (nodeAbove is! TextNode) {
      _log.log('CombineParagraphsCommand', 'Cannot merge ParagraphNode into node of type: $nodeAbove');
      return;
    }

    // Combine the text and delete the currently selected node.
    nodeAbove.text = nodeAbove.text.copyAndAppend(secondNode.text);
    bool didRemove = transaction.deleteNode(secondNode);
    if (!didRemove) {
      _log.log('CombineParagraphsCommand', 'ERROR: Failed to delete the currently selected node from the document.');
    }
  }
}

/// Splits the `ParagraphNode` affiliated with the given `nodeId` at the
/// given `splitPosition`, placing all text after `splitPosition` in a
/// new `ParagraphNode` with the given `newNodeId`, inserted after the
/// original node.
class SplitParagraphCommand implements EditorCommand {
  SplitParagraphCommand({
    required this.nodeId,
    required this.splitPosition,
    required this.newNodeId,
    required this.replicateExistingMetdata,
  });

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;
  final bool replicateExistingMetdata;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    _log.log('SplitParagraphCommand', 'Executing SplitParagraphCommand');

    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      _log.log('SplitParagraphCommand', 'WARNING: Cannot split paragraph for node of type: $node.');
      return;
    }

    final text = node.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = text.copyText(splitPosition.offset);
    _log.log('SplitParagraphCommand', 'Splitting paragraph:');
    _log.log('SplitParagraphCommand', ' - start text: "${startText.text}"');
    _log.log('SplitParagraphCommand', ' - end text: "${endText.text}"');

    // Change the current nodes content to just the text before the caret.
    _log.log('SplitParagraphCommand', ' - changing the original paragraph text due to split');
    node.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = ParagraphNode(
      id: newNodeId,
      text: endText,
      metadata: replicateExistingMetdata ? node.metadata : {},
    );

    // Insert the new node after the current node.
    _log.log('SplitParagraphCommand', ' - inserting new node in document');
    transaction.insertNodeAfter(
      previousNode: node,
      newNode: newNode,
    );

    _log.log('SplitParagraphCommand', ' - inserted new node: ${newNode.id} after old one: ${node.id}');
  }
}

ExecutionInstruction anyCharacterToInsertInParagraph({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  var character = keyEvent.character;
  if (character == null || character == '') {
    return ExecutionInstruction.continueExecution;
  }
  // On web, keys like shift and alt are sending their full name
  // as a character, e.g., "Shift" and "Alt". This check prevents
  // those keys from inserting their name into content.
  //
  // This filter is a blacklist, and therefore it will fail to
  // catch any key that isn't explicitly listed. The eventual solution
  // to this is for the web to honor the standard key event contract,
  // but that's out of our control.
  if (kIsWeb && webBugBlacklistCharacters.contains(character)) {
    return ExecutionInstruction.continueExecution;
  }

  // The web reports a tab as "Tab". Intercept it and translate it to a space.
  if (character == 'Tab') {
    character = ' ';
  }

  final didInsertCharacter = editContext.commonOps.insertCharacter(character);

  if (didInsertCharacter && character == ' ') {
    editContext.commonOps.convertParagraphByPatternMatching(
      editContext.composer.selection!.extent.nodeId,
    );
  }

  return didInsertCharacter ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

class DeleteParagraphsCommand implements EditorCommand {
  DeleteParagraphsCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    _log.log('DeleteParagraphsCommand', 'Executing DeleteParagraphsCommand');
    _log.log('DeleteParagraphsCommand', ' - deleting "$nodeId"');
    final node = document.getNodeById(nodeId);
    if (node is! TextNode) {
      _log.log('DeleteParagraphsCommand', 'WARNING: Cannot delete node of type: $node.');
      return;
    }

    bool didRemove = transaction.deleteNode(node);
    if (!didRemove) {
      _log.log('DeleteParagraphsCommand', 'ERROR: Failed to delete node "$node" from the document.');
    }
  }
}

/// When the caret is collapsed at the beginning of a ParagraphNode
/// and backspace is pressed, clear any existing block type, e.g.,
/// header 1, header 2, blockquote.
ExecutionInstruction backspaceToClearParagraphBlockType({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
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

  final textPosition = editContext.composer.selection!.extent.nodePosition;
  if (textPosition is! TextNodePosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  final didClearBlockType = editContext.commonOps.convertToParagraph();
  return didClearBlockType ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction enterToInsertBlockNewline({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  final didInsertBlockNewline = editContext.commonOps.insertBlockLevelNewline();

  return didInsertBlockNewline ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction moveParagraphSelectionUpWhenBackspaceIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
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

  if (node.text.text.isEmpty) {
    return ExecutionInstruction.continueExecution;
  }

  final nodeAbove = editContext.editor.document.getNodeBefore(node);
  if (nodeAbove == null) {
    return ExecutionInstruction.continueExecution;
  }
  final newDocumentPosition = DocumentPosition(
    nodeId: nodeAbove.id,
    nodePosition: nodeAbove.endPosition,
  );

  editContext.composer.selection = DocumentSelection.collapsed(
    position: newDocumentPosition,
  );

  return ExecutionInstruction.haltExecution;
}

Widget? paragraphBuilder(ComponentContext componentContext) {
  if (componentContext.documentNode is! ParagraphNode) {
    return null;
  }

  final textSelection =
      componentContext.nodeSelection == null || componentContext.nodeSelection!.nodeSelection is! TextSelection
          ? null
          : componentContext.nodeSelection!.nodeSelection as TextSelection;
  if (componentContext.nodeSelection != null && componentContext.nodeSelection!.nodeSelection is! TextSelection) {
    _log.log('paragraphBuilder',
        'ERROR: Building a paragraph component but the selection is not a TextSelection: ${componentContext.documentNode.id}');
  }
  final showCaret = componentContext.showCaret && componentContext.nodeSelection != null
      ? componentContext.nodeSelection!.isExtent
      : false;
  final highlightWhenEmpty =
      componentContext.nodeSelection == null ? false : componentContext.nodeSelection!.highlightWhenEmpty;

  _log.log('paragraphBuilder', ' - ${componentContext.documentNode.id}: ${componentContext.nodeSelection}');
  if (showCaret) {
    _log.log('paragraphBuilder', '   - ^ showing caret');
  }

  _log.log('paragraphBuilder', ' - building a paragraph with selection:');
  _log.log('paragraphBuilder', '   - base: ${textSelection?.base}');
  _log.log('paragraphBuilder', '   - extent: ${textSelection?.extent}');

  final textDirection = getParagraphDirection((componentContext.documentNode as TextNode).text.text);

  TextAlign textAlign = (textDirection == TextDirection.ltr) ? TextAlign.left : TextAlign.right;
  final textAlignName = (componentContext.documentNode as TextNode).metadata['textAlign'];
  switch (textAlignName) {
    case 'left':
      textAlign = TextAlign.left;
      break;
    case 'center':
      textAlign = TextAlign.center;
      break;
    case 'right':
      textAlign = TextAlign.right;
      break;
    case 'justify':
      textAlign = TextAlign.justify;
      break;
  }

  return TextComponent(
    key: componentContext.componentKey,
    text: (componentContext.documentNode as TextNode).text,
    textStyleBuilder: componentContext.extensions[textStylesExtensionKey],
    metadata: (componentContext.documentNode as TextNode).metadata,
    textAlign: textAlign,
    textDirection: textDirection,
    textSelection: textSelection,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    showCaret: showCaret,
    caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
    highlightWhenEmpty: highlightWhenEmpty,
  );
}
