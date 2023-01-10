import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

import '../core/document.dart';
import '../core/document_editor.dart';
import 'layout_single_column/layout_single_column.dart';
import 'paragraph.dart';
import 'text.dart';
import 'text_tools.dart';

// ignore: unused_element
final _log = Logger(scope: 'blockquote.dart');

class BlockquoteComponentBuilder implements ComponentBuilder {
  const BlockquoteComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ParagraphNode) {
      return null;
    }
    if (node.getMetadataValue('blockType') != blockquoteAttribution) {
      return null;
    }

    final textDirection = getParagraphDirection(node.text.text);

    TextAlign textAlign = (textDirection == TextDirection.ltr) ? TextAlign.left : TextAlign.right;
    final textAlignName = node.getMetadataValue('textAlign');
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

    final viewModel = BlockquoteComponentViewModel(
      nodeId: node.id,
      text: node.text,
      backgroundColor: const Color(0x00000000),
      borderRadius: BorderRadius.zero,
      textDirection: textDirection,
      textAlignment: textAlign,
      selectionColor: const Color(0x00000000),
    );

    return viewModel;
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! BlockquoteComponentViewModel) {
      return null;
    }

    return BlockquoteComponent(
      textKey: componentContext.componentKey,
      text: componentViewModel.text,
      styleBuilder: componentViewModel.textStyleBuilder,
      backgroundColor: componentViewModel.backgroundColor,
      borderRadius: componentViewModel.borderRadius,
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
    );
  }
}

class BlockquoteComponentViewModel extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  BlockquoteComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required this.text,
    TextComponentTextStyles? textStyler,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    required this.backgroundColor,
    required this.borderRadius,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding) {
    if (textStyler != null) {
      super.textStyler = textStyler;
    }
  }

  @override
  AttributedText text;
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

  Color backgroundColor;
  BorderRadius borderRadius;

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);
    backgroundColor = styles["backgroundColor"] ?? Colors.transparent;
    borderRadius = styles["borderRadius"] ?? BorderRadius.zero;
  }

  @override
  BlockquoteComponentViewModel copy() {
    return BlockquoteComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      text: text,
      textStyler: textStyler,
      textDirection: textDirection,
      textAlignment: textAlignment,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      selection: selection,
      selectionColor: selectionColor,
      highlightWhenEmpty: highlightWhenEmpty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is BlockquoteComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          backgroundColor == other.backgroundColor &&
          borderRadius == other.borderRadius &&
          isTextViewModelEquivalent(other);

  @override
  int get hashCode =>
      super.hashCode ^ nodeId.hashCode ^ backgroundColor.hashCode ^ borderRadius.hashCode ^ textHashCode;
}

/// Displays a blockquote in a document.
class BlockquoteComponent extends StatelessWidget {
  const BlockquoteComponent({
    Key? key,
    required this.textKey,
    required this.text,
    required this.styleBuilder,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    required this.backgroundColor,
    required this.borderRadius,
    this.showDebugPaint = false,
    this.highlightWhenEmpty = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final TextSelection? textSelection;
  final Color selectionColor;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: backgroundColor,
        ),
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
    );
  }
}

class ConvertBlockquoteToParagraphCommand implements EditorCommand {
  ConvertBlockquoteToParagraphCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  List<DocumentChangeEvent> execute(EditorContext context, CommandExpander expandActiveCommand) {
    final document = context.find<MutableDocument>("document");
    final node = document.getNodeById(nodeId);
    final blockquote = node as ParagraphNode;
    final newParagraphNode = ParagraphNode(
      id: blockquote.id,
      text: blockquote.text,
    );
    document.replaceNode(oldNode: blockquote, newNode: newParagraphNode);

    return [NodeChangeEvent(nodeId)];
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

  if (editContext.composer.selectionComponent.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  final baseNode =
      editContext.editor.document.getNodeById(editContext.composer.selectionComponent.selection!.base.nodeId)!;
  final extentNode =
      editContext.editor.document.getNodeById(editContext.composer.selectionComponent.selection!.extent.nodeId)!;
  if (baseNode.id != extentNode.id) {
    return ExecutionInstruction.continueExecution;
  }
  if (extentNode is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }
  if (extentNode.getMetadataValue('blockType') != blockquoteAttribution) {
    return ExecutionInstruction.continueExecution;
  }

  final didInsertNewline = editContext.commonOps.insertPlainText('\n');
  return didInsertNewline ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction splitBlockquoteWhenEnterPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selectionComponent.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  final baseNode =
      editContext.editor.document.getNodeById(editContext.composer.selectionComponent.selection!.base.nodeId)!;
  final extentNode =
      editContext.editor.document.getNodeById(editContext.composer.selectionComponent.selection!.extent.nodeId)!;
  if (baseNode.id != extentNode.id) {
    return ExecutionInstruction.continueExecution;
  }
  if (extentNode is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }
  if (extentNode.getMetadataValue('blockType') != blockquoteAttribution) {
    return ExecutionInstruction.continueExecution;
  }

  final didSplit = editContext.commonOps.insertBlockLevelNewline();
  return didSplit ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
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
  List<DocumentChangeEvent> execute(EditorContext context, CommandExpander expandActiveCommand) {
    final document = context.find<MutableDocument>("document");
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
      metadata: isNewNodeABlockquote ? {'blockType': blockquoteAttribution} : {},
    );

    // Insert the new node after the current node.
    document.insertNodeAfter(
      existingNode: node,
      newNode: newNode,
    );

    return [
      NodeChangeEvent(nodeId),
      NodeInsertedEvent(newNodeId),
    ];
  }
}
