import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Forces [child] to take up all available width when the
/// incoming width constraint is bounded, otherwise the [child]
/// is sized by its intrinsic width.
///
/// If there is an existing widget that does this, get rid of this
/// widget and use the standard widget.
class FillWidthIfConstrained extends SingleChildRenderObjectWidget {
  const FillWidthIfConstrained({
    Key? key,
    required Widget child,
  }) : super(key: key, child: child);

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
    size = computeDryLayout(constraints);

    if (child != null) {
      child!.layout(BoxConstraints.tight(size));
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) {
      return Size.zero;
    }

    Size size = child!.computeDryLayout(constraints);

    // If the available width is bounded and the child did not
    // take all available width, force the child to be as wide
    // as the available width.
    if (constraints.hasBoundedWidth && size.width < constraints.maxWidth) {
      size = Size(constraints.maxWidth, size.height);
    }

    return size;
  }
}
