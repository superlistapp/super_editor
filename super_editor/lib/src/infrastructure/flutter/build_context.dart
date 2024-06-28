import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

extension ScrollableFinder on BuildContext {
  /// Finds the nearest ancestor [Scrollable] with a vertical scroll in the
  /// widget tree.
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

  /// Returns the RenderBox of the nearest ancestor [RenderAbstractViewport].
  RenderBox findViewportBox() {
    // findAncestorRenderObjectOfType traverses the element tree, which is
    // more dense then render object tree. So instead we traverse the
    // render object tree.
    var renderObject = findRenderObject();
    while (renderObject != null) {
      if (renderObject is RenderAbstractViewport) {
        return renderObject as RenderBox;
      }
      renderObject = renderObject.parent;
    }

    throw StateError('No RenderAbstractViewport ancestor found');
  }
}
