import "package:flutter/rendering.dart";
import "package:flutter/widgets.dart";

/// Component that allows mixing RenderSliver child with other RenderBox
/// children. The RenderSliver child will be laid out first, and then the
/// RenderBox children will be laid out to cover the entire scroll extent
/// of the RenderSliver child.
class SliverHybridStack extends MultiChildRenderObjectWidget {
  /// Creates a SliverHybridStack. The [children] must contain exactly one
  /// child that a RenderSliver, and zero or more RenderBox children.
  /// The [fillViewport] flag controls whether the RenderBox children should
  /// be stretched if necessary to fill the entire viewport.
  const SliverHybridStack({
    super.key,
    this.fillViewport = false,
    super.children,
  });

  final bool fillViewport;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSliverHybridStack(fillViewport: fillViewport);
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderSliver renderObject) {
    (renderObject as _RenderSliverHybridStack).fillViewport = fillViewport;
  }
}

class _ChildParentData extends SliverLogicalParentData with ContainerParentDataMixin<RenderObject> {}

class _RenderSliverHybridStack extends RenderSliver
    with ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>>, RenderSliverHelpers {
  _RenderSliverHybridStack({required this.fillViewport});

  bool fillViewport;

  @override
  void performLayout() {
    RenderSliver? sliver;
    var child = firstChild;
    while (child != null) {
      if (child is RenderSliver) {
        assert(sliver == null, "There can only be one sliver in a SliverHybridStack");
        sliver = child;
        break;
      }
      child = childAfter(child);
    }
    if (sliver == null) {
      geometry = SliverGeometry.zero;
      return;
    }

    (sliver.parentData! as SliverLogicalParentData).layoutOffset = 0.0;
    sliver.layout(constraints, parentUsesSize: true);
    final SliverGeometry sliverLayoutGeometry = sliver.geometry!;
    if (sliverLayoutGeometry.scrollOffsetCorrection != null) {
      geometry = SliverGeometry(
        scrollOffsetCorrection: sliverLayoutGeometry.scrollOffsetCorrection,
      );
      return;
    }

    geometry = SliverGeometry(
      scrollExtent: sliverLayoutGeometry.scrollExtent,
      paintExtent: sliverLayoutGeometry.paintExtent,
      maxPaintExtent: sliverLayoutGeometry.maxPaintExtent,
      maxScrollObstructionExtent: sliverLayoutGeometry.maxScrollObstructionExtent,
      cacheExtent: sliverLayoutGeometry.cacheExtent,
      hasVisualOverflow: sliverLayoutGeometry.hasVisualOverflow,
    );

    final boxConstraints = ScrollingBoxConstraints(
      minWidth: constraints.crossAxisExtent,
      maxWidth: constraints.crossAxisExtent,
      minHeight: sliverLayoutGeometry.scrollExtent,
      maxHeight: sliverLayoutGeometry.scrollExtent,
      scrollOffset: constraints.scrollOffset,
    );

    child = firstChild;
    while (child != null) {
      if (child is RenderBox) {
        final childParentData = child.parentData! as SliverLogicalParentData;
        childParentData.layoutOffset = -constraints.scrollOffset;
        if (constraints.scrollOffset == 0.0 && fillViewport) {
          child.layout(
            BoxConstraints.tightFor(
              width: constraints.crossAxisExtent,
              height: constraints.viewportMainAxisExtent,
            ),
            parentUsesSize: true,
          );
        } else {
          child.layout(boxConstraints, parentUsesSize: true);
        }
      }
      child = childAfter(child);
    }
  }

  @override
  bool hitTest(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    if (mainAxisPosition >= 0.0 && crossAxisPosition >= 0.0 && crossAxisPosition < constraints.crossAxisExtent) {
      if (hitTestChildren(result, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition) ||
          hitTestSelf(mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition)) {
        result.add(SliverHitTestEntry(
          this,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        ));
        return true;
      }
    }
    return false;
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    var child = lastChild;
    while (child != null) {
      if (child is RenderSliver) {
        final isHit = child.hitTest(
          result,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        );
        if (isHit) {
          return true;
        }
      } else if (child is RenderBox) {
        final boxResult = BoxHitTestResult.wrap(result);
        final isHit = hitTestBoxChild(
          boxResult,
          child,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        );
        if (isHit) {
          return true;
        }
      }
      child = childBefore(child);
    }
    return false;
  }

  @override
  void setupParentData(covariant RenderObject child) {
    child.parentData = _ChildParentData();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final childParentData = child.parentData! as SliverLogicalParentData;
      context.paintChild(
        child,
        offset + Offset(0, childParentData.layoutOffset!),
      );
      child = childAfter(child);
    }
  }

  @override
  void applyPaintTransform(covariant RenderObject child, Matrix4 transform) {
    final childParentData = child.parentData! as SliverLogicalParentData;
    transform.translate(0.0, childParentData.layoutOffset!);
  }

  @override
  double childMainAxisPosition(covariant RenderObject child) {
    final childParentData = child.parentData! as SliverLogicalParentData;
    return childParentData.layoutOffset!;
  }
}

// Box constraints that will cause relayout when the scroll offset changes.
class ScrollingBoxConstraints extends BoxConstraints {
  const ScrollingBoxConstraints({
    super.minWidth,
    super.maxWidth,
    super.minHeight,
    super.maxHeight,
    required this.scrollOffset,
  });

  final double scrollOffset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScrollingBoxConstraints && super == other && scrollOffset == other.scrollOffset;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, scrollOffset);
}
