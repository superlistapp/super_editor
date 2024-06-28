import 'package:flutter/rendering.dart';

/// Extension on [RenderSliver] that that brings over some of the missing
/// [RenderBox] functionality.
extension RenderSliverExt on RenderSliver {
  Size get size {
    assert(attached);
    return Size(geometry!.crossAxisExtent ?? constraints.crossAxisExtent, geometry!.paintExtent);
  }

  bool get hasSize {
    assert(attached);
    return geometry != null;
  }

  Offset globalToLocal(Offset point, {RenderObject? ancestor}) {
    assert(attached);
    final transform = getTransformTo(ancestor);
    transform.invert();
    return MatrixUtils.transformPoint(transform, point);
  }

  Offset localToGlobal(Offset point, {RenderObject? ancestor}) {
    assert(attached);
    final transform = getTransformTo(ancestor);
    return MatrixUtils.transformPoint(transform, point);
  }
}
