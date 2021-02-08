import 'package:example/spikes/editor_abstractions/selectable_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/document_composer.dart';
import '../core/document_editor.dart';
import '../core/document.dart';
import '../core/document_selection.dart';
import 'paragraph.dart';
import 'text.dart';

class ListItemNode extends TextNode {
  ListItemNode.ordered({
    @required String id,
    AttributedText text,
    int indent = 0,
  })  : type = ListItemType.ordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          textAlign: TextAlign.left,
          textType: 'paragraph',
        );

  ListItemNode.unordered({
    @required String id,
    AttributedText text,
    int indent = 0,
  })  : type = ListItemType.unordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          textAlign: TextAlign.left,
          textType: 'paragraph',
        );

  ListItemNode({
    @required String id,
    @required this.type,
    AttributedText text,
    int indent = 0,
  })  : _indent = indent,
        super(
          id: id,
          text: text,
          textAlign: TextAlign.left,
          textType: 'paragraph',
        );

  final ListItemType type;

  int _indent;
  int get indent => _indent;
  set indent(int newIndent) {
    if (newIndent != _indent) {
      _indent = newIndent;
      notifyListeners();
    }
  }
}

enum ListItemType {
  ordered,
  unordered,
}

/// Displays a un-ordered list item in a document.
///
/// Supports various indentation levels, e.g., 1, 2, 3, ...
class UnorderedListItemComponent extends StatelessWidget {
  const UnorderedListItemComponent({
    Key key,
    @required this.textKey,
    this.text,
    this.textStyle,
    this.indent = 0,
    this.textSelection,
    this.hasCursor = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
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
            child: Container(
              padding: const EdgeInsets.only(right: 15.0),
              decoration: BoxDecoration(
                border: Border.all(width: 1, color: showDebugPaint ? Colors.grey : Colors.transparent),
              ),
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
            key: textKey,
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
    this.text,
    this.numeralTextStyle,
    this.textStyle,
    this.indent = 0,
    this.textSelection,
    this.hasCursor = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final int listIndex;
  final AttributedText text;
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
            child: Container(
              padding: const EdgeInsets.only(right: 15.0),
              decoration: BoxDecoration(
                border: Border.all(width: 1, color: showDebugPaint ? Colors.grey : Colors.transparent),
              ),
              child: Text(
                '$listIndex',
                style: numeralTextStyle,
              ),
            ),
          ),
        ),
        Expanded(
          child: TextComponent(
            key: textKey,
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

class IndentListItemCommand implements EditorCommand {
  IndentListItemCommand({
    @required this.nodeId,
  }) : assert(nodeId != null);

  final String nodeId;

  @override
  void execute(RichTextDocument document) {
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;
    if (listItem.indent >= 6) {
      print('WARNING: Editor does not support an indent level beyond 6.');
      return;
    }

    listItem.indent += 1;
  }
}

class UnIndentListItemCommand implements EditorCommand {
  UnIndentListItemCommand({
    @required this.nodeId,
  }) : assert(nodeId != null);

  final String nodeId;

  @override
  void execute(RichTextDocument document) {
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;
    if (listItem.indent > 0) {
      listItem.indent -= 1;
    } else {
      // TODO: move node replacement to its own command.
      final newParagraphNode = ParagraphNode(
        id: listItem.id,
        text: listItem.text,
      );
      final listItemIndex = document.getNodeIndex(listItem);
      document
        ..deleteNodeAt(listItemIndex)
        ..insertNodeAt(listItemIndex, newParagraphNode);
    }
  }
}

class SplitListItemCommand implements EditorCommand {
  SplitListItemCommand({
    @required this.nodeId,
    @required this.textPosition,
    @required this.newNodeId,
  })  : assert(nodeId != null),
        assert(textPosition != null);

  final String nodeId;
  final TextPosition textPosition;
  final String newNodeId;

  @override
  void execute(RichTextDocument document) {
    final node = document.getNodeById(nodeId);
    final listItemNode = node as ListItemNode;
    final text = listItemNode.text;
    final startText = text.copyText(0, textPosition.offset);
    final endText = textPosition.offset < text.text.length ? text.copyText(textPosition.offset) : AttributedText();
    print('Splitting list item:');
    print(' - start text: "$startText"');
    print(' - end text: "$endText"');

    // Change the current node's content to just the text before the caret.
    print(' - changing the original list item text due to split');
    listItemNode.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = listItemNode.type == ListItemType.ordered
        ? ListItemNode.ordered(
            id: newNodeId,
            text: endText,
            indent: listItemNode.indent,
          )
        : ListItemNode.unordered(
            id: newNodeId,
            text: endText,
            indent: listItemNode.indent,
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

ExecutionInstruction indentListItemWhenBackspaceIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }

  final node = composerContext.document.getNodeById(composerContext.currentSelection.value.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  if (!composerContext.currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = composerContext.currentSelection.value.extent.nodePosition;
  if (textPosition is! TextPosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  composerContext.editor.executeCommand(
    IndentListItemCommand(nodeId: node.id),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction unindentListItemWhenBackspaceIsPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  final node = composerContext.document.getNodeById(composerContext.currentSelection.value.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  if (!composerContext.currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = composerContext.currentSelection.value.extent.nodePosition;
  if (textPosition is! TextPosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  composerContext.editor.executeCommand(
    UnIndentListItemCommand(nodeId: node.id),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction splitListItemWhenEnterPressed({
  @required ComposerContext composerContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }
  if (!composerContext.currentSelection.value.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = composerContext.document.getNodeById(composerContext.currentSelection.value.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  final newNodeId = RichTextDocument.createNodeId();

  composerContext.editor.executeCommand(
    SplitListItemCommand(
      nodeId: node.id,
      textPosition: composerContext.currentSelection.value.extent.nodePosition as TextPosition,
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
