import 'package:example/spikes/editor_abstractions/default_editor/list_items.dart';
import 'package:example/spikes/editor_abstractions/selectable_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/document/rich_text_document.dart';
import '../core/document/document_editor.dart';
import '../core/layout/document_layout.dart';
import '../core/selection/editor_selection.dart';
import '../core/composition/document_composer.dart';
import '_text_tools.dart';
import 'text.dart';

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

ExecutionInstruction insertCharacterInParagraph({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is ParagraphNode && isCharacterKey(keyEvent.logicalKey) && currentSelection.value.isCollapsed) {
    print(' - this is a paragraph');
    // Delegate the action to the standard insert-character behavior.
    insertCharacterInTextComposable(
      document: document,
      editor: editor,
      documentLayout: documentLayout,
      currentSelection: currentSelection,
      nodeSelections: nodeSelections,
      keyEvent: keyEvent,
    );

    final text = node.text;
    final textSelection = currentSelection.value.extent.nodePosition as TextPosition;

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
          ? UnorderedListItemNode(id: node.id, text: adjustedText)
          : OrderedListItemNode(id: node.id, text: adjustedText);
      final nodeIndex = document.getNodeIndex(node);
      document
        ..deleteNodeAt(nodeIndex)
        ..insertNodeAt(nodeIndex, newNode);

      // We removed some text at the beginning of the list item.
      // Move the selection back by that same amount.
      final textPosition = currentSelection.value.extent.nodePosition as TextPosition;
      currentSelection.value = DocumentSelection.collapsed(
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
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is ParagraphNode && keyEvent.logicalKey == LogicalKeyboardKey.enter && currentSelection.value.isCollapsed) {
    final text = node.text;
    final caretIndex = (currentSelection.value.extent.nodePosition as TextPosition).offset;
    // final startText = text.text.substring(0, caretIndex);
    final startText = text.copyText(0, caretIndex);
    // final endText = caretIndex < text.text.length ? text.text.substring(caretIndex) : '';
    final endText = caretIndex < text.text.length ? text.copyText(caretIndex) : AttributedText();
    print('Splitting paragraph:');
    print(' - start text: "$startText"');
    print(' - end text: "$endText"');

    // Change the current nodes content to just the text before the caret.
    print(' - changing the original paragraph text due to split');
    node.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = ParagraphNode(
      id: RichTextDocument.createNodeId(),
      text: endText,
      textAlign: node.textAlign,
    );

    // Insert the new node after the current node.
    print(' - inserting new node in document');
    document.insertNodeAfter(
      previousNode: node,
      newNode: newNode,
    );

    print(' - inserted new node: ${newNode.id} after old one: ${node.id}');

    // Place the caret at the beginning of the new paragraph node.
    currentSelection.value = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: newNode.id,
        // TODO: change this from TextPosition to a generic node position
        nodePosition: TextPosition(offset: 0),
      ),
    );

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}
