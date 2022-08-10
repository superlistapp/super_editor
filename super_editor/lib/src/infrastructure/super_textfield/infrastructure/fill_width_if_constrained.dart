import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Forces [child] to take up all available width when the
/// incoming width constraint is bounded, otherwise the [child]
/// is sized by its intrinsic width.
///
/// This widget is used to correctly align the text of a multiline
/// [SuperTextWithSelection] with a constrained width.
class FillWidthIfConstrained extends SingleChildRenderObjectWidget {
  const FillWidthIfConstrained({
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderFillWidthIfConstrained(
      viewportWidth: _getViewportWidth(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFillWidthIfConstrained renderObject) {
    renderObject.viewportWidth = _getViewportWidth(context);
  }

  double? _getViewportWidth(BuildContext context) {
    final scrollable = Scrollable.of(context);
    if (scrollable == null) {
      return null;
    }
    return (scrollable.context.findRenderObject() as RenderBox?)?.size.width;
  }
}

class RenderFillWidthIfConstrained extends RenderProxyBox {
  RenderFillWidthIfConstrained({
    double? viewportWidth,
  }) : _viewportWidth = viewportWidth;

  set viewportWidth(double? value) {
    _viewportWidth = value;
    markNeedsLayout();
  }

  double? _viewportWidth = 0;

  @override
  void performLayout() {
    BoxConstraints childConstraints = constraints;

    // If the available width is bounded, 
    // force the child to be as wide as the available width.
    if (constraints.hasBoundedWidth) {
      childConstraints = BoxConstraints(
        minWidth: constraints.maxWidth,
        minHeight: constraints.minHeight,
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight,
      );
    } else if (_viewportWidth != null) {
      // If a viewport width is given, force the child to be at least this width.
      // This is the case when this widget is placed inside an Scrollable.
      childConstraints = BoxConstraints(
        minWidth: _viewportWidth!,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );
    }

    child!.layout(childConstraints, parentUsesSize: true);
    size = child!.size;
  }
}
