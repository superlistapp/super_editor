import 'dart:math';

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import 'paragraph.dart';

final _log = Logger(scope: 'multi_node_editing.dart');

class InsertNodeAtIndexRequest implements EditRequest {
  InsertNodeAtIndexRequest({
    required this.nodeIndex,
    required this.newNode,
  });

  final int nodeIndex;
  final DocumentNode newNode;
}

class InsertNodeAtIndexCommand extends EditCommand {
  InsertNodeAtIndexCommand({
    required this.nodeIndex,
    required this.newNode,
  });

  final int nodeIndex;
  final DocumentNode newNode;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    document.insertNodeAt(nodeIndex, newNode);
    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(newNode.id),
      )
    ]);
  }
}

class InsertNodeBeforeNodeRequest implements EditRequest {
  const InsertNodeBeforeNodeRequest({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;
}

class InsertNodeBeforeNodeCommand extends EditCommand {
  InsertNodeBeforeNodeCommand({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final existingNode = document.getNodeById(existingNodeId)!;
    document.insertNodeBefore(existingNode: existingNode, newNode: newNode);
    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(newNode.id),
      )
    ]);
  }
}

class InsertNodeAfterNodeRequest implements EditRequest {
  const InsertNodeAfterNodeRequest({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;
}

class InsertNodeAfterNodeCommand extends EditCommand {
  InsertNodeAfterNodeCommand({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final existingNode = document.getNodeById(existingNodeId)!;
    document.insertNodeAfter(existingNode: existingNode, newNode: newNode);
    executor.logChanges([
      DocumentEdit(
        NodeInsertedEvent(newNode.id),
      )
    ]);
  }
}

class InsertNodeAtCaretRequest implements EditRequest {
  InsertNodeAtCaretRequest({
    required this.node,
  });

  final DocumentNode node;
}

class InsertNodeAtCaretCommand extends EditCommand {
  InsertNodeAtCaretCommand({
    required this.newNode,
  });

  final DocumentNode newNode;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final composer = context.find<DocumentComposer>(Editor.composerKey);

    if (composer.selectionComponent.selection == null) {
      return;
    }
    if (composer.selectionComponent.selection!.base.nodeId != composer.selectionComponent.selection!.extent.nodeId) {
      return;
    }

    final nodeId = composer.selectionComponent.selection!.base.nodeId;
    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) {
      return;
    }

    final paragraphPosition = composer.selectionComponent.selection!.extent.nodePosition as TextNodePosition;
    final endOfParagraph = node.endPosition;

    DocumentSelection newSelection;
    if (node.text.text.isEmpty) {
      // Convert empty paragraph to block item.
      document.replaceNode(oldNode: node, newNode: newNode);
      executor.logChanges([
        DocumentEdit(
          NodeRemovedEvent(node.id),
        ),
        DocumentEdit(
          NodeInsertedEvent(newNode.id),
        ),
      ]);

      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: newNode.endPosition,
        ),
      );
    } else if (paragraphPosition == endOfParagraph) {
      // Insert block item after the paragraph.
      document.insertNodeAfter(existingNode: node, newNode: newNode);
      executor.logChanges([
        DocumentEdit(
          NodeInsertedEvent(node.id),
        )
      ]);

      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: newNode.endPosition,
        ),
      );
    } else {
      // Split the paragraph and inset image in between.
      final textBefore = node.text.copyText(0, paragraphPosition.offset);
      final textAfter = node.text.copyText(paragraphPosition.offset);

      final newParagraph = ParagraphNode(id: Editor.createNodeId(), text: textAfter);

      node.text = textBefore;
      document
        ..insertNodeAfter(existingNode: node, newNode: newNode)
        ..insertNodeAfter(existingNode: newNode, newNode: newParagraph);
      executor.logChanges([
        DocumentEdit(
          NodeChangeEvent(nodeId),
        ),
        DocumentEdit(
          NodeInsertedEvent(newNode.id),
        ),
        DocumentEdit(
          NodeInsertedEvent(newParagraph.id),
        ),
      ]);

      newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: newParagraph.beginningPosition,
        ),
      );
    }

    executor.executeCommand(ChangeSelectionCommand(
      newSelection,
      SelectionChangeType.insertContent,
      SelectionReason.userInteraction,
    ));
  }
}

