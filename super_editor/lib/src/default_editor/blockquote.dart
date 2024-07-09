import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

import '../core/document.dart';
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

    return BlockquoteComponentViewModel(
      nodeId: node.id,
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      backgroundColor: const Color(0x00000000),
      borderRadius: BorderRadius.zero,
      textDirection: textDirection,
      textAlignment: textAlign,
      selectionColor: const Color(0x00000000),
    );
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
      composingRegion: componentViewModel.composingRegion,
      showComposingUnderline: componentViewModel.showComposingUnderline,
    );
  }
}

class BlockquoteComponentViewModel extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  BlockquoteComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    required this.backgroundColor,
    required this.borderRadius,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  @override
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
  TextRange? composingRegion;
  @override
  bool showComposingUnderline;

  Color backgroundColor;
  BorderRadius borderRadius;

  @override
  void applyStyles(Map<String, dynamic> styles) {
    super.applyStyles(styles);
    backgroundColor = styles[Styles.backgroundColor] ?? Colors.transparent;
    borderRadius = styles[Styles.borderRadius] ?? BorderRadius.zero;
  }

  @override
  BlockquoteComponentViewModel copy() {
    return BlockquoteComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      text: text,
      textStyleBuilder: textStyleBuilder,
      textDirection: textDirection,
      textAlignment: textAlignment,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      selection: selection,
      selectionColor: selectionColor,
      highlightWhenEmpty: highlightWhenEmpty,
      composingRegion: composingRegion,
      showComposingUnderline: showComposingUnderline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is BlockquoteComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          text == other.text &&
          textDirection == other.textDirection &&
          textAlignment == other.textAlignment &&
          backgroundColor == other.backgroundColor &&
          borderRadius == other.borderRadius &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          highlightWhenEmpty == other.highlightWhenEmpty &&
          composingRegion == other.composingRegion &&
          showComposingUnderline == other.showComposingUnderline;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      text.hashCode ^
      textDirection.hashCode ^
      textAlignment.hashCode ^
      backgroundColor.hashCode ^
      borderRadius.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      highlightWhenEmpty.hashCode ^
      composingRegion.hashCode ^
      showComposingUnderline.hashCode;
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
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final TextSelection? textSelection;
  final Color selectionColor;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final bool highlightWhenEmpty;
  final TextRange? composingRegion;
  final bool showComposingUnderline;
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
          composingRegion: composingRegion,
          showComposingUnderline: showComposingUnderline,
          showDebugPaint: showDebugPaint,
        ),
      ),
    );
  }
}

class ConvertBlockquoteToParagraphCommand extends EditCommand {
  ConvertBlockquoteToParagraphCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    final blockquote = node as ParagraphNode;
    final newParagraphNode = ParagraphNode(
      id: blockquote.id,
      text: blockquote.text,
    );
    document.replaceNode(oldNode: blockquote, newNode: newParagraphNode);

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(nodeId),
      )
    ]);
  }
}

ExecutionInstruction insertNewlineInBlockquote({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  if (!HardwareKeyboard.instance.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  final baseNode = editContext.document.getNodeById(editContext.composer.selection!.base.nodeId)!;
  final extentNode = editContext.document.getNodeById(editContext.composer.selection!.extent.nodeId)!;
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
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  final baseNode = editContext.document.getNodeById(editContext.composer.selection!.base.nodeId)!;
  final extentNode = editContext.document.getNodeById(editContext.composer.selection!.extent.nodeId)!;
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

class SplitBlockquoteCommand extends EditCommand {
  SplitBlockquoteCommand({
    required this.nodeId,
    required this.splitPosition,
    required this.newNodeId,
  });

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    final blockquote = node as ParagraphNode;
    final text = blockquote.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = splitPosition.offset < text.length ? text.copyText(splitPosition.offset) : AttributedText();

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

    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(nodeId),
      ),
      DocumentEdit(
        NodeInsertedEvent(newNodeId, document.getNodeIndexById(newNodeId)),
      ),
    ]);
  }
}
