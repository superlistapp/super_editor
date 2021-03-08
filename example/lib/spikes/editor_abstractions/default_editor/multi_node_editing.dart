import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/document.dart';
import '../core/document_editor.dart';
import '../core/document_selection.dart';
import '../core/attributed_text.dart';
import 'text.dart';
import 'box_component.dart';
import 'paragraph.dart';

class DeleteSelectionCommand implements EditorCommand {
  DeleteSelectionCommand({
    @required this.documentSelection,
  }) : assert(documentSelection != null);

  final DocumentSelection documentSelection;

  void execute(Document document, DocumentEditor editor) {
    print('DocumentEditor: deleting selection: $documentSelection');
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);

    if (nodes.length == 1) {
      // This is a selection within a single node.
      _deleteSelectionWithinSingleNode(
        document: document,
        documentSelection: documentSelection,
        editor: editor,
        node: nodes.first,
      );

      // Done handling single-node selection deletion.
      return;
    }

    final range = document.getRangeBetween(documentSelection.base, documentSelection.extent);

    final startNode = document.getNode(range.start);
    final startNodePosition = startNode.id == documentSelection.base.nodeId
        ? documentSelection.base.nodePosition
        : documentSelection.extent.nodePosition;

    final endNode = document.getNode(range.end);
    final endNodePosition = startNode.id == documentSelection.base.nodeId
        ? documentSelection.extent.nodePosition
        : documentSelection.base.nodePosition;

    _deleteNodesBetweenFirstAndLast(document, range, editor);

    print(' - deleting partial selection within the starting node.');
    _deleteSelectionWithinNodeFromPositionToEnd(
      document: document,
      node: startNode,
      nodePosition: startNodePosition,
      editor: editor,
    );

    print(' - deleting partial selection within ending node.');
    _deleteSelectionWithinNodeFromStartToPosition(
      document: document,
      node: endNode,
      nodePosition: endNodePosition,
      editor: editor,
    );

    // If the start node and end nodes are both `TextNode`s
    // then we need to consider merging them if one or both are
    // empty.
    if (startNode is! TextNode || endNode is! TextNode) {
      return;
    }

    print(' - combining last node text with first node text');
    (startNode as TextNode).text = (startNode as TextNode).text.copyAndAppend((endNode as TextNode).text);

    print(' - deleting last node');
    editor.deleteNode(endNode);

    print(' - done with selection deletion');
  }

  void _deleteSelectionWithinSingleNode({
    @required Document document,
    @required DocumentSelection documentSelection,
    @required DocumentEditor editor,
    @required DocumentNode node,
  }) {
    print(' - deleting selection withing single node');
    final basePosition = documentSelection.base.nodePosition;
    final extentPosition = documentSelection.extent.nodePosition;

    if (basePosition is BinaryPosition) {
      // Binary positions are all-or-nothing. Therefore, partial
      // selection means delete the whole node.
      editor.deleteNode(node);
    } else if (node is TextNode) {
      print(' - its a TextNode');
      final baseOffset = (basePosition as TextPosition).offset;
      final extentOffset = (extentPosition as TextPosition).offset;
      final startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
      final endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;
      print(' - deleting from $startOffset to $endOffset');

      node.text = node.text.removeRegion(
        startOffset: startOffset,
        endOffset: endOffset,
      );
    }
  }

  void _deleteNodesBetweenFirstAndLast(Document document, DocumentRange range, DocumentEditor editor) {
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
      editor.deleteNodeAt(i);
    }
  }

  void _deleteSelectionWithinNodeFromPositionToEnd({
    @required Document document,
    @required DocumentNode node,
    @required dynamic nodePosition,
    @required DocumentEditor editor,
  }) {
    if (nodePosition is BinaryPosition) {
      _deleteBinaryNode(
        document: document,
        node: node,
        editor: editor,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      node.text = node.text.removeRegion(
        startOffset: nodePosition.offset,
        endOffset: node.text.text.length,
      );
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  void _deleteSelectionWithinNodeFromStartToPosition({
    @required Document document,
    @required DocumentNode node,
    @required dynamic nodePosition,
    @required DocumentEditor editor,
  }) {
    if (nodePosition is BinaryPosition) {
      _deleteBinaryNode(
        document: document,
        node: node,
        editor: editor,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      node.text = node.text.removeRegion(
        startOffset: 0,
        endOffset: nodePosition.offset,
      );
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  void _deleteBinaryNode({
    @required Document document,
    @required DocumentNode node,
    @required DocumentEditor editor,
  }) {
    // TODO: for now deleting a binary node simply means replacing
    //       it with an empty ParagraphNode because after doing that,
    //       the general deletion logic that called this function will
    //       collapse empty paragraphs together, which gives the
    //       result we want.
    //
    //       We avoid deleting the node because the composer is
    //       depending on the first node still existing at the end of
    //       the deletion. This is a fragile relationship between the
    //       composer and the editor and needs to be addressed.
    print(' - replacing BinaryNode with a ParagraphNode: ${node.id}');
    final nodeIndex = document.getNodeIndex(node);
    editor.insertNodeAt(
      nodeIndex,
      ParagraphNode(
        id: node.id,
        text: AttributedText(),
      ),
    );
    editor.deleteNode(node);
  }
}
