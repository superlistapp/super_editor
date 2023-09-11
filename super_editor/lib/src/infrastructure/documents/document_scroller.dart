import 'package:flutter/widgets.dart';

/// Scrolling status and controls for a document experience.
///
/// Depending on the surrounding widget tree, a [DocumentScroller] might be attached
/// to a descendant `Scrollable`, which was added by the document experience widget
/// (like `SuperEditor` or `SuperReader`). Or, a [DocumentScroller] might be attached
/// to an ancestor `Scrollable`, if the document experience chooses to use an
/// ancestor `Scrollable`.
class DocumentScroller {
  /// The height of a vertically scrolling viewport, or the width of a horizontally
  /// scrolling viewport.
  double get viewportDimension => _scrollPosition!.viewportDimension;

  /// The smallest possible scrolling offset, which is usually zero.
  double get minScrollExtent => _scrollPosition!.minScrollExtent;

  /// The maximum possible scrolling offset, at which point the end of the scrolling
  /// content is visible in the viewport.
  double get maxScrollExtent => _scrollPosition!.maxScrollExtent;

  /// The current scroll offset in the viewport, which is represented by the number
  /// of pixels between the top-left corner of the viewport, and the top-left corner
  /// of the content that sits inside the viewport.
  double get scrollOffset => _scrollPosition!.pixels;

  /// Immediately moves the [scrollOffset] to [newScrollOffset].
  void jumpTo(double newScrollOffset) {
    _scrollPosition!.jumpTo(newScrollOffset);
  }

  /// Immediately moves the [scrollOffset] by [delta] pixels.
  void jumpBy(double delta) {
    _scrollPosition!.jumpTo(_scrollPosition!.pixels + delta);
  }

  /// Animates [scrollOffset] from its current offset to [to], over the given [duration]
  /// of time, following the given animation [curve].
  void animateTo(
    double to, {
    required Duration duration,
    Curve curve = Curves.easeInOut,
  }) {
    _scrollPosition!.animateTo(to, duration: duration, curve: curve);
  }

  ScrollPosition? _scrollPosition;

  void attach(ScrollPosition scrollPosition) {
    _scrollPosition = scrollPosition;
  }

  void detach() {
    _scrollPosition = null;
  }
}
