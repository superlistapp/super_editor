import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/document/rich_text_document.dart';
import '../core/document/document_editor.dart';
import '../core/layout/document_layout.dart';
import '../core/selection/editor_selection.dart';
import '../core/composition/document_composer.dart';
import 'paragraph.dart';
import 'text.dart';

abstract class ListItemNode extends TextNode {
  ListItemNode({
    @required String id,
    String text = '',
    int indent = 0,
  })  : _indent = indent,
        super(
          id: id,
          text: text,
          textAlign: TextAlign.left,
          textType: 'paragraph',
        );

  int _indent;
  int get indent => _indent;
  set indent(int newIndent) {
    if (newIndent != _indent) {
      _indent = newIndent;
      notifyListeners();
    }
  }

  bool tryToCombineWithOtherNode(DocumentNode other) {
    // TODO: implement node combinations
    print('WARNING: UnorderedListItemNode combining is not yet implemented.');
    return false;
  }
}

class UnorderedListItemNode extends ListItemNode {
  UnorderedListItemNode({
    @required String id,
    String text = '',
    int indent = 0,
  }) : super(
          id: id,
          text: text,
          indent: indent,
        );
}

class OrderedListItemNode extends ListItemNode {
  OrderedListItemNode({
    @required String id,
    String text = '',
    int indent = 0,
  }) : super(
          id: id,
          text: text,
          indent: indent,
        );
}

/// Displays a un-ordered list item in a document.
///
/// Supports various indentation levels, e.g., 1, 2, 3, ...
class UnorderedListItemComponent extends StatelessWidget {
  const UnorderedListItemComponent({
    Key key,
    @required this.textKey,
    this.text = '',
    this.textStyle,
    this.indent = 0,
    this.textSelection,
    this.hasCursor = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final String text;
  final TextStyle textStyle;
  final int indent;
  final TextSelection textSelection;
  final bool hasCursor;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final indentSpace = 25.0 * indent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 25 + indentSpace,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF000000),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: TextComponent(
            textKey: textKey,
            text: text,
            textStyle: textStyle,
            textSelection: textSelection,
            hasCursor: hasCursor,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}

/// Displays an ordered list item in a document.
///
/// Supports various indentation levels, e.g., 1, 2, 3, ...
class OrderedListItemComponent extends StatelessWidget {
  const OrderedListItemComponent({
    Key key,
    @required this.textKey,
    @required this.listIndex,
    this.text = '',
    this.numeralTextStyle,
    this.textStyle,
    this.indent = 0,
    this.textSelection,
    this.hasCursor = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final int listIndex;
  final String text;
  final TextStyle numeralTextStyle;
  final TextStyle textStyle;
  final int indent;
  final TextSelection textSelection;
  final bool hasCursor;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final indentSpace = 25.0 * indent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 25 + indentSpace,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: Text(
                '$listIndex',
                style: numeralTextStyle,
              ),
            ),
          ),
        ),
        Expanded(
          child: TextComponent(
            textKey: textKey,
            text: text,
            textStyle: textStyle,
            textSelection: textSelection,
            hasCursor: hasCursor,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}

ExecutionInstruction indentListItemWhenBackspaceIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  if (!currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = currentSelection.value.extent.nodePosition;
  if (textPosition is! TextPosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  final listItem = node as ListItemNode;
  if (listItem.indent >= 6) {
    print('WARNING: Editor does not support an indent level beyond 6.');
    return ExecutionInstruction.continueExecution;
  }

  listItem.indent += 1;

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction unindentListItemWhenBackspaceIsPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  if (!currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = currentSelection.value.extent.nodePosition;
  if (textPosition is! TextPosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  final listItem = node as ListItemNode;
  if (listItem.indent > 0) {
    listItem.indent -= 1;
  } else {
    final newParagraphNode = ParagraphNode(
      id: listItem.id,
      text: listItem.text,
    );
    final listItemIndex = document.getNodeIndex(listItem);
    document
      ..deleteNodeAt(listItemIndex)
      ..insertNodeAt(listItemIndex, newParagraphNode);
  }

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction splitListItemWhenEnterPressed({
  @required RichTextDocument document,
  @required DocumentEditor editor,
  @required DocumentLayoutState documentLayout,
  @required ValueNotifier<DocumentSelection> currentSelection,
  @required List<DocumentNodeSelection> nodeSelections,
  @required RawKeyEvent keyEvent,
}) {
  final node = document.getNodeById(currentSelection.value.extent.nodeId);
  if (node is ListItemNode && keyEvent.logicalKey == LogicalKeyboardKey.enter && currentSelection.value.isCollapsed) {
    final text = node.text;
    final caretIndex = (currentSelection.value.extent.nodePosition as TextPosition).offset;
    final startText = text.substring(0, caretIndex);
    final endText = caretIndex < text.length ? text.substring(caretIndex) : '';
    print('Splitting list item:');
    print(' - start text: "$startText"');
    print(' - end text: "$endText"');

    // Change the current node's content to just the text before the caret.
    print(' - changing the original list item text due to split');
    node.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = node is OrderedListItemNode
        ? OrderedListItemNode(
            id: RichTextDocument.createNodeId(),
            text: endText,
            indent: node.indent,
          )
        : UnorderedListItemNode(
            id: RichTextDocument.createNodeId(),
            text: endText,
            indent: node.indent,
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
