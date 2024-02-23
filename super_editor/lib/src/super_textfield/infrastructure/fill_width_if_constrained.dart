import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Widget that constrains its [child]s width in different ways depending on the
/// incoming width constraint.
///
/// Rules:
///  * If the constraints from the parent has a constrained width, then the [child]
///    is forced to be EXACTLY as wide the incoming max width.
///  * If the constraints from the parent has an unbounded width, and if there's an
///    ancestor `Scrollable`, then the [child] is forced to be AT LEAST as wide as the
///    Viewport of the `Scrollable`.
///  * If neither of the above two rules apply, the [child]'s width is set to its
///    intrinsic width. This implies that any provided [child] must have an intrinsic
///    width.
///
/// This widget is used to correctly align the text of a multiline [SuperText] with
/// a constrained width. It's also used to constrain and align single-line text within
/// a horizontal scrollable.
class FillWidthIfConstrained extends SingleChildRenderObjectWidget {
  const FillWidthIfConstrained({
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderFillWidthIfConstrained(
      findAncestorScrollableWidth: _createViewportWidthLookup(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFillWidthIfConstrained renderObject) {
    renderObject.findAncestorScrollableWidth = _createViewportWidthLookup(context);
  }

  double? Function() _createViewportWidthLookup(BuildContext context) {
    return () {
      return _getViewportWidth(context);
    };
  }

  double? _getViewportWidth(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      return null;
    }

    final direction = scrollable.axisDirection;
    // We only need to specify the width if we are inside a horizontal scrollable,
    // because in this case we might have an infinity maxWidth.
    if (direction == AxisDirection.up || direction == AxisDirection.down) {
      return null;
    }
    return (scrollable.context.findRenderObject() as RenderBox?)?.constraints.maxWidth;
  }
}

class RenderFillWidthIfConstrained extends RenderProxyBox {
  RenderFillWidthIfConstrained({
    required double? Function() findAncestorScrollableWidth,
  }) : _findAncestorScrollableWidth = findAncestorScrollableWidth;

  /// Informs this [RenderFillWidthIfConstrained] about the width of an ancestor [Scrollable],
  /// which may be used to set the width of the [child] `RenderObject`.
  set findAncestorScrollableWidth(double? Function() value) {
    _findAncestorScrollableWidth = value;
    markNeedsLayout();
  }

  double? Function() _findAncestorScrollableWidth;

  @override
  void performLayout() {
    BoxConstraints childConstraints = constraints;

    final ancestorViewportWidth = _findAncestorScrollableWidth();

    if (constraints.hasBoundedWidth) {
      // The available width is bounded, force the child to be as wide
      // as the available width.
      childConstraints = BoxConstraints(
        minWidth: constraints.maxWidth,
        maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );
    } else if (ancestorViewportWidth != null && ancestorViewportWidth < double.infinity) {
      // The available width is unbounded and we're inside of a Scrollable.
      // Make the child at least as wide as the Scrollable viewport.
      childConstraints = BoxConstraints(
        minWidth: ancestorViewportWidth,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );
    }

    child!.layout(childConstraints, parentUsesSize: true);
    size = child!.size;
  }
}