class MoveNodeRequest implements EditRequest {
  const MoveNodeRequest({
    required this.nodeId,
    required this.newIndex,
  });

  final String nodeId;
  final int newIndex;
}

class MoveNodeCommand extends EditCommand {
  MoveNodeCommand({
    required this.nodeId,
    required this.newIndex,
  });

  final String nodeId;
  final int newIndex;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);

    // Log all the move changes that will happen when we move the target node
    // elsewhere in the document.
    final nodeMoveEvents = <DocumentEdit>[];
    final targetNodeIndex = document.getNodeIndexById(nodeId);
    final startIndex = min(targetNodeIndex, newIndex);
    final endIndex = max(targetNodeIndex, newIndex);
    for (int i = startIndex; i <= endIndex; i += 1) {
      if (i == targetNodeIndex) {
        // This is the node that we care about moving.
        nodeMoveEvents.add(
          DocumentEdit(
            NodeMovedEvent(nodeId: nodeId, from: targetNodeIndex, to: newIndex),
          ),
        );
        continue;
      }

      // This is a node that got moved up by one as a consequence of moving
      // the target node.
      nodeMoveEvents.add(
        DocumentEdit(
          NodeMovedEvent(nodeId: document.getNodeAt(i)!.id, from: i, to: i - 1),
        ),
      );
    }

    // Move the target node to its destination index.
    document.moveNode(nodeId: nodeId, targetIndex: newIndex);

    // Report all the node movements.
    executor.logChanges(nodeMoveEvents);
  }
}

class ReplaceNodeRequest implements EditRequest {
  ReplaceNodeRequest({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;
}

class ReplaceNodeCommand extends EditCommand {
  ReplaceNodeCommand({
    required this.existingNodeId,
    required this.newNode,
  });

  final String existingNodeId;
  final DocumentNode newNode;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);
    final oldNode = document.getNodeById(existingNodeId)!;
    document.replaceNode(oldNode: oldNode, newNode: newNode);

    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(existingNodeId),
      ),
      DocumentEdit(
        NodeInsertedEvent(newNode.id),
      ),
    ]);
  }
}

class ReplaceNodeWithEmptyParagraphWithCaretRequest implements EditRequest {
  const ReplaceNodeWithEmptyParagraphWithCaretRequest({
    required this.nodeId,
  });

  final String nodeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplaceNodeWithEmptyParagraphWithCaretRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

class ReplaceNodeWithEmptyParagraphWithCaretCommand implements EditCommand {
  ReplaceNodeWithEmptyParagraphWithCaretCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<MutableDocument>(Editor.documentKey);

    final oldNode = document.getNodeById(nodeId);
    if (oldNode == null) {
      return;
    }

    final newNode = ParagraphNode(
      id: oldNode.id,
      text: AttributedText(),
    );
    document.replaceNode(oldNode: oldNode, newNode: newNode);

    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(oldNode.id),
      ),
      DocumentEdit(
        NodeInsertedEvent(newNode.id),
      ),
    ]);

    executor.executeCommand(ChangeSelectionCommand(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: newNode.id,
          nodePosition: newNode.beginningPosition,
        ),
      ),
      SelectionChangeType.place,
      SelectionReason.userInteraction,
      notifyListeners: false,
    ));
  }
}

class DeleteSelectionRequest implements EditRequest {
  DeleteSelectionRequest({
    required this.documentSelection,
  });

  final DocumentSelection documentSelection;
}

class DeleteSelectionCommand implements EditCommand {
  DeleteSelectionCommand({
    required this.documentSelection,
  });

