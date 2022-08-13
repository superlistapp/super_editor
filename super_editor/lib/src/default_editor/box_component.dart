import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../core/document_layout.dart';

// ignore: unused_element
final _log = Logger(scope: 'box_component.dart');

/// Base implementation for a [DocumentNode] that only supports [UpstreamDownstreamNodeSelection]s.
abstract class BlockNode extends DocumentNode {
  @override
  UpstreamDownstreamNodePosition get beginningPosition => const UpstreamDownstreamNodePosition.upstream();

  @override
  UpstreamDownstreamNodePosition get endPosition => const UpstreamDownstreamNodePosition.downstream();

  @override
  UpstreamDownstreamNodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! UpstreamDownstreamNodePosition) {
      throw Exception(
          'Expected a UpstreamDownstreamNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! UpstreamDownstreamNodePosition) {
      throw Exception(
          'Expected a UpstreamDownstreamNodePosition for position2 but received a ${position2.runtimeType}');
    }

    if (position1.affinity == TextAffinity.upstream || position2.affinity == TextAffinity.upstream) {
      return const UpstreamDownstreamNodePosition.upstream();
    } else {
      return const UpstreamDownstreamNodePosition.downstream();
    }
  }

  @override
  UpstreamDownstreamNodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! UpstreamDownstreamNodePosition) {
      throw Exception(
          'Expected a UpstreamDownstreamNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! UpstreamDownstreamNodePosition) {
      throw Exception(
          'Expected a UpstreamDownstreamNodePosition for position2 but received a ${position2.runtimeType}');
    }

    if (position1.affinity == TextAffinity.downstream || position2.affinity == TextAffinity.downstream) {
      return const UpstreamDownstreamNodePosition.upstream();
    } else {
      return const UpstreamDownstreamNodePosition.downstream();
    }
  }

  @override
  UpstreamDownstreamNodeSelection computeSelection({
    @required dynamic base,
    @required dynamic extent,
  }) {
    if (base is! UpstreamDownstreamNodePosition) {
      throw Exception('Expected a UpstreamDownstreamNodePosition for base but received a ${base.runtimeType}');
    }
    if (extent is! UpstreamDownstreamNodePosition) {
      throw Exception('Expected a UpstreamDownstreamNodePosition for extent but received a ${extent.runtimeType}');
    }

    return UpstreamDownstreamNodeSelection(base: base, extent: extent);
  }
}

/// Editor layout component that displays content that is either
/// entirely selected, or not selected, like an image or a
/// horizontal rule.
class BoxComponent extends StatefulWidget {
  const BoxComponent({
    Key? key,
    this.isVisuallySelectable = true,
    required this.child,
  }) : super(key: key);

  final bool isVisuallySelectable;
  final Widget child;

  @override
  State createState() => _BoxComponentState();
}

class _BoxComponentState extends State<BoxComponent> with DocumentComponent {
  @override
  UpstreamDownstreamNodePosition getBeginningPosition() {
    return const UpstreamDownstreamNodePosition.upstream();
  }

  @override
  UpstreamDownstreamNodePosition getBeginningPositionNearX(double x) {
    final width = (context.findRenderObject() as RenderBox).size.width;

    return x < width / 2
        ? const UpstreamDownstreamNodePosition.upstream()
        : const UpstreamDownstreamNodePosition.downstream();
  }

  @override
  UpstreamDownstreamNodePosition? movePositionLeft(dynamic currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition == const UpstreamDownstreamNodePosition.upstream()) {
      // Can't move any further left.
      return null;
    }

