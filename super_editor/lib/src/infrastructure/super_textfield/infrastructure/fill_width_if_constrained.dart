import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Forces [child] to take up all available width when the
/// incoming width constraint is bounded, otherwise the [child]
/// is sized by its intrinsic width.
///
/// If there is an existing widget that does this, get rid of this
/// widget and use the standard widget.
class FillWidthIfConstrained extends SingleChildRenderObjectWidget {
  const FillWidthIfConstrained({
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderFillWidthIfConstrained();
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    renderObject.markNeedsLayout();
  }
}

class _RenderFillWidthIfConstrained extends RenderProxyBox {
  @override
  void performLayout() {
    BoxConstraints childConstraints = constraints;

    // If the available width is bounded and the child did not
    // take all available width, force the child to be as wide
    // as the available width.
    if (constraints.hasBoundedWidth) {
      childConstraints = BoxConstraints(
        minWidth: constraints.maxWidth,
        minHeight: constraints.minHeight,
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight,
      );
    }

    child!.layout(childConstraints, parentUsesSize: true);
    size = child!.size;
  }  
}
