import 'dart:ui';

extension Edges on Rect {
  /// Returns a zero-width `Rect` along the left side of this rectangle.
  Rect get leftEdge => Rect.fromLTWH(left, top, 0, height);

  /// Returns a zero-width `Rect` along the right side of this rectangle.
  Rect get rightEdge => Rect.fromLTWH(right, top, 0, height);
}

extension RectangleMutation on Rect {
  /// Returns a copy of this `Rect`, translated by the given [offset].
  ///
  /// Translation of this `Rect` means that every corner of the existing
  /// `Rect` is recomputed as `(corner.dx + offset.dx, corner.dy + offset.dy)`.
  Rect translateByOffset(Offset offset) => translate(offset.dx, offset.dy);

  /// Returns a copy of this `Rect` with the left edge moved [amount] to the
  /// left.
  ///
  /// A positive [amount] moves the left edge towards the left, a negative
  /// [amount] moves the left edge towards the right.
  ///
  /// It's the caller's responsibility to ensure that the movement of the left
  /// edge doesn't result in a broken `Rect`, i.e., a left edge that's further
  /// to the right than the right edge.
  Rect inflateLeft(double amount) => Rect.fromLTWH(left - amount, top, width + amount, height);

  /// Returns a copy of this `Rect` with the right edge moved [amount] to the
  /// right.
  ///
  /// A positive [amount] moves the right edge towards the right, a negative
  /// [amount] moves the right edge towards the left.
  ///
  /// It's the caller's responsibility to ensure that the movement of the right
  /// edge doesn't result in a broken `Rect`, i.e., a right edge that's further
  /// to the left than the left edge.
  Rect inflateRight(double amount) => Rect.fromLTWH(left, top, width + amount, height);
}
