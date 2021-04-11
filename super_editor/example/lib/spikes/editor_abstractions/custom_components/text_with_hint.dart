import 'package:example/spikes/editor_abstractions/core/document.dart';
import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:example/spikes/editor_abstractions/core/document_selection.dart';
import 'package:example/spikes/editor_abstractions/core/edit_context.dart';
import 'package:example/spikes/editor_abstractions/default_editor/document_interaction.dart';
import 'package:example/spikes/editor_abstractions/default_editor/paragraph.dart';
import 'package:example/spikes/editor_abstractions/default_editor/styles.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/attributed_text.dart';
import '../default_editor/text.dart';

/// Displays text in a document, and given `hintText` when there
/// is no content text and this component does not have the caret.
class TextWithHintComponent extends StatelessWidget {
  const TextWithHintComponent({
    Key key,
    @required this.documentComponentKey,
    @required this.text,
    @required this.styleBuilder,
    this.metadata = const {},
    @required this.hintText,
    this.textAlign,
    this.textSelection,
    this.hasCursor,
    this.highlightWhenEmpty,
    this.showDebugPaint,
  }) : super(key: key);

  final GlobalKey documentComponentKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final Map<String, dynamic> metadata;
  final String hintText;
  final TextAlign textAlign;
  final TextSelection textSelection;
  final bool hasCursor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final blockType = metadata['blockType'];

    final blockLevelText = text
      ..copyText(0)
      ..addAttribution(blockType, TextRange(start: 0, end: text.text.length - 1));

    print('Building TextWithHintComponent with key: $documentComponentKey');
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Stack(
        children: [
          Text(
            hintText,
            textAlign: textAlign,
            style: styleBuilder({blockType}).copyWith(
              color: const Color(0xFFC3C1C1),
            ),
          ),
          Positioned.fill(
            child: TextComponent(
              key: documentComponentKey,
              text: blockLevelText,
              textAlign: textAlign,
              textSelection: textSelection,
              hasCaret: hasCursor,
              textStyleBuilder: styleBuilder,
              highlightWhenEmpty: highlightWhenEmpty,
              showDebugPaint: showDebugPaint,
            ),
          ),
        ],
      ),
    );
  }
}

Widget titleHintBuilder(ComponentContext componentContext) {
  if (componentContext.currentNode is! ParagraphNode) {
    return null;
  }

  final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;
  if (componentContext.document.getNodeIndex(componentContext.currentNode) != 0 ||
      (componentContext.currentNode as TextNode).text.text.isNotEmpty ||
      hasCursor) {
    return null;
  }

  final textSelection =
      componentContext.nodeSelection == null || componentContext.nodeSelection.nodeSelection is! TextSelection
          ? null
          : componentContext.nodeSelection.nodeSelection as TextSelection;
  if (componentContext.nodeSelection != null && componentContext.nodeSelection.nodeSelection is! TextSelection) {
    print(
        'ERROR: Building a paragraph component but the selection is not a TextSelection: ${componentContext.currentNode.id}');
  }

  final highlightWhenEmpty =
      componentContext.nodeSelection == null ? false : componentContext.nodeSelection.highlightWhenEmpty;

  // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
  // if (hasCursor) {
  //   print('   - ^ has cursor');
  // }

  print(' - building a paragraph with selection:');
  print('   - base: ${textSelection?.base}');
  print('   - extent: ${textSelection?.extent}');

  var textAlign = TextAlign.left;
  final textAlignName = (componentContext.currentNode as TextNode).metadata['textAlign'];
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

  print(' - this is the title node');
  return TextWithHintComponent(
    documentComponentKey: componentContext.componentKey,
    text: (componentContext.currentNode as TextNode).text,
    styleBuilder: componentContext.extensions[textStylesExtensionKey],
    metadata: (componentContext.currentNode as TextNode).metadata,
    hintText: 'Enter your title',
    textAlign: textAlign,
    textSelection: textSelection,
    hasCursor: hasCursor,
    highlightWhenEmpty: highlightWhenEmpty,
    showDebugPaint: componentContext.showDebugPaint,
  );
}

Widget firstParagraphHintBuilder(ComponentContext componentContext) {
  if (componentContext.currentNode is! ParagraphNode) {
    return null;
  }

  final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;
  if (componentContext.document.nodes.length > 2 ||
      componentContext.document.getNodeIndex(componentContext.currentNode) != 1 ||
      (componentContext.currentNode as TextNode).text.text.isNotEmpty ||
      hasCursor) {
    return null;
  }

  final textSelection =
      componentContext.nodeSelection == null || componentContext.nodeSelection.nodeSelection is! TextSelection
          ? null
          : componentContext.nodeSelection.nodeSelection as TextSelection;
  if (componentContext.nodeSelection != null && componentContext.nodeSelection.nodeSelection is! TextSelection) {
    print(
        'ERROR: Building a paragraph component but the selection is not a TextSelection: ${componentContext.currentNode.id}');
  }
  final highlightWhenEmpty =
      componentContext.nodeSelection == null ? false : componentContext.nodeSelection.highlightWhenEmpty;

  // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
  // if (hasCursor) {
  //   print('   - ^ has cursor');
  // }

  print(' - building a paragraph with selection:');
  print('   - base: ${textSelection?.base}');
  print('   - extent: ${textSelection?.extent}');

  var textAlign = TextAlign.left;
  final textAlignName = (componentContext.currentNode as TextNode).metadata['textAlign'];
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

  print(' - this is the 1st paragraph node');
  return TextWithHintComponent(
    documentComponentKey: componentContext.componentKey,
    text: (componentContext.currentNode as TextNode).text,
    styleBuilder: componentContext.extensions[textStylesExtensionKey],
    metadata: (componentContext.currentNode as TextNode).metadata,
    hintText: 'Enter your content...',
    textAlign: textAlign,
    textSelection: textSelection,
    hasCursor: hasCursor,
    highlightWhenEmpty: highlightWhenEmpty,
    showDebugPaint: componentContext.showDebugPaint,
  );
}

ExecutionInstruction moveCaretFromTitleToFirstParagraph({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.editor.document.getNodeById(editContext.composer.selection.extent.nodeId);
  if (node is! ParagraphNode) {
    return ExecutionInstruction.continueExecution;
  }
  final nodeIndex = editContext.editor.document.getNodeIndex(node);
  if (nodeIndex != 0) {
    // This is not the title node.
    return ExecutionInstruction.continueExecution;
  }

  final nodeCount = editContext.editor.document.nodes.length;
  if (nodeCount != 2) {
    // There is some amount of existing content. Process the
    // enter key like normal.
    return ExecutionInstruction.continueExecution;
  }

  final nextNode = editContext.editor.document.getNodeAt(1);
  if (nextNode is! ParagraphNode || (nextNode as ParagraphNode).text.text.isNotEmpty) {
    // There's existing content. Process the enter key like
    // normal.
    return ExecutionInstruction.continueExecution;
  }

  // Move the document selection from the title to 1st paragraph.
  editContext.composer.selection = DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: nextNode.id,
      nodePosition: TextPosition(offset: 0),
    ),
  );

  return ExecutionInstruction.haltExecution;
}
