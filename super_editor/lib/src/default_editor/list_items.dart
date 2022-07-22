import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';

import '../core/document.dart';
import '../core/document_editor.dart';
import 'document_input_keyboard.dart';
import 'layout_single_column/layout_single_column.dart';
import 'paragraph.dart';
import 'text.dart';

final _log = Logger(scope: 'list_items.dart');

class ListItemNode extends TextNode {
  ListItemNode.ordered({
    required String id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
    int indent = 0,
  })  : type = ListItemType.ordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
        ) {
    putMetadataValue("blockType", const NamedAttribution("listItem"));
  }

  ListItemNode.unordered({
    required String id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
    int indent = 0,
  })  : type = ListItemType.unordered,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
        ) {
    putMetadataValue("blockType", const NamedAttribution("listItem"));
  }

  ListItemNode({
    required String id,
    required ListItemType itemType,
    required AttributedText text,
    Map<String, dynamic>? metadata,
    int indent = 0,
  })  : type = itemType,
        _indent = indent,
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

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is ListItemNode && type == other.type && indent == other.indent && text == other.text;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ListItemNode &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _indent == other._indent;

  @override
  int get hashCode => super.hashCode ^ type.hashCode ^ _indent.hashCode;
}

enum ListItemType {
  ordered,
  unordered,
}

class ListItemComponentBuilder implements ComponentBuilder {
  const ListItemComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ListItemNode) {
      return null;
    }

    int? ordinalValue;
    if (node.type == ListItemType.ordered) {
      ordinalValue = 1;
      DocumentNode? nodeAbove = document.getNodeBefore(node);
      while (nodeAbove != null &&
          nodeAbove is ListItemNode &&
          nodeAbove.type == ListItemType.ordered &&
          nodeAbove.indent >= node.indent) {
        if (nodeAbove.indent == node.indent) {
          ordinalValue = ordinalValue! + 1;
        }
        nodeAbove = document.getNodeBefore(nodeAbove);
      }
    }

    return ListItemComponentViewModel(
      nodeId: node.id,
      type: node.type,
      indent: node.indent,
      ordinalValue: ordinalValue,
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ListItemComponentViewModel) {
      return null;
    }

    if (componentViewModel.type == ListItemType.unordered) {
      return UnorderedListItemComponent(
        textKey: componentContext.componentKey,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        indent: componentViewModel.indent,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
      );
    } else if (componentViewModel.type == ListItemType.ordered) {
      return OrderedListItemComponent(
        textKey: componentContext.componentKey,
        indent: componentViewModel.indent,
        listIndex: componentViewModel.ordinalValue!,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
      );
    }

    editorLayoutLog
        .warning("Tried to build a component for a list item view model without a list item type: $componentViewModel");
    return null;
  }
}

class ListItemComponentViewModel extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  ListItemComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required this.type,
    this.ordinalValue,
    required this.indent,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  ListItemType type;
  int? ordinalValue;
  int indent;
  AttributedText text;

  @override
  AttributionStyleBuilder textStyleBuilder;
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment;
  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty;

  @override
  ListItemComponentViewModel copy() {
    return ListItemComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      type: type,
      ordinalValue: ordinalValue,
      indent: indent,
      text: text,
      textStyleBuilder: textStyleBuilder,
      textDirection: textDirection,
      selection: selection,
      selectionColor: selectionColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ListItemComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          type == other.type &&
          ordinalValue == other.ordinalValue &&
          indent == other.indent &&
          text == other.text &&
          textStyleBuilder == other.textStyleBuilder &&
          textDirection == other.textDirection &&
          selection == other.selection &&
          selectionColor == other.selectionColor;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      type.hashCode ^
      ordinalValue.hashCode ^
      indent.hashCode ^
      text.hashCode ^
      textStyleBuilder.hashCode ^
      textDirection.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode;
}

/// Displays a un-ordered list item in a document.
///
/// Supports various indentation levels, e.g., 1, 2, 3, ...
class UnorderedListItemComponent extends StatelessWidget {
  const UnorderedListItemComponent({
    Key? key,
    required this.textKey,
    required this.text,
    required this.styleBuilder,
    this.dotBuilder = _defaultUnorderedListItemDotBuilder,
    this.indent = 0,
    this.indentCalculator = _defaultIndentCalculator,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final UnorderedListItemDotBuilder dotBuilder;
  final int indent;
  final double Function(TextStyle, int indent) indentCalculator;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final textStyle = styleBuilder({});
    final indentSpace = indentCalculator(textStyle, indent);
    final lineHeight = textStyle.fontSize! * (textStyle.height ?? 1.25);
    const manualVerticalAdjustment = 3.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: indentSpace,
          margin: const EdgeInsets.only(top: manualVerticalAdjustment),
          decoration: BoxDecoration(
            border: showDebugPaint ? Border.all(width: 1, color: Colors.grey) : null,
          ),
          child: SizedBox(
            height: lineHeight,
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
            highlightWhenEmpty: highlightWhenEmpty,
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
    Key? key,
    required this.textKey,
    required this.listIndex,
    required this.text,
    required this.styleBuilder,
    this.numeralBuilder = _defaultOrderedListItemNumeralBuilder,
    this.indent = 0,
    this.indentCalculator = _defaultIndentCalculator,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final int listIndex;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final OrderedListItemNumeralBuilder numeralBuilder;
  final int indent;
  final double Function(TextStyle, int indent) indentCalculator;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final textStyle = styleBuilder({});
    final indentSpace = indentCalculator(textStyle, indent);
    final lineHeight = textStyle.fontSize! * (textStyle.height ?? 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: indentSpace,
          height: lineHeight,
          decoration: BoxDecoration(
            border: showDebugPaint ? Border.all(width: 1, color: Colors.grey) : null,
          ),
          child: SizedBox(
            height: lineHeight,
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
            highlightWhenEmpty: highlightWhenEmpty,
            showDebugPaint: showDebugPaint,
          ),
        ),
      ],
    );
  }
}

