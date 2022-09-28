import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Logical operations for interacting with a read-only document.
// TODO: de-dup with analogous SuperEditor operations

/// Calculates an appropriate [DocumentSelection] from an (x,y)
/// [baseOffsetInDocument], to an (x,y) [extentOffsetInDocument], setting
/// the new document selection in the given [selection].
void selectRegion({
  required DocumentLayout documentLayout,
  required Offset baseOffsetInDocument,
  required Offset extentOffsetInDocument,
  required SelectionType selectionType,
  bool expandSelection = false,
  required ValueNotifier<DocumentSelection?> selection,
}) {
  readerGesturesLog.info("Selecting region with selection mode: $selectionType");
  DocumentSelection? regionSelection = documentLayout.getDocumentSelectionInRegion(
    baseOffsetInDocument,
    extentOffsetInDocument,
  );
  DocumentPosition? basePosition = regionSelection?.base;
  DocumentPosition? extentPosition = regionSelection?.extent;
  readerGesturesLog.fine(" - base: $basePosition, extent: $extentPosition");

  if (basePosition == null || extentPosition == null) {
    selection.value = null;
    return;
  }

  if (selectionType == SelectionType.paragraph) {
    final baseParagraphSelection = getParagraphSelection(
      docPosition: basePosition,
      docLayout: documentLayout,
    );
    if (baseParagraphSelection == null) {
      selection.value = null;
      return;
    }
    basePosition = baseOffsetInDocument.dy < extentOffsetInDocument.dy
        ? baseParagraphSelection.base
        : baseParagraphSelection.extent;

    final extentParagraphSelection = getParagraphSelection(
      docPosition: extentPosition,
      docLayout: documentLayout,
    );
    if (extentParagraphSelection == null) {
      selection.value = null;
      return;
    }
    extentPosition = baseOffsetInDocument.dy < extentOffsetInDocument.dy
        ? extentParagraphSelection.extent
        : extentParagraphSelection.base;
  } else if (selectionType == SelectionType.word) {
    final baseWordSelection = getWordSelection(
      docPosition: basePosition,
      docLayout: documentLayout,
    );
    if (baseWordSelection == null) {
      selection.value = null;
      return;
    }
    basePosition = baseWordSelection.base;

    final extentWordSelection = getWordSelection(
      docPosition: extentPosition,
      docLayout: documentLayout,
    );
    if (extentWordSelection == null) {
      selection.value = null;
      return;
    }
    extentPosition = extentWordSelection.extent;
  }

  selection.value = (DocumentSelection(
    // If desired, expand the selection instead of replacing it.
    base: expandSelection ? selection.value?.base ?? basePosition : basePosition,
    extent: extentPosition,
  ));
  readerGesturesLog.fine("Selected region: ${selection.value}");
}

enum SelectionType {
  position,
  word,
  paragraph,
}

bool selectWordAt({
  required DocumentPosition docPosition,
  required DocumentLayout docLayout,
  required ValueNotifier<DocumentSelection?> selection,
}) {
  final newSelection = getWordSelection(docPosition: docPosition, docLayout: docLayout);
  if (newSelection != null) {
    selection.value = newSelection;
    return true;
  } else {
    return false;
  }
}

bool selectBlockAt(DocumentPosition position, ValueNotifier<DocumentSelection?> selection) {
  if (position.nodePosition is! UpstreamDownstreamNodePosition) {
    return false;
  }

  selection.value = DocumentSelection(
    base: DocumentPosition(
      nodeId: position.nodeId,
      nodePosition: const UpstreamDownstreamNodePosition.upstream(),
    ),
    extent: DocumentPosition(
      nodeId: position.nodeId,
      nodePosition: const UpstreamDownstreamNodePosition.downstream(),
    ),
  );

  return true;
}

bool selectParagraphAt({
  required DocumentPosition docPosition,
  required DocumentLayout docLayout,
  required ValueNotifier<DocumentSelection?> selection,
}) {
  final newSelection = getParagraphSelection(docPosition: docPosition, docLayout: docLayout);
  if (newSelection != null) {
    selection.value = newSelection;
    return true;
  } else {
    return false;
  }
}

