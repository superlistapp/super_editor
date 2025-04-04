import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that takes up all available space, but unlike `SizedBox`, this widget
/// doesn't paint anything in debug mode.
///
/// Typically, when a Flutter app wants to take up space with a widget without
/// painting anything, a `SizedBox` used. However, when using Flutter debug
/// tools to see layout boundaries, every `SizedBox` paints itself with a gray
/// color. This is especially a problem when a `SizedBox` is displayed in an
/// overlay. To solve that problem, `EmptyBox` takes up space where a
/// `SizedBox` may have been used, but paints nothing in debug mode, allowing
/// users to see the content beneath the overlay.
class EmptyBox extends LeafRenderObjectWidget {
  const EmptyBox();

  @override
  RenderEmptyBox createRenderObject(BuildContext context) {
    return RenderEmptyBox();
  }
}

class RenderEmptyBox extends RenderProxyBox {}
