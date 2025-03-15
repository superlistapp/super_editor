import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Converts a [child] Sliver-based viewport into a [RenderBox] so that
/// the [child] can be used in situations that require intrinsic height,
/// dry layout, etc.
///
/// Ideally, unsliverizing would never be done. However, in some situations
/// it's unavoidable, such as when you don't control the decision to use Slivers,
/// or in a situation where you truly need Slivers in some cases, but also need
/// intrinsic sizing in others.
class Unsliverizer extends StatelessWidget {
  const Unsliverizer({
    super.key,
    this.scrollController,
    this.physics,
    required this.child,
  });

  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      physics: physics,
      child: _SliverToRenderBoxViewport(child: child),
    );
  }
}

class _SliverToRenderBoxViewport extends SingleChildRenderObjectWidget {
  const _SliverToRenderBoxViewport({
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderFakeViewport();
  }
}

class _RenderFakeViewport extends RenderBox
    with RenderObjectWithChildMixin<RenderSliver>
    implements RenderAbstractViewport {
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final layoutBox = _findFirstRenderBoxInSliverList(child!);
    return layoutBox.computeDryLayout(constraints);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final layoutBox = _findFirstRenderBoxInSliverList(child!);
    return layoutBox.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final layoutBox = _findFirstRenderBoxInSliverList(child!);
    return layoutBox.computeMinIntrinsicWidth(height);
  }

  @override
  computeMaxIntrinsicHeight(double width) {
    final layoutBox = _findFirstRenderBoxInSliverList(child!);
    return layoutBox.computeMaxIntrinsicHeight(width);
  }

  @override
  computeMinIntrinsicHeight(double width) {
    final layoutBox = _findFirstRenderBoxInSliverList(child!);
    return layoutBox.computeMinIntrinsicHeight(width);
  }

  RenderBox _findFirstRenderBoxInSliverList(RenderSliver sliver) {
    RenderSliver? firstSliver;
    RenderBox? firstBox;
    sliver.visitChildren((child) {
      if (child is RenderSliver && firstSliver == null) {
        firstSliver = child;
      }
      if (child is RenderBox && firstBox == null) {
        firstBox = child;
      }
    });
    return firstSliver != null ? _findFirstRenderBoxInSliverList(firstSliver!) : firstBox!;
  }

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, {Rect? rect, Axis? axis}) {
    print("getOffsetToReveal() - target: $target, rect: $rect");
    return const RevealedOffset(offset: 0, rect: Rect.zero);
  }

  @override
  void setupParentData(RenderObject child) {}

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child!.hitTest(
      SliverHitTestResult.wrap(result),
      mainAxisPosition: position.dy,
      crossAxisPosition: position.dx,
    );
  }

  @override
  void performLayout() {
    final childConstraints = SliverConstraints(
      axisDirection: AxisDirection.down,
      growthDirection: GrowthDirection.forward,
      userScrollDirection: ScrollDirection.forward,
      scrollOffset: 0,
      precedingScrollExtent: 0,
      overlap: 0,
      remainingPaintExtent: double.infinity, //constraints.maxHeight,
      crossAxisExtent: constraints.maxWidth,
      crossAxisDirection: AxisDirection.right,
      viewportMainAxisExtent: double.infinity, //constraints.maxHeight,
      remainingCacheExtent: double.infinity,
      cacheOrigin: 0,
    );

    child!.layout(childConstraints, parentUsesSize: true);

    final geometry = child!.geometry;
    print("Scroll extent: ${geometry?.scrollExtent}");
    size = Size(constraints.maxWidth, geometry!.scrollExtent);
  }

  @override
  Rect get paintBounds => Offset.zero & size;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(child!, offset);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    // No-op: Our child is always origin and axis aligned with this
    // render object. No transform needed.
  }

  @override
  void performResize() {}

  @override
  Rect get semanticBounds => Offset.zero & size;

  @override
  void debugAssertDoesMeetConstraints() {}
}
