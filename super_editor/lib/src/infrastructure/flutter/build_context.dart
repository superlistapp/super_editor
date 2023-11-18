import 'package:flutter/material.dart';

extension ScrollableFinder on BuildContext {
  /// Finds the nearest ancestor [Scrollable] with a vertical scroll within
  /// this [BuildContext].
  ScrollableState? get findAncestorScrollableWithVerticalScroll {
    final ancestorScrollable = Scrollable.maybeOf(this);
    if (ancestorScrollable == null) {
      return null;
    }

    final direction = ancestorScrollable.axisDirection;
    // If the direction is horizontal, then we are inside a widget like a TabBar
    // or a horizontal ListView, so we can't use the ancestor scrollable
    if (direction == AxisDirection.left || direction == AxisDirection.right) {
      return null;
    }

    return ancestorScrollable;
  }
}
