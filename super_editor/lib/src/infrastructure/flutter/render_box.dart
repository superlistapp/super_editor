import 'package:flutter/rendering.dart';

/// Extensions for relationships between boxes that are axis-aligned, e.g., boxes
/// that might have different offsets and scales but aren't rotated.
extension AxisAlignedBoxes on RenderBox {
  /// Returns this [RenderBox]'s bounds in the global coordinate space.
  Rect get globalRect => Rect.fromPoints(
        localToGlobal(Offset.zero),
        localToGlobal(
          Offset(size.width, size.height),
        ),
      );
}
