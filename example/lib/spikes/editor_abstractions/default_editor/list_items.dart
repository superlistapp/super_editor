import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:example/spikes/editor_abstractions/core/edit_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/attributed_text.dart';
import '../core/document.dart';
import '../core/document_editor.dart';
import '../core/document_selection.dart';
import 'document_interaction.dart';
import 'paragraph.dart';
import 'styles.dart';
import 'text.dart';

class ListItemNode extends TextNode {
  ListItemNode.ordered({
    @required String id,
    AttributedText text,
    Map<String, dynamic> metadata,
    int indent = 0,
  })  : type = ListItemType.ordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
        );

  ListItemNode.unordered({
    @required String id,
    AttributedText text,
    Map<String, dynamic> metadata,
    int indent = 0,
  })  : type = ListItemType.unordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
        );

  ListItemNode({
    @required String id,
    @required this.type,
    AttributedText text,
    Map<String, dynamic> metadata,
    int indent = 0,
  })  : _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
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
    @required this.styleBuilder,
    this.dotBuilder = _defaultUnorderedListItemDotBuilder,
    this.indent = 0,
    this.indentExtent = 25,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.hasCaret = false,
    this.caretColor = Colors.black,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final UnorderedListItemDotBuilder dotBuilder;
  final int indent;
  final double indentExtent;
  final TextSelection textSelection;
  final Color selectionColor;
  final bool hasCaret;
  final Color caretColor;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final indentSpace = indentExtent * (indent + 1);
    final firstLineHeight = styleBuilder({}).fontSize;
    final manualVerticalAdjustment = 2.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: manualVerticalAdjustment),
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: showDebugPaint ? Colors.grey : Colors.transparent),
          ),
          child: SizedBox(
            width: indentSpace,
            height: firstLineHeight,
            child: dotBuilder(context, this),
          ),
        ),
        Expanded(
          child: TextComponent(
            key: textKey,
            text: text,
            textStyleBuilder: styleBuilder,
            textSelection: textSelection,
            selectionColor: selectionColor,
            hasCaret: hasCaret,
            caretColor: caretColor,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}

typedef UnorderedListItemDotBuilder = Widget Function(BuildContext, UnorderedListItemComponent);

Widget _defaultUnorderedListItemDotBuilder(BuildContext context, UnorderedListItemComponent component) {
  return Align(
    alignment: Alignment.centerRight,
    child: Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: component.styleBuilder({}).color,
      ),
    ),
  );
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
    @required this.styleBuilder,
    this.numeralBuilder = _defaultOrderedListItemNumeralBuilder,
    this.indent = 0,
    this.indentExtent = 25,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.hasCaret = false,
    this.caretColor = Colors.black,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final int listIndex;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final OrderedListItemNumeralBuilder numeralBuilder;
  final int indent;
  final double indentExtent;
  final TextSelection textSelection;
  final Color selectionColor;
  final bool hasCaret;
  final Color caretColor;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final indentSpace = indentExtent * (indent + 1);
    final firstLineHeight = styleBuilder({}).fontSize;
    final manualVerticalAdjustment = 2.0;
    final manualHeightAdjustment = firstLineHeight * 0.15;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: indentSpace,
          height: firstLineHeight + manualHeightAdjustment,
          margin: EdgeInsets.only(top: manualVerticalAdjustment),
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: showDebugPaint ? Colors.grey : Colors.transparent),
          ),
          child: SizedBox(
            width: indentSpace,
            height: firstLineHeight,
            child: numeralBuilder(context, this),
          ),
        ),
        Expanded(
          child: TextComponent(
            key: textKey,
            text: text,
            textStyleBuilder: styleBuilder,
            textSelection: textSelection,
            selectionColor: selectionColor,
            hasCaret: hasCaret,
            caretColor: caretColor,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}

typedef OrderedListItemNumeralBuilder = Widget Function(BuildContext, OrderedListItemComponent);

Widget _defaultOrderedListItemNumeralBuilder(BuildContext context, OrderedListItemComponent component) {
  return OverflowBox(
    maxHeight: double.infinity,
    child: Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Text(
          '${component.listIndex}.',
          style: component.styleBuilder({}).copyWith(),
        ),
      ),
    ),
  );
}