typedef OrderedListItemNumeralBuilder = Widget Function(BuildContext, OrderedListItemComponent);

double _defaultIndentCalculator(TextStyle textStyle, int indent) {
  return (textStyle.fontSize! * 0.60) * 4 * (indent + 1);
}

Widget _defaultOrderedListItemNumeralBuilder(BuildContext context, OrderedListItemComponent component) {
  return OverflowBox(
    maxWidth: double.infinity,
    maxHeight: double.infinity,
    child: Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 5.0),
        child: Text(
          '${component.listIndex}.',
          textAlign: TextAlign.right,
          style: component.styleBuilder({}).copyWith(),
        ),
      ),
    ),
  );
}

class IndentListItemCommand implements EditorCommand {
  IndentListItemCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    // TODO: figure out how node changes should work in terms of
    //       a DocumentEditorTransaction (#67)
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;
    if (listItem.indent >= 6) {
      _log.log('IndentListItemCommand', 'WARNING: Editor does not support an indent level beyond 6.');
      return;
    }

    listItem.indent += 1;
  }
}

class UnIndentListItemCommand implements EditorCommand {
  UnIndentListItemCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;
    if (listItem.indent > 0) {
      // TODO: figure out how node changes should work in terms of
      //       a DocumentEditorTransaction (#67)
      listItem.indent -= 1;
    } else {
      ConvertListItemToParagraphCommand(
        nodeId: nodeId,
      ).execute(document, transaction);
    }
  }
}

class ConvertListItemToParagraphCommand implements EditorCommand {
  ConvertListItemToParagraphCommand({
    required this.nodeId,
    this.paragraphMetadata,
  });

  final String nodeId;
  final Map<String, dynamic>? paragraphMetadata;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final node = document.getNodeById(nodeId);
    final listItem = node as ListItemNode;

    final newParagraphNode = ParagraphNode(
      id: listItem.id,
      text: listItem.text,
      metadata: paragraphMetadata ?? {},
    );
    transaction.replaceNode(oldNode: listItem, newNode: newParagraphNode);
  }
}

class ConvertParagraphToListItemCommand implements EditorCommand {
  ConvertParagraphToListItemCommand({
    required this.nodeId,
    required this.type,
  });

  final String nodeId;
  final ListItemType type;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final node = document.getNodeById(nodeId);
    final paragraphNode = node as ParagraphNode;

    final newListItemNode = ListItemNode(
      id: paragraphNode.id,
      itemType: type,
      text: paragraphNode.text,
    );
    transaction.replaceNode(oldNode: paragraphNode, newNode: newListItemNode);
  }
}

class ChangeListItemTypeCommand implements EditorCommand {
  ChangeListItemTypeCommand({
    required this.nodeId,
    required this.newType,
  });

  final String nodeId;
  final ListItemType newType;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final existingListItem = document.getNodeById(nodeId) as ListItemNode;

    final newListItemNode = ListItemNode(
      id: existingListItem.id,
      itemType: newType,
      text: existingListItem.text,
    );
    transaction.replaceNode(oldNode: existingListItem, newNode: newListItemNode);
  }
}

class SplitListItemCommand implements EditorCommand {
  SplitListItemCommand({
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
    final listItemNode = node as ListItemNode;
    final text = listItemNode.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = splitPosition.offset < text.text.length ? text.copyText(splitPosition.offset) : AttributedText();
    _log.log('SplitListItemCommand', 'Splitting list item:');
    _log.log('SplitListItemCommand', ' - start text: "$startText"');
    _log.log('SplitListItemCommand', ' - end text: "$endText"');

    // Change the current node's content to just the text before the caret.
    _log.log('SplitListItemCommand', ' - changing the original list item text due to split');
    // TODO: figure out how node changes should work in terms of
    //       a DocumentEditorTransaction (#67)
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
    _log.log('SplitListItemCommand', ' - inserting new node in document');
    transaction.insertNodeAfter(
      existingNode: node,
      newNode: newNode,
    );

    _log.log('SplitListItemCommand', ' - inserted new node: ${newNode.id} after old one: ${node.id}');
  }
}

ExecutionInstruction tabToIndentListItem({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }
  if (keyEvent.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final wasIndented = editContext.commonOps.indentListItem();

  return wasIndented ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction shiftTabToUnIndentListItem({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }
  if (!keyEvent.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final wasIndented = editContext.commonOps.unindentListItem();

  return wasIndented ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction backspaceToUnIndentListItem({
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
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }
  if ((editContext.composer.selection!.extent.nodePosition as TextPosition).offset > 0) {
    return ExecutionInstruction.continueExecution;
  }

  final wasIndented = editContext.commonOps.unindentListItem();

  return wasIndented ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction splitListItemWhenEnterPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.editor.document.getNodeById(editContext.composer.selection!.extent.nodeId);
  if (node is! ListItemNode) {
    return ExecutionInstruction.continueExecution;
  }

  final didSplitListItem = editContext.commonOps.insertBlockLevelNewline();
  return didSplitListItem ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}
