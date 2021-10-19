import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SliverStickToBottom extends SingleChildRenderObjectWidget {
  /// Creates a sliver that positions its child at the bottom of the screen or
  /// scrolls it off screen if there's not enough space
  const SliverStickToBottom({
    required Widget child,
    Key? key,
  }) : super(key: key, child: child);

  @override
  RenderSliverStickToBottom createRenderObject(BuildContext context) =>
      RenderSliverStickToBottom();
}

class RenderSliverStickToBottom extends RenderSliverSingleBoxAdapter {
  /// Creates a [RenderSliver] that wraps a [RenderBox] will be aligned at the
  /// bottom or scrolled off screen
  RenderSliverStickToBottom({
    RenderBox? child,
  }) : super(child: child);

  @override
  void performLayout() {
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    double? childExtent;
    switch (constraints.axis) {
      case Axis.horizontal:
        childExtent = child!.size.width;
        break;
      case Axis.vertical:
        childExtent = child!.size.height;
        break;
    }
    final paintedChildSize = calculatePaintOffset(
      constraints,
      from: 0,
      to: childExtent,
    );
    final cacheExtent = calculateCacheOffset(
      constraints,
      from: 0,
      to: childExtent,
    );

    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    geometry = SliverGeometry(
      paintOrigin: math.max(0, constraints.remainingPaintExtent - childExtent),
      scrollExtent: childExtent,
      paintExtent: math.min(childExtent, constraints.remainingPaintExtent),
      cacheExtent: math.min(cacheExtent, constraints.remainingPaintExtent),
      maxPaintExtent: math.max(childExtent, constraints.remainingPaintExtent),
      hitTestExtent: paintedChildSize,
      hasVisualOverflow: childExtent > constraints.remainingPaintExtent ||
          constraints.scrollOffset > 0.0,
    );
    setChildParentData(child!, constraints, geometry!);
  }
}