  final DocumentSelection documentSelection;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    _log.log('DeleteSelectionCommand', 'DocumentEditor: deleting selection: $documentSelection');
    final document = context.find<MutableDocument>(Editor.documentKey);
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);

    if (nodes.length == 1) {
      // This is a selection within a single node.
      final changeList = _deleteSelectionWithinSingleNode(
        document: document,
        documentSelection: documentSelection,
        node: nodes.first,
      );

      executor.logChanges(changeList);
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
    final startNodeIndex = document.getNodeIndexById(startNode.id);

    final endNode = document.getNode(range.end);
    if (endNode == null) {
      throw Exception('Could not locate end node for DeleteSelectionCommand: ${range.end}');
    }
    final endNodePosition = startNode.id == documentSelection.base.nodeId
        ? documentSelection.extent.nodePosition
        : documentSelection.base.nodePosition;
    final endNodeIndex = document.getNodeIndexById(endNode.id);

    executor.logChanges(
      _deleteNodesBetweenFirstAndLast(
        document: document,
        startNode: startNode,
        endNode: endNode,
      ),
    );

    _log.log('DeleteSelectionCommand', ' - deleting partial selection within the starting node.');
    executor.logChanges(
      _deleteSelectionWithinNodeFromPositionToEnd(
        document: document,
        node: startNode,
        nodePosition: startNodePosition,
        replaceWithParagraph: false,
      ),
    );

    _log.log('DeleteSelectionCommand', ' - deleting partial selection within ending node.');
    executor.logChanges(
      _deleteSelectionWithinNodeFromStartToPosition(
        document: document,
        node: endNode,
        nodePosition: endNodePosition,
      ),
    );

    // If all selected nodes were deleted, e.g., the user selected from
    // the beginning of the first node to the end of the last node, then
    // we need insert an empty paragraph node so that there's a place
    // to position the caret.
    if (document.getNodeById(startNode.id) == null && document.getNodeById(endNode.id) == null) {
      final insertIndex = min(startNodeIndex, endNodeIndex);
      document.insertNodeAt(
        insertIndex,
        ParagraphNode(id: baseNode!.id, text: AttributedText()),
      );
      executor.logChanges([
        DocumentEdit(
          NodeChangeEvent(baseNode.id),
        )
      ]);
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
      // Neither of the end nodes are `TextNode`s, so there's nothing
      // for us to merge. We're done.
      return;
    }

    _log.log('DeleteSelectionCommand', ' - combining last node text with first node text');
    startNodeAfterDeletion.text = startNodeAfterDeletion.text.copyAndAppend(endNodeAfterDeletion.text);
    executor.logChanges([
      DocumentEdit(
        NodeChangeEvent(startNodeAfterDeletion.id),
      )
    ]);

    _log.log('DeleteSelectionCommand', ' - deleting last node');
    document.deleteNode(endNodeAfterDeletion);
    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(endNodeAfterDeletion.id),
      )
    ]);
    _log.log('DeleteSelectionCommand', ' - done with selection deletion');
  }

  List<EditEvent> _deleteSelectionWithinSingleNode({
    required MutableDocument document,
    required DocumentSelection documentSelection,
    required DocumentNode node,
  }) {
    _log.log('_deleteSelectionWithinSingleNode', ' - deleting selection within single node');
    final basePosition = documentSelection.base.nodePosition;
    final extentPosition = documentSelection.extent.nodePosition;

    if (basePosition is UpstreamDownstreamNodePosition) {
      if (basePosition == extentPosition) {
        // The selection is collapsed. Nothing to delete.
        return [];
      }

      // The selection is expanded within a block-level node. The only
      // possibility is that the entire node is selected. Delete the node
      // and replace it with an empty paragraph.
      document.replaceNode(
        oldNode: node,
        newNode: ParagraphNode(id: node.id, text: AttributedText()),
      );

      return [
        DocumentEdit(
          NodeChangeEvent(node.id),
        )
      ];
    } else if (node is TextNode) {
      _log.log('_deleteSelectionWithinSingleNode', ' - its a TextNode');
      final baseOffset = (basePosition as TextPosition).offset;
      final extentOffset = (extentPosition as TextPosition).offset;
      final startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
      final endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;
      _log.log('_deleteSelectionWithinSingleNode', ' - deleting from $startOffset to $endOffset');

      final deletedText = node.text.copyText(startOffset, endOffset);
      node.text = node.text.removeRegion(
        startOffset: startOffset,
        endOffset: endOffset,
      );

      return [
        DocumentEdit(
          TextDeletedEvent(
            node.id,
            deletedText: deletedText,
            offset: startOffset,
          ),
        ),
      ];
    }

    return [];
  }

  List<EditEvent> _deleteNodesBetweenFirstAndLast({
    required MutableDocument document,
    required DocumentNode startNode,
    required DocumentNode endNode,
  }) {
    // Delete all nodes between the first node and the last node.
    final startIndex = document.getNodeIndexById(startNode.id);
    final endIndex = document.getNodeIndexById(endNode.id);

    _log.log('_deleteNodesBetweenFirstAndLast', ' - start node index: $startIndex');
    _log.log('_deleteNodesBetweenFirstAndLast', ' - end node index: $endIndex');
    _log.log('_deleteNodesBetweenFirstAndLast', ' - initially ${document.nodes.length} nodes');

    // Remove nodes from last to first so that indices don't get
    // screwed up during removal.
    final changes = <EditEvent>[];
    for (int i = endIndex - 1; i > startIndex; --i) {
      _log.log('_deleteNodesBetweenFirstAndLast', ' - deleting node $i: ${document.getNodeAt(i)?.id}');
      changes.add(DocumentEdit(
        NodeRemovedEvent(document.getNodeAt(i)!.id),
      ));
      document.deleteNodeAt(i);
    }
    return changes;
  }

  List<EditEvent> _deleteSelectionWithinNodeFromPositionToEnd({
    required MutableDocument document,
    required DocumentNode node,
    required dynamic nodePosition,
    required bool replaceWithParagraph,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.downstream) {
        // The position is already at the end of the node. Nothing to do.
        return [];
      }

      // The position is on the upstream side of block-level content.
      // Delete the whole block.
      return _deleteBlockLevelNode(
        document: document,
        node: node,
        replaceWithParagraph: replaceWithParagraph,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.beginningPosition) {
        // All text is selected. Delete the node.
        document.deleteNode(node);

        return [
          DocumentEdit(
            NodeRemovedEvent(node.id),
          )
        ];
      } else {
        // Delete part of the text.
        node.text = node.text.removeRegion(
          startOffset: nodePosition.offset,
          endOffset: node.text.text.length,
        );

        return [
          DocumentEdit(
            NodeChangeEvent(node.id),
          )
        ];
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  List<EditEvent> _deleteSelectionWithinNodeFromStartToPosition({
    required MutableDocument document,
    required DocumentNode node,
    required dynamic nodePosition,
  }) {
    if (nodePosition is UpstreamDownstreamNodePosition) {
      if (nodePosition.affinity == TextAffinity.upstream) {
        // The position is already at the beginning of the node. Nothing to do.
        return [];
      }

      // The position is on the downstream side of block-level content.
      // Delete the whole block.
      return _deleteBlockLevelNode(
        document: document,
        node: node,
        replaceWithParagraph: false,
      );
    } else if (nodePosition is TextPosition && node is TextNode) {
      if (nodePosition == node.endPosition) {
        // All text is selected. Delete the node.
        document.deleteNode(node);

        return [
          DocumentEdit(
            NodeRemovedEvent(node.id),
          )
        ];
      } else {
        // Delete part of the text.
        node.text = node.text.removeRegion(
          startOffset: 0,
          endOffset: nodePosition.offset,
        );

        return [
          DocumentEdit(
            NodeChangeEvent(node.id),
          )
        ];
      }
    } else {
      throw Exception('Unknown node position type: $nodePosition, for node: $node');
    }
  }

  List<EditEvent> _deleteBlockLevelNode({
    required MutableDocument document,
    required DocumentNode node,
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
      document.replaceNode(oldNode: node, newNode: newNode);

      return [
        DocumentEdit(
          NodeRemovedEvent(node.id),
        ),
        DocumentEdit(
          NodeInsertedEvent(newNode.id),
        ),
      ];
    } else {
      _log.log('_deleteBlockNode', ' - deleting block level node');
      document.deleteNode(node);

      return [
        DocumentEdit(
          NodeRemovedEvent(node.id),
        )
      ];
    }
  }
}

class DeleteNodeRequest implements EditRequest {
  DeleteNodeRequest({
    required this.nodeId,
  });

  final String nodeId;
}

class DeleteNodeCommand implements EditCommand {
  DeleteNodeCommand({
    required this.nodeId,
  });

  final String nodeId;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    _log.log('DeleteNodeCommand', 'DocumentEditor: deleting node: $nodeId');

    final document = context.find<MutableDocument>(Editor.documentKey);
    final node = document.getNodeById(nodeId);
    if (node == null) {
      _log.log('DeleteNodeCommand', 'No such node. Returning.');
      return;
    }

    _log.log('DeleteNodeCommand', ' - deleting node');
    document.deleteNode(node);
    _log.log('DeleteNodeCommand', ' - done with node deletion');
    executor.logChanges([
      DocumentEdit(
        NodeRemovedEvent(node.id),
      )
    ]);
  }
}