    return const UpstreamDownstreamNodePosition.upstream();
  }

  @override
  UpstreamDownstreamNodePosition? movePositionRight(dynamic currentPosition, [MovementModifier? movementModifier]) {
    if (currentPosition == const UpstreamDownstreamNodePosition.downstream()) {
      // Can't move any further right.
      return null;
    }

    return const UpstreamDownstreamNodePosition.downstream();
  }

  @override
  UpstreamDownstreamNodePosition? movePositionUp(dynamic currentPosition) {
    // BoxComponents don't support vertical movement.
    return null;
  }

  @override
  UpstreamDownstreamNodePosition? movePositionDown(dynamic currentPosition) {
    // BoxComponents don't support vertical movement.
    return null;
  }

  @override
  UpstreamDownstreamNodeSelection getCollapsedSelectionAt(nodePosition) {
    if (nodePosition is! UpstreamDownstreamNodePosition) {
      throw Exception('The given nodePosition ($nodePosition) is not compatible with BoxComponent');
    }

    return UpstreamDownstreamNodeSelection.collapsed(nodePosition);
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    return null;
  }

  @override
  UpstreamDownstreamNodePosition getEndPosition() {
    return const UpstreamDownstreamNodePosition.downstream();
  }

  @override
  UpstreamDownstreamNodePosition getEndPositionNearX(double x) {
    final width = (context.findRenderObject() as RenderBox).size.width;

    return x < width / 2
        ? const UpstreamDownstreamNodePosition.upstream()
        : const UpstreamDownstreamNodePosition.downstream();
  }

  @override
  Offset getOffsetForPosition(nodePosition) {
    if (nodePosition is! UpstreamDownstreamNodePosition) {
      throw Exception('Expected nodePosition of type UpstreamDownstreamNodePosition but received: $nodePosition');
    }

    final myBox = context.findRenderObject() as RenderBox;

    if (nodePosition.affinity == TextAffinity.upstream) {
      // Technically, we could return any offset in the left half of the component.
      // Arbitrary, we'll return the position at the center of the left half of
      // the component.
      return Offset(myBox.size.width / 4, myBox.size.height / 2);
    } else {
      // Technically, we could return any offset in the right half of the component.
      // Arbitrary, we'll return the position at the center of the right half of
      // the component.
      return Offset(3 * myBox.size.width / 4, myBox.size.height / 2);
    }
  }

  @override
  Rect getRectForPosition(dynamic nodePosition) {
    if (nodePosition is! UpstreamDownstreamNodePosition) {
      throw Exception('Expected nodePosition of type UpstreamDownstreamNodePosition but received: $nodePosition');
    }

    final myBox = context.findRenderObject() as RenderBox;

    if (nodePosition.affinity == TextAffinity.upstream) {
      // Vertical line to the left of the component.
      return Rect.fromLTWH(-1, 0, 1, myBox.size.height);
    } else {
      // Vertical line to the right of the component.
      return Rect.fromLTWH(myBox.size.width, 0, 1, myBox.size.height);
    }
  }

  @override
  Rect getRectForSelection(dynamic basePosition, dynamic extentPosition) {
    if (basePosition is! UpstreamDownstreamNodePosition) {
      throw Exception('Expected nodePosition of type UpstreamDownstreamNodePosition but received: $basePosition');
    }
    if (extentPosition is! UpstreamDownstreamNodePosition) {
      throw Exception('Expected nodePosition of type UpstreamDownstreamNodePosition but received: $extentPosition');
    }

    final selection = UpstreamDownstreamNodeSelection(base: basePosition, extent: extentPosition);
    if (selection.isCollapsed) {
      return getRectForPosition(selection.extent);
    }

    // The whole component is selected.
    final myBox = context.findRenderObject() as RenderBox;
    return Offset.zero & myBox.size;
  }

  @override
  UpstreamDownstreamNodePosition getPositionAtOffset(Offset localOffset) {
    final myBox = context.findRenderObject() as RenderBox;

    if (localOffset.dx <= myBox.size.width / 2) {
      return const UpstreamDownstreamNodePosition.upstream();
    } else {
      return const UpstreamDownstreamNodePosition.downstream();
    }
  }

  @override
  UpstreamDownstreamNodeSelection getSelectionBetween({required basePosition, required extentPosition}) {
    if (basePosition is! UpstreamDownstreamNodePosition) {
      throw Exception('The given basePosition ($basePosition) is not compatible with BoxComponent');
    }
    if (extentPosition is! UpstreamDownstreamNodePosition) {
      throw Exception('The given extentPosition ($extentPosition) is not compatible with BoxComponent');
    }

    return UpstreamDownstreamNodeSelection(base: basePosition, extent: extentPosition);
  }

  @override
  UpstreamDownstreamNodeSelection getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    return getSelectionBetween(
      basePosition: getPositionAtOffset(localBaseOffset),
      extentPosition: getPositionAtOffset(localExtentOffset),
    );
  }

  @override
  UpstreamDownstreamNodeSelection getSelectionOfEverything() {
    return const UpstreamDownstreamNodeSelection.all();
  }

  @override
  bool isVisualSelectionSupported() => widget.isVisuallySelectable;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class SelectableBox extends StatelessWidget {
  const SelectableBox({
    Key? key,
    this.selection,
    required this.selectionColor,
    required this.child,
  }) : super(key: key);

  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isSelected = selection != null && !selection!.isCollapsed;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? selectionColor.withOpacity(0.5) : Colors.transparent,
          ),
          position: DecorationPosition.foreground,
          child: child,
        ),
      ),
    );
  }
}
