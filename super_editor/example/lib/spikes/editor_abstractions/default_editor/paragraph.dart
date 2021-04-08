import 'package:example/spikes/editor_abstractions/core/document_composer.dart';
import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:example/spikes/editor_abstractions/core/edit_context.dart';
import 'package:example/spikes/editor_abstractions/default_editor/horizontal_rule.dart';
import 'package:example/spikes/editor_abstractions/default_editor/image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:linkify/linkify.dart';

import '../core/attributed_text.dart';
import '../core/document.dart';
import '../core/document_editor.dart';
import '../core/document_selection.dart';
import '_text_tools.dart';
import 'document_interaction.dart';
import 'list_items.dart';
import 'styles.dart';
import 'text.dart';

class ParagraphNode extends TextNode {
  ParagraphNode({
    @required String id,
    AttributedText text,
    Map<String, dynamic> metadata,
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
    this.firstNodeId,
    this.secondNodeId,
  })  : assert(firstNodeId != null),
        assert(secondNodeId != null),
        assert(firstNodeId != secondNodeId);

  final String firstNodeId;
  final String secondNodeId;

  void execute(Document document, DocumentEditor editor) {
    print('Executing CombineParagraphsCommand');
    print(' - merging "$firstNodeId" <- "$secondNodeId"');
    final secondNode = document.getNodeById(secondNodeId);
    if (secondNode is! TextNode) {
      print('WARNING: Cannot merge node of type: $secondNode into node above.');
      return;
    }
    final paragraphNode = secondNode as TextNode;

    final nodeAbove = document.getNodeBefore(paragraphNode);
    if (nodeAbove == null) {
      print('At top of document. Cannot merge with node above.');
      return;
    }
    if (nodeAbove.id != firstNodeId) {
      print('The specified `firstNodeId` is not the node before `secondNodeId`.');
      return;
    }
    if (nodeAbove is! TextNode) {
      print('Cannot merge ParagraphNode into node of type: $nodeAbove');
      return;
    }

    final paragraphNodeAbove = nodeAbove as TextNode;

    // Combine the text and delete the currently selected node.
    paragraphNodeAbove.text = paragraphNodeAbove.text.copyAndAppend(paragraphNode.text);
    bool didRemove = editor.deleteNode(paragraphNode);
    if (!didRemove) {
      print('ERROR: Failed to delete the currently selected node from the document.');
    }
  }
}

/// Splits the `ParagraphNode` affiliated with the given `nodeId` at the
/// given `splitPosition`, placing all text after `splitPosition` in a
/// new `ParagraphNode` with the given `newNodeId`, inserted after the
/// original node.
class SplitParagraphCommand implements EditorCommand {
  SplitParagraphCommand({
    @required this.nodeId,
    @required this.splitPosition,
    @required this.newNodeId,
  })  : assert(nodeId != null),
        assert(splitPosition != null),
        assert(newNodeId != null);

  final String nodeId;
  final TextPosition splitPosition;
  final String newNodeId;

  void execute(Document document, DocumentEditor editor) {
    print('Executing SplitParagraphCommand');

    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      print('WARNING: Cannot split paragraph for node of type: $node.');
      return;
    }
    final paragraphNode = node as ParagraphNode;

    final text = paragraphNode.text;
    final startText = text.copyText(0, splitPosition.offset);
    final endText = text.copyText(splitPosition.offset);
    print('Splitting paragraph:');
    print(' - start text: "${startText.text}"');
    print(' - end text: "${endText.text}"');

    // Change the current nodes content to just the text before the caret.
    print(' - changing the original paragraph text due to split');
    paragraphNode.text = startText;

