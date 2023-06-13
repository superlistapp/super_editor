import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Platform independent tools for touch gesture interaction with a
/// document, such as dragging to scroll a document, and dragging
/// handles to expand a selection.
///
/// See also:
///  * document_gestures_touch_ios for iOS-specific touch gesture tools.
///  * document_gestures_touch_android for Android-specific touch gesture tools.
///  * super_editor's mouse gesture support.

/// Displays the given [child] document within a `Scrollable`, if and only
/// if there is no ancestor `Scrollable` in the widget tree.
///
/// The given [scrollController] is attached to inner `Scrollable`, when
/// a `Scrollable` is included in this widget tree.
///
/// The [documentLayerLink] is given a `CompositedTransformTarget` that
/// surrounds the document.
class ScrollableDocument extends StatelessWidget {
  const ScrollableDocument({
    Key? key,
    this.scrollController,
    this.disableDragScrolling = false,
    required this.documentLayerLink,
    required this.child,
  }) : super(key: key);

  /// `ScrollController` that's attached to the `Scrollable` in this
  /// widget, if a `Scrollable` is added.
  ///
  /// A `Scrollable` is added if, and only if, there is no ancestor
  /// `Scrollable` in the widget tree.
  final ScrollController? scrollController;

  /// Whether to disable drag-based scrolling, for cases in which drag
  /// behaviors are handled elsewhere, e.g., the user drags a handle that's
  /// displayed within the document.
  final bool disableDragScrolling;

  /// `LayerLink` that will be aligned to the top-left of the document layout.
  final LayerLink documentLayerLink;

  /// The document layout widget.
  final Widget child;

  ScrollableState? _findAncestorScrollable(BuildContext context) {
    final ancestorScrollable = Scrollable.maybeOf(context);
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

  @override
  Widget build(BuildContext context) {
    final ancestorScrollable = _findAncestorScrollable(context);
    final ancestorScrollPosition = ancestorScrollable?.position;
    final addScrollView = ancestorScrollPosition == null;

    return addScrollView
        ? SizedBox(
            height: double.infinity,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              }),
              child: SingleChildScrollView(
                physics: disableDragScrolling ? const NeverScrollableScrollPhysics() : null,
                controller: scrollController,
                child: _buildDocument(),
              ),
            ),
          )
        : _buildDocument();
  }

  Widget _buildDocument() {
    return Center(
      child: CompositedTransformTarget(
        link: documentLayerLink,
        child: child,
      ),
    );
  }
}
