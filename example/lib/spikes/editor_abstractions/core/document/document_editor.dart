import 'dart:math';

import 'package:example/spikes/editor_abstractions/default_editor/box_component.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rich_text_document.dart';
import '../selection/editor_selection.dart';
import '../layout/document_layout.dart';

// TODO: get rid of these imports
import '../../default_editor/text.dart';
import '../../default_editor/paragraph.dart';
import '../../default_editor/list_items.dart';

class DocumentEditor {
  DocumentSelection addCharacter({
    @required RichTextDocument document,
    @required DocumentPosition position,
    @required String character,
    List<String> styles = const [],
  }) {
    final docNode = document.getNodeById(position.nodeId);
    if (docNode is! TextNode) {
      return DocumentSelection.collapsed(position: position);
    }

    final textNode = docNode as TextNode;
    final textOffset = (position.nodePosition as TextPosition).offset;
    final newTextNode = textNode.text.insertString(
      textToInsert: character,
      startOffset: textOffset,
      applyAttributions: styles,
    );

    // Add the character to the paragraph.
    textNode.text = newTextNode;

    // Update the selection to place the caret after the new character.
    return DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: textNode.id,
        nodePosition: TextPosition(
          offset: textOffset + 1,
        ),
      ),
    );
  }

  bool tryToCombineNodes({
    @required RichTextDocument document,
    @required DocumentNode destination,
    @required DocumentNode toMerge,
  }) {
    if (destination is ParagraphNode || destination is ListItemNode) {
      if (toMerge is ParagraphNode || toMerge is ListItemNode) {
        final destinationTextNode = destination as TextNode;
        final toMergeTextNode = toMerge as TextNode;
        destinationTextNode.text = destinationTextNode.text.copyAndAppend(toMergeTextNode.text);
        return true;
      }
    }
    return false;
  }

  DocumentSelection deleteSelection({
    @required RichTextDocument document,
    @required DocumentLayoutState documentLayout,
    @required DocumentSelection selection,
  }) {
    print('DocumentEditor: deleting selection: $selection');
    final nodeSelections = selection.computeNodeSelections(
      document: document,
      documentLayout: documentLayout,
    );

    if (nodeSelections.length == 1) {
      // This is a selection within a single node.
      final nodeSelection = nodeSelections.first;

      if (nodeSelection.nodeSelection is BinarySelection) {
        final node = document.getNodeById(nodeSelection.nodeId);
        final deletedNodeIndex = document.getNodeIndex(node);
        document.deleteNode(node);

        final newSelectionPosition = _getAnotherSelectionAfterNodeDeletion(
          document: document,
          documentLayout: documentLayout,
          deletedNodeIndex: deletedNodeIndex,
        );
        return newSelectionPosition != null ? DocumentSelection.collapsed(position: newSelectionPosition) : null;
      } else if (nodeSelection.nodeSelection is TextSelection) {
        final textSelection = nodeSelection.nodeSelection as TextSelection;
        final textNode = document.getNodeById(nodeSelection.nodeId) as TextNode;
        textNode.text = textNode.text.removeRegion(
          startOffset: textSelection.start,
          endOffset: textSelection.end,
        );

        print('Done deleting selection. Returning new document selection.');
        return DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: textNode.id,
            nodePosition: TextPosition(offset: textSelection.start),
          ),
        );
      }
    }

    final range = document.getRangeBetween(selection.base, selection.extent);

    // Delete all nodes between the first node and the last node.
    final startPosition = range.start;
    final startNode = document.getNodeById(startPosition.nodeId);
    final startIndex = document.getNodeIndex(startNode);

    final endPosition = range.end;
    final endNode = document.getNodeById(endPosition.nodeId);
    final endIndex = document.getNodeIndex(endNode);

    print(' - start node index: $startIndex');
    print(' - start position: $startPosition');
    print(' - end node index: $endIndex');
    print(' - end position: $endPosition');
    print(' - initially ${document.nodes.length} nodes');

    // Remove nodes from last to first so that indices don't get
    // screwed up during removal.
    for (int i = endIndex - 1; i > startIndex; --i) {
      print(' - deleting node $i: ${document.getNodeAt(i).id}');
      document.deleteNodeAt(i);
    }

    print(' - deleting partial selection within the starting node.');
    final newStartPosition = _deleteSelectionWithinNodeAt(
      document: document,
      docNode: startNode,
      nodeSelection: nodeSelections.first.nodeSelection,
    );

    print(' - deleting partial selection within ending node.');
    final newEndPosition = _deleteSelectionWithinNodeAt(
      document: document,
      docNode: endNode,
      nodeSelection: nodeSelections.last.nodeSelection,
    );

    final doesFirstNodeStillExist = document.getNodeById(startNode.id) != null;
    final doesSecondNodeStillExist = document.getNodeById(endNode.id) != null;

    final shouldTryToCombineNodes = doesFirstNodeStillExist && doesSecondNodeStillExist;

    DocumentPosition newPosition;
    if (shouldTryToCombineNodes) {
      print(' - trying to combine nodes');
      final didCombine = tryToCombineNodes(
        document: document,
        destination: startNode,
        toMerge: endNode,
      );
      if (didCombine) {
        print(' - nodes were successfully combined');
        print(' - deleting end node $endIndex');
        final didRemoveLast = document.deleteNode(endNode);
        print(' - did remove ending node? $didRemoveLast');
        print(' - finally ${document.nodes.length} nodes');
      }
      newPosition = startPosition;
    } else if (doesFirstNodeStillExist) {
      // First node still has some content and still exists.
      // Place the new selection position there.
      newPosition = newStartPosition;
    } else if (doesSecondNodeStillExist) {
      // The first node was deleted, but the second node
      // still has some content. Place the new selection
      // position there.
      newPosition = newEndPosition;
    } else {
      // Both the start and end nodes were deleted. Get
      // a new node position for the selection.
      newPosition = _getAnotherSelectionAfterNodeDeletion(
        document: document,
        documentLayout: documentLayout,
        deletedNodeIndex: startIndex,
      );
    }

    final newSelection = newPosition != null
        ? DocumentSelection.collapsed(
            position: newPosition,
          )
        : null;
    print(' - returning new selection: $newSelection');

    return newSelection;
  }

  DocumentPosition _deleteSelectionWithinNodeAt({
    @required RichTextDocument document,
    @required DocumentNode docNode,
    @required dynamic nodeSelection,
  }) {
    if (nodeSelection is BinarySelection) {
      if (nodeSelection.position.isIncluded) {
        // This is something like an image or horizontal rule.
        // Delete the node.
        document.deleteNode(docNode);
        return null;
      }
    } else if (docNode is TextNode) {
      return _deleteSelectionWithinTextNodeAt(
        document: document,
        docNode: docNode,
        nodeSelection: nodeSelection,
      );
    }

    print('WARNING: Cannot delete partial content in node of type: $docNode');
    return null;
  }

  DocumentPosition _deleteSelectionWithinTextNodeAt({
    @required RichTextDocument document,
    @required TextNode docNode,
    @required dynamic nodeSelection,
  }) {
    final index = document.getNodeIndex(docNode);
    assert(index >= 0 && index < document.nodes.length);

    print('Deleting selection within node $index');
    final paragraphNode = docNode;
    if (nodeSelection is TextSelection) {
      print(' - deleting TextSelection within ParagraphNode');
      final from = min(nodeSelection.baseOffset, nodeSelection.extentOffset);
      final to = max(nodeSelection.baseOffset, nodeSelection.extentOffset);
      print(' - from: $from, to: $to, text: ${paragraphNode.text.text}');

      paragraphNode.text = paragraphNode.text.removeRegion(
        startOffset: from,
        endOffset: to,
      );
      print(' - remaining text: ${paragraphNode.text.text}');

      return DocumentPosition(
        nodeId: docNode.id,
        nodePosition: TextPosition(offset: from),
      );
    } else {
      print('ParagraphNode cannot delete unknown selection type: $nodeSelection');
      return null;
    }
  }

  DocumentPosition _getAnotherSelectionAfterNodeDeletion({
    @required RichTextDocument document,
    @required DocumentLayoutState documentLayout,
    @required int deletedNodeIndex,
  }) {
    if (deletedNodeIndex > 0) {
      final newSelectionNodeIndex = deletedNodeIndex - 1;
      final newSelectionNode = document.getNodeAt(newSelectionNodeIndex);
      final component = documentLayout.getComponentByNodeId(newSelectionNode.id);
      return DocumentPosition(
        nodeId: newSelectionNode.id,
        nodePosition: component.getEndPosition(),
      );
    } else if (document.nodes.isNotEmpty) {
      // There is no node above the start node. It's at the top
      // of the document. Try to place the selection in whatever
      // is now the first node in the document.
      final newSelectionNode = document.getNodeAt(0);
      final component = documentLayout.getComponentByNodeId(newSelectionNode.id);
      return DocumentPosition(
        nodeId: newSelectionNode.id,
        nodePosition: component.getEndPosition(),
      );
    } else {
      // The document is empty. Null out the position.
      return null;
    }
  }
}