    // Create a new node that will follow the current node. Set its text
    // to the text that was removed from the current node.
    final newNode = ParagraphNode(
      id: newNodeId,
      text: endText,
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

ExecutionInstruction insertCharacterInParagraph({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  final node = editContext.editor.document.getNodeById(editContext.composer.selection.extent.nodeId);
  if (node is ParagraphNode && isCharacterKey(keyEvent.logicalKey) && editContext.composer.selection.isCollapsed) {
    print(' - this is a paragraph');
    // Delegate the action to the standard insert-character behavior.
    insertCharacterInTextComposable(
      editContext: editContext,
      keyEvent: keyEvent,
    );

    if (keyEvent.character == ' ') {
      _convertParagraphIfDesired(
        document: editContext.editor.document,
        composer: editContext.composer,
        node: node,
        editor: editContext.editor,
      );
    }

    return ExecutionInstruction.haltExecution;
  } else {
    return ExecutionInstruction.continueExecution;
  }
}

// TODO: refactor to make prefix matching extensible
bool _convertParagraphIfDesired({
  @required Document document,
  @required DocumentComposer composer,
  @required ParagraphNode node,
  @required DocumentEditor editor,
}) {
  final text = node.text;
  final textSelection = composer.selection.extent.nodePosition as TextPosition;
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
        ? ListItemNode.unordered(id: node.id, text: adjustedText)
        : ListItemNode.ordered(id: node.id, text: adjustedText);
    final nodeIndex = document.getNodeIndex(node);
    editor
      ..deleteNodeAt(nodeIndex)
      ..insertNodeAt(nodeIndex, newNode);

    // We removed some text at the beginning of the list item.
    // Move the selection back by that same amount.
    final textPosition = composer.selection.extent.nodePosition as TextPosition;
    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: node.id,
        nodePosition: TextPosition(offset: textPosition.offset - startOfNewText),
      ),
    );

    return true;
  }

  final hrMatch = RegExp(r'^---*\s$');
  final hasHrMatch = hrMatch.hasMatch(textBeforeCaret);
  if (hasHrMatch) {
    print('Paragraph has an HR match');
    // Insert an HR before this paragraph and then clear the
    // paragraph's content.
    final paragraphNodeIndex = document.getNodeIndex(node);

    editor.insertNodeAt(
      paragraphNodeIndex,
      HorizontalRuleNode(
        id: DocumentEditor.createNodeId(),
      ),
    );

    node.text = AttributedText();

    composer.selection = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: node.id,
        nodePosition: TextPosition(offset: 0),
      ),
    );

    return true;
  }

  // URL match, e.g., images, social, etc.
  print('Looking for URL match...');
  final extractedLinks = linkify(node.text.text,
      options: LinkifyOptions(
        humanize: false,
      ));
  final int linkCount = extractedLinks.fold(0, (value, element) => element is UrlElement ? value + 1 : value);
  final String nonEmptyText =
      extractedLinks.fold('', (value, element) => element is TextElement ? value + element.text.trim() : value);
  if (linkCount == 1 && nonEmptyText.isEmpty) {
    // This node's text is just a URL, try to interpret it
    // as a known type.
    final link = extractedLinks.firstWhere((element) => element is UrlElement, orElse: () => null)?.text;
    _processUrlNode(
      document: document,
      editor: editor,
      nodeId: node.id,
      originalText: node.text.text,
      url: link,
    );
    return true;
  }

  return false;
}

Future<void> _processUrlNode({
  @required Document document,
  @required DocumentEditor editor,
  @required String nodeId,
  @required String originalText,
  @required String url,
}) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    print('Failed to load URL: ${response.statusCode} - ${response.reasonPhrase}');
    return;
  }

  print('Headers:');
  for (final entry in response.headers.entries) {
    print('${entry.key}: ${entry.value}');
  }

  final contentType = response.headers['content-type'];
  if (contentType == null) {
    print('Failed to determine URL content type.');
    return;
  }
  if (!contentType.startsWith('image/')) {
    print('URL is not an image. Ignoring');
    return;
  }

  // The URL is an image. Convert the node.
  print('The URL is an image. Converting the ParagraphNode to an ImageNode.');
  final node = document.getNodeById(nodeId);
  if (node is! ParagraphNode) {
    print('The node has become something other than a ParagraphNode ($node). Can\'t convert ndoe.');
    return;
  }
  final currentText = (node as ParagraphNode).text.text;
  if (currentText.trim() != originalText.trim()) {
    print('The node content changed in a non-trivial way. Aborting node conversion.');
    return;
  }

  final imageNode = ImageNode(
    id: node.id,
    imageUrl: url,
  );
  final nodeIndex = document.getNodeIndex(node);
  editor
    ..deleteNodeAt(nodeIndex)
    ..insertNodeAt(nodeIndex, imageNode);
}

