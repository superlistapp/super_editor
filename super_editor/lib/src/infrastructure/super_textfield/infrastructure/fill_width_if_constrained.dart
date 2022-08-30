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
      minWidth: _getViewportWidth(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFillWidthIfConstrained renderObject) {
    renderObject.minWidth = _getViewportWidth(context);
  }

  double? _getViewportWidth(BuildContext context) {
    final scrollable = Scrollable.of(context);
    if (scrollable == null) {
      return null;
    }

    final direction = scrollable.axisDirection;
    // We only need to specify the width if we are inside a horizontal scrollable,
    // because in this case we might have an infinity maxWidth.    
    if (direction == AxisDirection.up || direction == AxisDirection.down) {
      return null;
    }
    return (scrollable.context.findRenderObject() as RenderBox?)?.size.width;
  }
}

class RenderFillWidthIfConstrained extends RenderProxyBox {
  RenderFillWidthIfConstrained({
    double? minWidth,
  }) : _minWidth = minWidth;

  /// Sets the minimum width the child widget needs to be.
  /// 
  /// This is needed when this widget is inside a horizontal Scrollable.
  /// In this case, we might have an infinity maxWidth, so we need
  /// to specify the Scrollable's width to force the child to
  /// be at least this width.
  set minWidth(double? value) {
    _minWidth = value;
    markNeedsLayout();
  }

  double? _minWidth;

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
    } else if (_minWidth != null) {
      // If a minWidth is given, force the child to be at least this width.
      // This is the case when this widget is placed inside an Scrollable.
      childConstraints = BoxConstraints(
        minWidth: _minWidth!,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );
    }

    child!.layout(childConstraints, parentUsesSize: true);
    size = child!.size;
  }
}
