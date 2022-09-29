import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_layout.dart';

import 'document.dart';
import 'document_selection.dart';

/// Moves the [DocumentComposer]'s selection to the nearest node to [startingNode],
/// whose [DocumentComponent] is visually selectable.
///
/// Expands the selection if [expand] is `true`, otherwise collapses the selection.
///
/// If a downstream selectable node if found, it will be used, otherwise,
/// a upstream selectable node will be searched.
///
/// If a selectable node is found, the selection will move to its beginning.
/// If no selectable node is found, the selection will remain unchanged.
///
/// Returns `true` if the selection is moved and `false` otherwise, e.g., there
/// are no selectable nodes in the document.
bool moveSelectionToNearestSelectableNode({
  required Document document,
  required DocumentLayoutResolver documentLayoutResolver,
  required ValueNotifier<DocumentSelection?> selection,
  required DocumentNode startingNode,
  bool expand = false,
}) {
  String? newNodeId;
  NodePosition? newPosition;

  // Try to find a new selection downstream.
  final downstreamNode = _getDownstreamSelectableNodeAfter(document, documentLayoutResolver, startingNode);
  if (downstreamNode != null) {
    newNodeId = downstreamNode.id;
    final nextComponent = documentLayoutResolver().getComponentByNodeId(newNodeId);
    newPosition = nextComponent?.getBeginningPosition();
  }

  // Try to find a new selection upstream.
  if (newPosition == null) {
    final upstreamNode = _getUpstreamSelectableNodeBefore(document, documentLayoutResolver, startingNode);
    if (upstreamNode != null) {
      newNodeId = upstreamNode.id;
      final previousComponent = documentLayoutResolver().getComponentByNodeId(newNodeId);
      newPosition = previousComponent?.getBeginningPosition();
    }
  }

  if (newNodeId == null || newPosition == null) {
    return false;
  }

  final newExtent = DocumentPosition(
    nodeId: newNodeId,
    nodePosition: newPosition,
  );

  if (expand) {
    // Selection should be expanded.
    selection.value = selection.value!.expandTo(newExtent);
  } else {
    // Selection should be replaced by new collapsed position.
    selection.value = DocumentSelection.collapsed(position: newExtent);
  }

  return true;
}

/// Returns the first [DocumentNode] after [startingNode] whose
/// [DocumentComponent] is visually selectable.
DocumentNode? _getDownstreamSelectableNodeAfter(
  Document document,
  DocumentLayoutResolver documentLayoutResolver,
  DocumentNode startingNode,
) {
  bool foundSelectableNode = false;
  DocumentNode prevNode = startingNode;
  DocumentNode? selectableNode;
  do {
    selectableNode = document.getNodeAfter(prevNode);

    if (selectableNode != null) {
      final nextComponent = documentLayoutResolver().getComponentByNodeId(selectableNode.id);
      if (nextComponent != null) {
        foundSelectableNode = nextComponent.isVisualSelectionSupported();
      }
      prevNode = selectableNode;
    }
  } while (!foundSelectableNode && selectableNode != null);

  return selectableNode;
}

/// Returns the first [DocumentNode] before [startingNode] whose
/// [DocumentComponent] is visually selectable.
DocumentNode? _getUpstreamSelectableNodeBefore(
  Document document,
  DocumentLayoutResolver documentLayoutResolver,
  DocumentNode startingNode,
) {
  bool foundSelectableNode = false;
  DocumentNode prevNode = startingNode;
  DocumentNode? selectableNode;
  do {
    selectableNode = document.getNodeBefore(prevNode);

    if (selectableNode != null) {
      final nextComponent = documentLayoutResolver().getComponentByNodeId(selectableNode.id);
      if (nextComponent != null) {
        foundSelectableNode = nextComponent.isVisualSelectionSupported();
      }
      prevNode = selectableNode;
    }
  } while (!foundSelectableNode && selectableNode != null);

  return selectableNode;
}