class IndentListItemCommand implements EditorCommand {
  IndentListItemCommand({
    @required this.nodeId,
  }) : assert(nodeId != null);

  final String nodeId;

  @override
  void execute(Document document, DocumentEditor editor) {
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
  void execute(Document document, DocumentEditor editor) {
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
      editor
        ..deleteNodeAt(listItemIndex)
        ..insertNodeAt(listItemIndex, newParagraphNode);
    }
  }
}

class SplitListItemCommand implements EditorCommand {
  SplitListItemCommand({
    @required this.nodeId,
    @required this.splitPosition,
    @required this.newNodeId,
  })  : assert(nodeId != null),
        assert(splitPosition != null);

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;

  @override
  void execute(Document document, DocumentEditor editor) {
    final node = document.getNodeById(nodeId);
    final listItemNode = node as ListItemNode;
    final text = listItemNode.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = splitPosition.offset < text.text.length ? text.copyText(splitPosition.offset) : AttributedText();
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
    editor.insertNodeAfter(
      previousNode: node,
      newNode: newNode,
    );

    print(' - inserted new node: ${newNode.id} after old one: ${node.id}');
  }
}

ExecutionInstruction indentListItemWhenBackspaceIsPressed({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  if (!editContext.composer.selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = editContext.composer.selection.extent.nodePosition;
  if (textPosition is! TextPosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.editor.executeCommand(
    IndentListItemCommand(nodeId: node.id),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction unindentListItemWhenBackspaceIsPressed({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  if (!editContext.composer.selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final textPosition = editContext.composer.selection.extent.nodePosition;
  if (textPosition is! TextPosition || textPosition.offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  editContext.editor.executeCommand(
    UnIndentListItemCommand(nodeId: node.id),
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction splitListItemWhenEnterPressed({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(editContext.composer.selection.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  final newNodeId = Document.createNodeId();

  editContext.editor.executeCommand(
    SplitListItemCommand(
      nodeId: node.id,
      splitPosition: editContext.composer.selection.extent.nodePosition as TextPosition,
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

Widget unorderedListItemBuilder(ComponentContext componentContext) {
  if (componentContext.currentNode is! ListItemNode ||
      (componentContext.currentNode as ListItemNode).type != ListItemType.unordered) {
    return null;
  }
  final textSelection =
      componentContext.nodeSelection == null ? null : componentContext.nodeSelection.nodeSelection as TextSelection;
  final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;

  return UnorderedListItemComponent(
    textKey: componentContext.componentKey,
    text: (componentContext.currentNode as ListItemNode).text,
    styleBuilder: componentContext.extensions[textStylesExtensionKey],
    indent: (componentContext.currentNode as ListItemNode).indent,
    textSelection: textSelection,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    hasCaret: hasCursor,
    caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
    showDebugPaint: componentContext.showDebugPaint,
  );
}

Widget orderedListItemBuilder(ComponentContext componentContext) {
  if (componentContext.currentNode is! ListItemNode ||
      (componentContext.currentNode as ListItemNode).type != ListItemType.ordered) {
    return null;
  }

  int index = 1;
  DocumentNode nodeAbove = componentContext.document.getNodeBefore(componentContext.currentNode);
  while (nodeAbove != null &&
      nodeAbove is ListItemNode &&
      nodeAbove.type == ListItemType.ordered &&
      nodeAbove.indent >= (componentContext.currentNode as ListItemNode).indent) {
    if ((nodeAbove as ListItemNode).indent == (componentContext.currentNode as ListItemNode).indent) {
      index += 1;
    }
    nodeAbove = componentContext.document.getNodeBefore(nodeAbove);
  }

  final textSelection =
      componentContext.nodeSelection == null ? null : componentContext.nodeSelection.nodeSelection as TextSelection;
  final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;

  return OrderedListItemComponent(
    textKey: componentContext.componentKey,
    listIndex: index,
    text: (componentContext.currentNode as ListItemNode).text,
    styleBuilder: componentContext.extensions[textStylesExtensionKey],
    textSelection: textSelection,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    hasCaret: hasCursor,
    caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
    indent: (componentContext.currentNode as ListItemNode).indent,
    showDebugPaint: componentContext.showDebugPaint,
  );
}
