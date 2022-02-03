import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/raw_key_event_extensions.dart';

import 'document_input_keyboard.dart';
import 'styles.dart';
import 'text_tools.dart';

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
    editorDocLog.info('Executing CombineParagraphsCommand');
    editorDocLog.info(' - merging "$firstNodeId" <- "$secondNodeId"');
    final secondNode = document.getNodeById(secondNodeId);
    if (secondNode is! TextNode) {
      editorDocLog.info('WARNING: Cannot merge node of type: $secondNode into node above.');
      return;
    }

    final nodeAbove = document.getNodeBefore(secondNode);
    if (nodeAbove == null) {
      editorDocLog.info('At top of document. Cannot merge with node above.');
      return;
    }
    if (nodeAbove.id != firstNodeId) {
      editorDocLog.info('The specified `firstNodeId` is not the node before `secondNodeId`.');
      return;
    }
    if (nodeAbove is! TextNode) {
      editorDocLog.info('Cannot merge ParagraphNode into node of type: $nodeAbove');
      return;
    }

    // Combine the text and delete the currently selected node.
    nodeAbove.text = nodeAbove.text.copyAndAppend(secondNode.text);
    bool didRemove = transaction.deleteNode(secondNode);
    if (!didRemove) {
      editorDocLog.info('ERROR: Failed to delete the currently selected node from the document.');
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
    editorDocLog.info('Executing SplitParagraphCommand');

    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      editorDocLog.info('WARNING: Cannot split paragraph for node of type: $node.');
      return;
    }

    final text = node.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = text.copyText(splitPosition.offset);
    editorDocLog.info('Splitting paragraph:');
    editorDocLog.info(' - start text: "${startText.text}"');
    editorDocLog.info(' - end text: "${endText.text}"');

    // Change the current nodes content to just the text before the caret.
    editorDocLog.info(' - changing the original paragraph text due to split');
    node.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node. And create a
    // new copy of the metadata if `replicateExistingMetdata` is true.
    final newNode = ParagraphNode(
      id: newNodeId,
      text: endText,
      metadata: replicateExistingMetdata ? {...node.metadata} : {},
    );

    // Insert the new node after the current node.
    editorDocLog.info(' - inserting new node in document');
    transaction.insertNodeAfter(
      existingNode: node,
      newNode: newNode,
    );

    editorDocLog.info(' - inserted new node: ${newNode.id} after old one: ${node.id}');
  }
}

ExecutionInstruction anyCharacterToInsertInParagraph({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  // Do nothing if CMD or CTRL are pressed because this signifies an attempted
  // shortcut.
  if (keyEvent.isControlPressed || keyEvent.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }

  var character = keyEvent.character;
  if (character == null || character == '') {
    return ExecutionInstruction.continueExecution;
  }

  if (LogicalKeyboardKey.isControlCharacter(keyEvent.character!) || keyEvent.isArrowKeyPressed) {
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
    editorDocLog.info('Executing DeleteParagraphsCommand');
    editorDocLog.info(' - deleting "$nodeId"');
    final node = document.getNodeById(nodeId);
    if (node is! TextNode) {
      editorDocLog.shout('WARNING: Cannot delete node of type: $node.');
      return;
    }

    bool didRemove = transaction.deleteNode(node);
    if (!didRemove) {
      editorDocLog.shout('ERROR: Failed to delete node "$node" from the document.');
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
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
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
    editorLayoutLog.shout(
        'ERROR: Building a paragraph component but the selection is not a TextSelection: ${componentContext.documentNode.id}');
  }
  final showCaret = componentContext.showCaret && componentContext.nodeSelection != null
      ? componentContext.nodeSelection!.isExtent
      : false;
  final highlightWhenEmpty =
      componentContext.nodeSelection == null ? false : componentContext.nodeSelection!.highlightWhenEmpty;

  editorLayoutLog.finer(' - ${componentContext.documentNode.id}: ${componentContext.nodeSelection}');
  if (showCaret) {
    editorLayoutLog.finer('   - ^ showing caret');
  }

  editorLayoutLog.finer(' - building a paragraph with selection:');
  editorLayoutLog.finer('   - base: ${textSelection?.base}');
  editorLayoutLog.finer('   - extent: ${textSelection?.extent}');

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

  final selectionColor =
      (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle?)?.selectionColor ??
          const Color(0x00000000);

  final caretColor = (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle?)?.textCaretColor ??
      const Color(0x00000000);

  return TextComponent(
    key: componentContext.componentKey,
    text: (componentContext.documentNode as TextNode).text,
    textStyleBuilder: componentContext.extensions[textStylesExtensionKey],
    metadata: (componentContext.documentNode as TextNode).metadata,
    textAlign: textAlign,
    textDirection: textDirection,
    textSelection: textSelection,
    selectionColor: selectionColor,
    showCaret: showCaret,
    caretColor: caretColor,
    highlightWhenEmpty: highlightWhenEmpty,
  );
}