void moveToNearestSelectableComponent(
  Document document,
  DocumentLayout documentLayout,
  ValueNotifier<DocumentSelection?> selection,
  String nodeId,
  DocumentComponent component,
) {
  // TODO: this was taken from CommonOps. We don't have CommonOps in this
  // interactor, because it's for read-only documents. Selection operations
  // should probably be moved to something outside of CommonOps
  DocumentNode startingNode = document.getNodeById(nodeId)!;
  String? newNodeId;
  NodePosition? newPosition;

  // Try to find a new selection downstream.
  final downstreamNode = _getDownstreamSelectableNodeAfter(document, documentLayout, startingNode);
  if (downstreamNode != null) {
    newNodeId = downstreamNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(newNodeId);
    newPosition = nextComponent?.getBeginningPosition();
  }

  // Try to find a new selection upstream.
  if (newPosition == null) {
    final upstreamNode = _getUpstreamSelectableNodeBefore(document, documentLayout, startingNode);
    if (upstreamNode != null) {
      newNodeId = upstreamNode.id;
      final previousComponent = documentLayout.getComponentByNodeId(newNodeId);
      newPosition = previousComponent?.getBeginningPosition();
    }
  }

  if (newNodeId == null || newPosition == null) {
    return;
  }

  selection.value = selection.value!.expandTo(
    DocumentPosition(
      nodeId: newNodeId,
      nodePosition: newPosition,
    ),
  );
}

/// Returns the first [DocumentNode] before [startingNode] whose
/// [DocumentComponent] is visually selectable.
DocumentNode? _getUpstreamSelectableNodeBefore(
  Document document,
  DocumentLayout documentLayout,
  DocumentNode startingNode,
) {
  bool foundSelectableNode = false;
  DocumentNode prevNode = startingNode;
  DocumentNode? selectableNode;
  do {
    selectableNode = document.getNodeBefore(prevNode);

    if (selectableNode != null) {
      final nextComponent = documentLayout.getComponentByNodeId(selectableNode.id);
      if (nextComponent != null) {
        foundSelectableNode = nextComponent.isVisualSelectionSupported();
      }
      prevNode = selectableNode;
    }
  } while (!foundSelectableNode && selectableNode != null);

  return selectableNode;
}

/// Returns the first [DocumentNode] after [startingNode] whose
/// [DocumentComponent] is visually selectable.
DocumentNode? _getDownstreamSelectableNodeAfter(
  Document document,
  DocumentLayout documentLayout,
  DocumentNode startingNode,
) {
  bool foundSelectableNode = false;
  DocumentNode prevNode = startingNode;
  DocumentNode? selectableNode;
  do {
    selectableNode = document.getNodeAfter(prevNode);

    if (selectableNode != null) {
      final nextComponent = documentLayout.getComponentByNodeId(selectableNode.id);
      if (nextComponent != null) {
        foundSelectableNode = nextComponent.isVisualSelectionSupported();
      }
      prevNode = selectableNode;
    }
  } while (!foundSelectableNode && selectableNode != null);

  return selectableNode;
}

