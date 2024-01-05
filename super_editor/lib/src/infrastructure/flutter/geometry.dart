import 'dart:ui';

extension Edges on Rect {
  /// Returns a zero-width `Rect` along the left side of this rectangle.
  Rect get leftEdge => Rect.fromLTWH(left, top, 0, height);

  /// Returns a zero-width `Rect` along the right side of this rectangle.
  Rect get rightEdge => Rect.fromLTWH(right, top, 0, height);
}
