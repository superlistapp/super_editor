import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'paragraph.dart';

final _log = Logger(scope: 'multi_node_editing.dart');

class DeleteSelectionCommand implements EditorCommand {
  DeleteSelectionCommand({
    required this.documentSelection,
  });

  final DocumentSelection documentSelection;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    _log.log('DeleteSelectionCommand', 'DocumentEditor: deleting selection: $documentSelection');
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);

    if (nodes.length == 1) {
      // This is a selection within a single node.
      _deleteSelectionWithinSingleNode(
        document: document,
        documentSelection: documentSelection,
        transaction: transaction,
        node: nodes.first,
      );

      // Done handling single-node selection deletion.
      return;
    }

    final range = document.getRangeBetween(documentSelection.base, documentSelection.extent);

    final startNode = document.getNode(range.start);
    final baseNode = document.getNode(documentSelection.base);
    if (startNode == null) {
      throw Exception('Could not locate start node for DeleteSelectionCommand: ${range.start}');
    }
    final startNodePosition = startNode.id == documentSelection.base.nodeId
        ? documentSelection.base.nodePosition
        : documentSelection.extent.nodePosition;
    final startNodeIndex = document.getNodeIndex(startNode);

    final endNode = document.getNode(range.end);
    if (endNode == null) {
      throw Exception('Could not locate end node for DeleteSelectionCommand: ${range.end}');
    }
    final endNodePosition = startNode.id == documentSelection.base.nodeId
        ? documentSelection.extent.nodePosition
        : documentSelection.base.nodePosition;
    final endNodeIndex = document.getNodeIndex(endNode);

    _deleteNodesBetweenFirstAndLast(
      document: document,
      startNode: startNode,
      endNode: endNode,
      transaction: transaction,
    );

    _log.log('DeleteSelectionCommand', ' - deleting partial selection within the starting node.');
    _deleteSelectionWithinNodeFromPositionToEnd(
      document: document,
      node: startNode,
      nodePosition: startNodePosition,
      transaction: transaction,
      replaceWithParagraph: false,
    );

    _log.log('DeleteSelectionCommand', ' - deleting partial selection within ending node.');
    _deleteSelectionWithinNodeFromStartToPosition(
      document: document,
      node: endNode,
      nodePosition: endNodePosition,
      transaction: transaction,
    );

    // If all selected nodes were deleted, e.g., the user selected from
    // the beginning of the first node to the end of the last node, then
    // we need insert an empty paragraph node so that there's a place
    // to position the caret.
    if (document.getNodeById(startNode.id) == null && document.getNodeById(endNode.id) == null) {
      final insertIndex = min(startNodeIndex, endNodeIndex);
      transaction.insertNodeAt(
        insertIndex,
        ParagraphNode(id: baseNode!.id, text: AttributedText()),
      );
      return;
    }

    // The start/end nodes may have been deleted due to empty content.
    // Refresh our references so that we can decide if we need to merge
    // the nodes.
    final startNodeAfterDeletion = document.getNodeById(startNode.id);
    final endNodeAfterDeletion = document.getNodeById(endNode.id);

    // If the start node and end nodes are both `TextNode`s
    // then we need to consider merging them if one or both are
    // empty.
    if (startNodeAfterDeletion is! TextNode || endNodeAfterDeletion is! TextNode) {
      return;
    }

    _log.log('DeleteSelectionCommand', ' - combining last node text with first node text');
    startNodeAfterDeletion.text = startNodeAfterDeletion.text.copyAndAppend(endNodeAfterDeletion.text);

    _log.log('DeleteSelectionCommand', ' - deleting last node');
    transaction.deleteNode(endNodeAfterDeletion);

    _log.log('DeleteSelectionCommand', ' - done with selection deletion');
  }

  void _deleteSelectionWithinSingleNode({
    required Document document,
    required DocumentSelection documentSelection,
    required DocumentEditorTransaction transaction,
    required DocumentNode node,
  }) {
    _log.log('_deleteSelectionWithinSingleNode', ' - deleting selection within single node');
    final basePosition = documentSelection.base.nodePosition;
    final extentPosition = documentSelection.extent.nodePosition;

    if (basePosition is UpstreamDownstreamNodePosition) {
      if (basePosition == extentPosition) {
        // The selection is collapsed. Nothing to delete.
        return;
      }

      // The selection is expanded within a block-level node. The only
      // possibility is that the entire node is selected. Delete the node
      // and replace it with an empty paragraph.
      transaction.replaceNode(
        oldNode: node,
        newNode: ParagraphNode(id: node.id, text: AttributedText()),
      );
    } else if (node is TextNode) {
      _log.log('_deleteSelectionWithinSingleNode', ' - its a TextNode');
      final baseOffset = (basePosition as TextPosition).offset;
      final extentOffset = (extentPosition as TextPosition).offset;
      final startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
      final endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;
      _log.log('_deleteSelectionWithinSingleNode', ' - deleting from $startOffset to $endOffset');

      node.text = node.text.removeRegion(
        startOffset: startOffset,
        endOffset: endOffset,
      );
    }
  }

  void _deleteNodesBetweenFirstAndLast({
    required Document document,
    required DocumentNode startNode,
    required DocumentNode endNode,
    required DocumentEditorTransaction transaction,
  }) {
    // Delete all nodes between the first node and the last node.
    final startIndex = document.getNodeIndex(startNode);
    final endIndex = document.getNodeIndex(endNode);

    _log.log('_deleteNodesBetweenFirstAndLast', ' - start node index: $startIndex');
    _log.log('_deleteNodesBetweenFirstAndLast', ' - end node index: $endIndex');
    _log.log('_deleteNodesBetweenFirstAndLast', ' - initially ${document.nodes.length} nodes');

    // Remove nodes from last to first so that indices don't get
    // screwed up during removal.
    for (int i = endIndex - 1; i > startIndex; --i) {
      _log.log('_deleteNodesBetweenFirstAndLast', ' - deleting node $i: ${document.getNodeAt(i)?.id}');
      transaction.deleteNodeAt(i);
    }
  }

  void _deleteSelectionWithinNodeFromPositionToEnd({
    required Document document,
    required DocumentNode node,
    required dynamic nodePosition,
    required DocumentEditorTransaction transaction,
    required bool replaceWithParagraph,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.downstream) {
        // The position is already at the end of the node. Nothing to do.
        return;
      }

      // The position is on the upstream side of block-level content.
      // Delete the whole block.
      _deleteBlockLevelNode(
        document: document,
        node: node,
        transaction: transaction,
        replaceWithParagraph: replaceWithParagraph,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.beginningPosition) {
        // All text is selected. Delete the node.
        transaction.deleteNode(node);
      } else {
        // Delete part of the text.
        node.text = node.text.removeRegion(
          startOffset: nodePosition.offset,
          endOffset: node.text.text.length,
        );
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  void _deleteSelectionWithinNodeFromStartToPosition({
    required Document document,
    required DocumentNode node,
    required dynamic nodePosition,
    required DocumentEditorTransaction transaction,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.upstream) {
        // The position is already at the beginning of the node. Nothing to do.
        return;
      }

      // The position is on the downstream side of block-level content.
      // Delete the whole block.
      _deleteBlockLevelNode(
        document: document,
        node: node,
        transaction: transaction,
        replaceWithParagraph: false,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.endPosition) {
        // All text is selected. Delete the node.
        transaction.deleteNode(node);
      } else {
        // Delete part of the text.
        node.text = node.text.removeRegion(
          startOffset: 0,
          endOffset: nodePosition.offset,
        );
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  void _deleteBlockLevelNode({
    required Document document,
    required DocumentNode node,
    required DocumentEditorTransaction transaction,
    required bool replaceWithParagraph,
  }) {
    if (replaceWithParagraph) {
      // TODO: for now deleting a block-level node simply means replacing
      //       it with an empty ParagraphNode because after doing that,
      //       the general deletion logic that called this function will
      //       collapse empty paragraphs together, which gives the
      //       result we want.
      //
      //       We avoid deleting the node because the composer is
      //       depending on the first node still existing at the end of
      //       the deletion. This is a fragile relationship between the
      //       composer and the editor and needs to be addressed.
      _log.log('_deleteBlockNode', ' - replacing block-level node with a ParagraphNode: ${node.id}');

      final newNode = ParagraphNode(id: node.id, text: AttributedText());
      transaction.replaceNode(oldNode: node, newNode: newNode);
    } else {
      _log.log('_deleteBlockNode', ' - deleting block level node');
      transaction.deleteNode(node);
    }
  }
}

class DeleteNodeCommand implements EditorCommand {
  DeleteNodeCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    _log.log('DeleteNodeCommand', 'DocumentEditor: deleting node: $nodeId');

    final node = document.getNodeById(nodeId);
    if (node == null) {
      _log.log('DeleteNodeCommand', 'No such node. Returning.');
      return;
    }

    _log.log('DeleteNodeCommand', ' - deleting node');
    transaction.deleteNode(node);

    _log.log('DeleteNodeCommand', ' - done with node deletion');
  }
}