bool moveCaretUpstream({
  required Document document,
  required DocumentLayout documentLayout,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  MovementModifier? movementModifier,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionLeft(currentExtent.nodePosition, movementModifier);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getUpstreamSelectableNodeBefore(document, documentLayout, node);

    if (nextNode == null) {
      // We're at the beginning of the document and can't go anywhere.
      return false;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
    if (nextComponent == null) {
      return false;
    }
    newExtentNodePosition = nextComponent.getEndPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

  return true;
}

/// Moves the [DocumentComposer]'s selection extent position in the
/// downstream direction (to the right for left-to-right languages).
///
/// {@macro skip_unselectable_components}
///
/// Expands/contracts the selection if [expand] is [true], otherwise
/// collapses the selection or keeps it collapsed.
///
/// By default, moves one character at a time when the extent sits in
/// a [TextNode]. To move word-by-word, pass [MovementModifier.word]
/// in [movementModifier]. To move to the end of a line, pass
/// [MovementModifier.line] in [movementModifier].
///
/// Returns [true] if the extent moved, or the selection changed, e.g., the
/// selection collapsed but the extent stayed in the same place. Returns
/// [false] if the extent did not move and the selection did not change.
bool moveCaretDownstream({
  required Document document,
  required DocumentLayout documentLayout,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  MovementModifier? movementModifier,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionRight(currentExtent.nodePosition, movementModifier);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getDownstreamSelectableNodeAfter(document, documentLayout, node);

    if (nextNode == null) {
      // We're at the beginning/end of the document and can't go
      // anywhere.
      return false;
    }

    newExtentNodeId = nextNode.id;
    final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
    if (nextComponent == null) {
      throw Exception('Could not find next component to move the selection horizontally. Next node ID: ${nextNode.id}');
    }
    newExtentNodePosition = nextComponent.getBeginningPosition();
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

  return true;
}

/// Moves the [DocumentComposer]'s selection extent position up,
/// vertically, either by moving the selection extent up one line of
/// text, or by moving the selection extent up to the node above the
/// current extent.
///
/// If the current selection extent wants to move to the node above,
/// but there is no node above the current extent, the extent is moved
/// to the "start" position of the current node. For example: the extent
/// moves from the middle of the first line of text in a paragraph to
/// the beginning of the paragraph.
///
/// {@macro skip_unselectable_components}
///
/// Expands/contracts the selection if [expand] is [true], otherwise
/// collapses the selection or keeps it collapsed.
///
/// Returns [true] if the extent moved, or the selection changed, e.g., the
/// selection collapsed but the extent stayed in the same place. Returns
/// [false] if the extent did not move and the selection did not change.
bool moveCaretUp({
  required Document document,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  required DocumentLayout documentLayout,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionUp(currentExtent.nodePosition);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getUpstreamSelectableNodeBefore(document, documentLayout, node);
    if (nextNode != null) {
      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
      if (nextComponent == null) {
        editorOpsLog.shout("Tried to obtain non-existent component by node id: $newExtentNodeId");
        return false;
      }
      final offsetToMatch = extentComponent.getOffsetForPosition(currentExtent.nodePosition);
      newExtentNodePosition = nextComponent.getEndPositionNearX(offsetToMatch.dx);
    } else {
      // We're at the top of the document. Move the cursor to the
      // beginning of the current node.
      newExtentNodePosition = extentComponent.getBeginningPosition();
    }
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

  return true;
}

/// Moves the [DocumentComposer]'s selection extent position down,
/// vertically, either by moving the selection extent down one line of
/// text, or by moving the selection extent down to the node below the
/// current extent.
///
/// If the current selection extent wants to move to the node below,
/// but there is no node below the current extent, the extent is moved
/// to the "end" position of the current node. For example: the extent
/// moves from the middle of the last line of text in a paragraph to
/// the end of the paragraph.
///
/// {@macro skip_unselectable_components}
///
/// Expands/contracts the selection if [expand] is [true], otherwise
/// collapses the selection or keeps it collapsed.
///
/// Returns [true] if the extent moved, or the selection changed, e.g., the
/// selection collapsed but the extent stayed in the same place. Returns
/// [false] if the extent did not move and the selection did not change.
bool moveCaretDown({
  required Document document,
  required DocumentLayout documentLayout,
  required ValueNotifier<DocumentSelection?> selectionNotifier,
  required bool retainCollapsedSelection,
}) {
  final selection = selectionNotifier.value;
  if (selection == null) {
    return false;
  }

  final currentExtent = selection.extent;
  final nodeId = currentExtent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node == null) {
    return false;
  }
  final extentComponent = documentLayout.getComponentByNodeId(nodeId);
  if (extentComponent == null) {
    return false;
  }

  String newExtentNodeId = nodeId;
  NodePosition? newExtentNodePosition = extentComponent.movePositionDown(currentExtent.nodePosition);

  if (newExtentNodePosition == null) {
    // Move to next node
    final nextNode = _getDownstreamSelectableNodeAfter(document, documentLayout, node);
    if (nextNode != null) {
      newExtentNodeId = nextNode.id;
      final nextComponent = documentLayout.getComponentByNodeId(nextNode.id);
      if (nextComponent == null) {
        editorOpsLog.shout("Tried to obtain non-existent component by node id: $newExtentNodeId");
        return false;
      }
      final offsetToMatch = extentComponent.getOffsetForPosition(currentExtent.nodePosition);
      newExtentNodePosition = nextComponent.getBeginningPositionNearX(offsetToMatch.dx);
    } else {
      // We're at the bottom of the document. Move the cursor to the
      // end of the current node.
      newExtentNodePosition = extentComponent.getEndPosition();
    }
  }

  final newExtent = DocumentPosition(
    nodeId: newExtentNodeId,
    nodePosition: newExtentNodePosition,
  );

  DocumentSelection? newSelection = selection.expandTo(newExtent);
  if (newSelection.isCollapsed && !retainCollapsedSelection) {
    newSelection = null;
  }
  selectionNotifier.value = newSelection;

  return true;
}

/// Sets the [selection]'s value to include the entire [Document].
///
/// Always returns [true].
bool selectAll(Document document, ValueNotifier<DocumentSelection?> selection) {
  final nodes = document.nodes;
  if (nodes.isEmpty) {
    return false;
  }

  selection.value = DocumentSelection(
    base: DocumentPosition(
      nodeId: nodes.first.id,
      nodePosition: nodes.first.beginningPosition,
    ),
    extent: DocumentPosition(
      nodeId: nodes.last.id,
      nodePosition: nodes.last.endPosition,
    ),
  );

  return true;
}

/// Serializes the current selection to plain text, and adds it to the
/// clipboard.
void copy({
  required Document document,
  required DocumentSelection selection,
}) {
  final textToCopy = _textInSelection(
    document: document,
    documentSelection: selection,
  );
  // TODO: figure out a general approach for asynchronous behaviors that
  //       need to be carried out in response to user input.
  _saveToClipboard(textToCopy);
}

String _textInSelection({
  required Document document,
  required DocumentSelection documentSelection,
}) {
  final selectedNodes = document.getNodesInside(
    documentSelection.base,
    documentSelection.extent,
  );

  final buffer = StringBuffer();
  for (int i = 0; i < selectedNodes.length; ++i) {
    final selectedNode = selectedNodes[i];
    dynamic nodeSelection;

    if (i == 0) {
      // This is the first node and it may be partially selected.
      final baseSelectionPosition = selectedNode.id == documentSelection.base.nodeId
          ? documentSelection.base.nodePosition
          : documentSelection.extent.nodePosition;

      final extentSelectionPosition =
          selectedNodes.length > 1 ? selectedNode.endPosition : documentSelection.extent.nodePosition;

      nodeSelection = selectedNode.computeSelection(
        base: baseSelectionPosition,
        extent: extentSelectionPosition,
      );
    } else if (i == selectedNodes.length - 1) {
      // This is the last node and it may be partially selected.
      final nodePosition = selectedNode.id == documentSelection.base.nodeId
          ? documentSelection.base.nodePosition
          : documentSelection.extent.nodePosition;

      nodeSelection = selectedNode.computeSelection(
        base: selectedNode.beginningPosition,
        extent: nodePosition,
      );
    } else {
      // This node is fully selected. Copy the whole thing.
      nodeSelection = selectedNode.computeSelection(
        base: selectedNode.beginningPosition,
        extent: selectedNode.endPosition,
      );
    }

    final nodeContent = selectedNode.copyContent(nodeSelection);
    if (nodeContent != null) {
      buffer.write(nodeContent);
      if (i < selectedNodes.length - 1) {
        buffer.writeln();
      }
    }
  }
  return buffer.toString();
}

Future<void> _saveToClipboard(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