class DeleteParagraphsCommand implements EditorCommand {
  DeleteParagraphsCommand({
    this.nodeId,
  }) : assert(nodeId != null);

  final String nodeId;

  void execute(Document document, DocumentEditor editor) {
    print('Executing DeleteParagraphsCommand');
    print(' - deleting "$nodeId"');
    final node = document.getNodeById(nodeId);
    if (node is! TextNode) {
      print('WARNING: Cannot delete node of type: $node.');
      return;
    }

    bool didRemove = editor.deleteNode(node);
    if (!didRemove) {
      print('ERROR: Failed to delete node "$node" from the document.');
    }
  }
}

ExecutionInstruction splitParagraphWhenEnterPressed({
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

  final newNodeId = DocumentEditor.createNodeId();

  editContext.editor.executeCommand(
    SplitParagraphCommand(
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

  _convertParagraphIfDesired(
    document: editContext.editor.document,
    editor: editContext.editor,
    composer: editContext.composer,
    node: node,
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction deleteEmptyParagraphWhenBackspaceIsPressed({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
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
  final paragraphNode = node as ParagraphNode;

  if (paragraphNode.text.text.isNotEmpty) {
    return ExecutionInstruction.continueExecution;
  }

  final nodeAbove = editContext.editor.document.getNodeBefore(paragraphNode);
  if (nodeAbove == null) {
    return ExecutionInstruction.continueExecution;
  }
  final newDocumentPosition = DocumentPosition(
    nodeId: nodeAbove.id,
    nodePosition: nodeAbove.endPosition,
  );

  editContext.editor.executeCommand(
    DeleteParagraphsCommand(nodeId: node.id),
  );

  editContext.composer.selection = DocumentSelection.collapsed(
    position: newDocumentPosition,
  );

  return ExecutionInstruction.haltExecution;
}

ExecutionInstruction moveParagraphSelectionUpWhenBackspaceIsPressed({
  @required EditContext editContext,
  @required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
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
  final paragraphNode = node as ParagraphNode;

  if (paragraphNode.text.text.isEmpty) {
    return ExecutionInstruction.continueExecution;
  }

  final nodeAbove = editContext.editor.document.getNodeBefore(paragraphNode);
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

Widget paragraphBuilder(ComponentContext componentContext) {
  if (componentContext.currentNode is! ParagraphNode) {
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
  final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;
  final highlightWhenEmpty =
      componentContext.nodeSelection == null ? false : componentContext.nodeSelection.highlightWhenEmpty;

  // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
  // if (hasCursor) {
  //   print('   - ^ has cursor');
  // }

  print(' - building a paragraph with selection:');
  print('   - base: ${textSelection?.base}');
  print('   - extent: ${textSelection?.extent}');

  TextAlign textAlign = TextAlign.left;
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

  print(
      'Building text component with caret color: ${(componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor}');

  return TextComponent(
    key: componentContext.componentKey,
    text: (componentContext.currentNode as TextNode).text,
    textStyleBuilder: componentContext.extensions[textStylesExtensionKey],
    metadata: (componentContext.currentNode as TextNode).metadata,
    textAlign: textAlign,
    textSelection: textSelection,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    hasCaret: hasCursor,
    caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
    highlightWhenEmpty: highlightWhenEmpty,
    showDebugPaint: componentContext.showDebugPaint,
  );
}
