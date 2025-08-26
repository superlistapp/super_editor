import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';

/// A [DocumentComponent] that presents other components, within a column.
class ColumnDocumentComponent extends StatefulWidget {
  const ColumnDocumentComponent({
    super.key,
    // required this.childComponentIds,
    required this.childComponentKeys,
    required this.children,
  });

  // final List<String> childComponentIds;

  final List<GlobalKey<DocumentComponent>> childComponentKeys;

  final List<Widget> children;

  @override
  State<ColumnDocumentComponent> createState() => _ColumnDocumentComponentState();
}

class _ColumnDocumentComponentState extends State<ColumnDocumentComponent>
    with DocumentComponent<ColumnDocumentComponent> {
  @override
  NodePosition getBeginningPosition() {
    return CompositeNodePosition(
      // TODO: We're using ad hoc component IDs based on child index. Come up with robust solution.
      "0",
      // widget.childComponentIds.first,
      widget.childComponentKeys.first.currentState!.getBeginningPosition(),
    );
  }

  @override
  NodePosition getEndPosition() {
    print("getEndPosition() - key: ${widget.childComponentKeys.last}");
    return CompositeNodePosition(
      // TODO: We're using ad hoc component IDs based on child index. Come up with robust solution.
      "${widget.children.length - 1}",
      // widget.childComponentIds.last,
      widget.childComponentKeys.last.currentState!.getEndPosition(),
    );
  }

  @override
  NodePosition getBeginningPositionNearX(double x) {
    return widget.childComponentKeys.first.currentState!.getBeginningPositionNearX(x);
  }

  @override
  NodePosition getEndPositionNearX(double x) {
    return widget.childComponentKeys.last.currentState!.getEndPositionNearX(x);
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    print("getDesiredCursorAtOffset() - local offset: $localOffset");
    final childIndexNearestToOffset = _getIndexOfChildNearestTo(localOffset);
    final childOffset = _projectColumnOffsetToChildSpace(localOffset, childIndexNearestToOffset);
    print(" - offset in child ($childIndexNearestToOffset): $childOffset");

    return widget.childComponentKeys[childIndexNearestToOffset].currentState!.getDesiredCursorAtOffset(childOffset);
  }

  @override
  NodePosition? getPositionAtOffset(Offset localOffset) {
    // TODO: Change all implementations of getPositionAtOffset to be exact, not nearest - but this first
    //       requires updating the gesture offset lookups.
    print("Column component - getPositionAtOffset() - local offset: $localOffset");
    if (localOffset.dy < 0) {
      return CompositeNodePosition(
        // TODO: use real IDs, not just index.
        "0",
        widget.childComponentKeys.first.currentState!.getBeginningPosition(),
      );
    }

    final columnBox = _columnBox;
    if (localOffset.dy > columnBox.size.height) {
      return CompositeNodePosition(
        // TODO: use real IDs, not just index.
        "${widget.children.length - 1}",
        widget.childComponentKeys.last.currentState!.getEndPosition(),
      );
    }

    final childIndex = _getIndexOfChildNearestTo(localOffset);
    final childOffset = _projectColumnOffsetToChildSpace(localOffset, childIndex);

    print(" - Returning position at offset for child $childIndex, at child offset: $childOffset");
    return CompositeNodePosition(
      // TODO: use real IDs, not just index.
      "$childIndex",
      widget.childComponentKeys[childIndex].currentState!.getPositionAtOffset(childOffset)!,
    );
  }

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get edge near position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    return _getChildComponentAtPosition(nodePosition).getEdgeForPosition(nodePosition.childNodePosition);
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get offset for position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    final childIndex = _findChildIndexForPosition(nodePosition);
    return _getChildComponentAtIndex(childIndex).getOffsetForPosition(nodePosition.childNodePosition);
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get bounding rectangle for position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    return _getChildComponentAtIndex(
      _findChildIndexForPosition(nodePosition),
    ).getRectForPosition(nodePosition.childNodePosition);
  }

  @override
  Rect getRectForSelection(NodePosition baseNodePosition, NodePosition extentNodePosition) {
    if (baseNodePosition is! CompositeNodePosition || extentNodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried to select within a ColumnDocumentComponent with invalid position types - base: $baseNodePosition, extent: $extentNodePosition");
    }

    final baseIndex = int.parse(baseNodePosition.childNodeId);

    final extentIndex = int.parse(extentNodePosition.childNodeId);
    final extentComponent = widget.childComponentKeys[extentIndex].currentState!;

    DocumentComponent topComponent;
    final componentBoundingBoxes = <Rect>[];

    // Collect bounding boxes for all selected components.
    final columnComponentBox = context.findRenderObject() as RenderBox;
    if (baseIndex == extentIndex) {
      // Selection within a single node.
      topComponent = extentComponent;
      final componentOffsetInDocument = (topComponent.context.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero, ancestor: columnComponentBox);

      final componentBoundingBox = extentComponent
          .getRectForSelection(
            baseNodePosition.childNodePosition,
            extentNodePosition.childNodePosition,
          )
          .translate(
            componentOffsetInDocument.dx,
            componentOffsetInDocument.dy,
          );
      componentBoundingBoxes.add(componentBoundingBox);
    } else {
      // Selection across nodes.
      final topNodeIndex = min(baseIndex, extentIndex);
      final topColumnPosition = baseIndex < extentIndex ? baseNodePosition : extentNodePosition;

      final bottomNodeIndex = max(baseIndex, extentIndex);
      final bottomColumnPosition = baseIndex < extentIndex ? extentNodePosition : baseNodePosition;

      for (int i = topNodeIndex; i <= bottomNodeIndex; ++i) {
        final component = widget.childComponentKeys[i].currentState!;
        final componentOffsetInColumnComponent = (component.context.findRenderObject() as RenderBox)
            .localToGlobal(Offset.zero, ancestor: columnComponentBox);

        if (i == topNodeIndex) {
          // This is the first node. The selection goes from
          // startPosition to the end of the node.
          final firstNodeEndPosition = component.getEndPosition();
          final selectionRectInComponent = component.getRectForSelection(
            topColumnPosition.childNodePosition,
            firstNodeEndPosition,
          );
          final componentRectInDocument = selectionRectInComponent.translate(
            componentOffsetInColumnComponent.dx,
            componentOffsetInColumnComponent.dy,
          );
          componentBoundingBoxes.add(componentRectInDocument);
        } else if (i == bottomNodeIndex) {
          // This is the last node. The selection goes from
          // the beginning of the node to endPosition.
          final lastNodeStartPosition = component.getBeginningPosition();
          final selectionRectInComponent = component.getRectForSelection(
            lastNodeStartPosition,
            bottomColumnPosition.childNodePosition,
          );
          final componentRectInColumnLayout = selectionRectInComponent.translate(
            componentOffsetInColumnComponent.dx,
            componentOffsetInColumnComponent.dy,
          );
          componentBoundingBoxes.add(componentRectInColumnLayout);
        } else {
          // This node sits between start and end. All content
          // is selected.
          final selectionRectInComponent = component.getRectForSelection(
            component.getBeginningPosition(),
            component.getEndPosition(),
          );
          final componentRectInColumnLayout = selectionRectInComponent.translate(
            componentOffsetInColumnComponent.dx,
            componentOffsetInColumnComponent.dy,
          );
          componentBoundingBoxes.add(componentRectInColumnLayout);
        }
      }
    }

    // Combine all component boxes into one big bounding box.
    Rect boundingBox = componentBoundingBoxes.first;
    for (int i = 1; i < componentBoundingBoxes.length; ++i) {
      boundingBox = boundingBox.expandToInclude(componentBoundingBoxes[i]);
    }

    return boundingBox;
  }

  @override
  NodeSelection getCollapsedSelectionAt(NodePosition nodePosition) {
    if (nodePosition is! CompositeNodePosition) {
      throw Exception(
          "Tried get position within a ColumnDocumentComponent with invalid type of node position: $nodePosition");
    }

    // TODO: implement getCollapsedSelectionAt
    throw UnimplementedError();
  }

  @override
  NodeSelection getSelectionBetween({required NodePosition basePosition, required NodePosition extentPosition}) {
    if (basePosition is! CompositeNodePosition || extentPosition is! CompositeNodePosition) {
      throw Exception(
          "Tried to select within a ColumnDocumentComponent with invalid position types - base: $basePosition, extent: $extentPosition");
    }

    // TODO: implement getSelectionBetween
    throw UnimplementedError();
  }

  @override
  NodeSelection? getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    // TODO: implement getSelectionInRange
    throw UnimplementedError();
  }

  @override
  NodeSelection getSelectionOfEverything() {
    // TODO: implement getSelectionOfEverything
    throw UnimplementedError();
  }

  @override
  NodePosition? movePositionUp(NodePosition currentPosition) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final upWithinChild = child.movePositionUp(currentPosition.childNodePosition);
    if (upWithinChild != null) {
      return currentPosition.moveWithinChild(upWithinChild);
    }

    if (childIndex == 0) {
      // Nothing above this child.
      return null;
    }

    // The next position up must be the ending position of the previous component.
    return CompositeNodePosition(
      // TODO: We're using ad hoc component IDs based on child index. Come up with robust solution.
      "${childIndex - 1}",
      // widget.childComponentIds[childIndex - 1],
      _getChildComponentAtIndex(childIndex - 1).getEndPosition(),
    );
  }

  @override
  NodePosition? movePositionDown(NodePosition currentPosition) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final downWithinChild = child.movePositionDown(currentPosition.childNodePosition);
    if (downWithinChild != null) {
      return currentPosition.moveWithinChild(downWithinChild);
    }

    if (childIndex == widget.children.length - 1) {
      // Nothing below this child.
      return null;
    }

    // The next position down must be the beginning position of the next component.
    return CompositeNodePosition(
      // TODO: We're using ad hoc component IDs based on child index. Come up with robust solution.
      "${childIndex + 1}",
      // widget.childComponentIds[childIndex + 1],
      _getChildComponentAtIndex(childIndex + 1).getBeginningPosition(),
    );
  }

  @override
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final leftWithinChild = child.movePositionLeft(currentPosition.childNodePosition);
    if (leftWithinChild != null) {
      return currentPosition.moveWithinChild(leftWithinChild);
    }

    if (childIndex == 0) {
      // Nothing above this child.
      return null;
    }

    // The next position left must be the ending position of the previous component.
    // TODO: This assumes left-to-right content ordering, which isn't true for some
    //       languages. Revisit this when/if we need RTL support for this behavior.
    return CompositeNodePosition(
      // TODO: We're using ad hoc component IDs based on child index. Come up with robust solution.
      "${childIndex - 1}",
      // widget.childComponentIds[childIndex - 1],
      _getChildComponentAtIndex(childIndex - 1).getEndPosition(),
    );
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition is! CompositeNodePosition) {
      return null;
    }

    final childIndex = _findChildIndexForPosition(currentPosition);
    final child = _getChildComponentAtIndex(childIndex);
    final rightWithinChild = child.movePositionRight(currentPosition.childNodePosition);
    if (rightWithinChild != null) {
      return currentPosition.moveWithinChild(rightWithinChild);
    }

    if (childIndex == widget.children.length - 1) {
      // Nothing below this child.
      return null;
    }

    // The next position right must be the beginning position of the next component.
    // TODO: This assumes left-to-right content ordering, which isn't true for some
    //       languages. Revisit this when/if we need RTL support for this behavior.
    return CompositeNodePosition(
      // TODO: We're using ad hoc component IDs based on child index. Come up with robust solution.
      "${childIndex + 1}",
      // widget.childComponentIds[childIndex + 1],
      _getChildComponentAtIndex(childIndex + 1).getBeginningPosition(),
    );
  }

  DocumentComponent _getChildComponentAtPosition(CompositeNodePosition columnPosition) {
    final childIndex = int.parse(columnPosition.childNodeId);
    return widget.childComponentKeys[childIndex].currentState!;
  }

  DocumentComponent _getChildComponentAtIndex(int childIndex) {
    return widget.childComponentKeys[childIndex].currentState!;
  }

  int _findChildIndexForPosition(CompositeNodePosition position) {
    for (int i = 0; i < widget.children.length; i += 1) {
      // TODO: We're using ad hoc component IDs based on child index. Come up with robust solution.
      if ("$i" == position.childNodeId) {
        return i;
      }
    }

    return -1;
  }

  int _getIndexOfChildNearestTo(Offset componentOffset) {
    if (componentOffset.dy < 0) {
      // Offset is above this component. Return the first item in the column.
      return 0;
    }

    final columnBox = context.findRenderObject() as RenderBox;
    final componentHeight = columnBox.size.height;
    if (componentOffset.dy > componentHeight) {
      // The offset is below this component. Return the last item in the column.
      return widget.children.length - 1;
    }

    // The offset is vertically somewhere within this column. Return the child
    // whose y-bounds contain this offset's y-value.
    for (int i = 0; i < widget.children.length; i += 1) {
      final childBox = widget.childComponentKeys[i].currentContext!.findRenderObject() as RenderBox;
      final childBottomY = childBox.localToGlobal(Offset.zero, ancestor: columnBox).dy + childBox.size.height;
      if (childBottomY >= componentOffset.dy) {
        // Found the child that vertically contains the offset. Horizontal offset
        // doesn't matter because we're looking for "nearest".
        return i;
      }
    }

    throw Exception("Tried to find the child nearest to component offset ($componentOffset) but couldn't find one.");
  }

  /// Given an offset that's relative to this column, finds where that same point sits
  /// within the given child, and returns that offset local to the child coordinate system.
  Offset _projectColumnOffsetToChildSpace(Offset columnOffset, int childIndex) {
    return _getChildBoxAtIndex(childIndex).globalToLocal(columnOffset, ancestor: _columnBox);
  }

  RenderBox get _columnBox => context.findRenderObject() as RenderBox;

  RenderBox _getChildBoxAtIndex(int childIndex) {
    return widget.childComponentKeys[childIndex].currentContext!.findRenderObject() as RenderBox;
  }

  @override
  Widget build(BuildContext context) {
    print("Composite component children: ${widget.children}");
    print("Child component keys: ${widget.childComponentKeys}");

    return IgnorePointer(
      child: Column(
        children: widget.children,
      ),
    );
  }
}

class CompositeNodePosition implements NodePosition {
  const CompositeNodePosition(this.childNodeId, this.childNodePosition);

  final String childNodeId;
  final NodePosition childNodePosition;

  CompositeNodePosition moveWithinChild(NodePosition newPosition) {
    return CompositeNodePosition(childNodeId, newPosition);
  }

  @override
  bool isEquivalentTo(NodePosition other) {
    return this == other;
  }

  @override
  String toString() => "[CompositeNodePosition] - $childNodeId -> $childNodePosition";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeNodePosition &&
          runtimeType == other.runtimeType &&
          childNodeId == other.childNodeId &&
          childNodePosition == other.childNodePosition;

  @override
  int get hashCode => childNodeId.hashCode ^ childNodePosition.hashCode;
}
