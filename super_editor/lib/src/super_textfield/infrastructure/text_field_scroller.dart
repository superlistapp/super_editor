import 'package:flutter/widgets.dart';

/// Scrolling status and controls within a text field.
class TextFieldScroller {
  /// The height of a vertically scrolling viewport, or the width of a horizontally
  /// scrolling viewport.
  double get viewportDimension => _scrollController!.position.viewportDimension;

  /// The smallest possible scrolling offset, which is usually zero.
  double get minScrollExtent => _scrollController!.position.minScrollExtent;

  /// The maximum possible scrolling offset, at which point the end of the scrolling
  /// content is visible in the viewport.
  double get maxScrollExtent => _scrollController!.position.maxScrollExtent;

  /// The current scroll offset in the viewport, which is represented by the number
  /// of pixels between the top-left corner of the viewport, and the top-left corner
  /// of the content that sits inside the viewport.
  double get scrollOffset => _scrollController!.offset;

  /// Immediately moves the [scrollOffset] to [newScrollOffset].
  void jumpTo(double newScrollOffset) {
    _scrollController!.jumpTo(newScrollOffset);
  }

  /// Immediately moves the [scrollOffset] by [delta] pixels.
  void jumpBy(double delta) {
    _scrollController!.jumpTo(_scrollController!.offset + delta);
  }

  /// Animates [scrollOffset] from its current offset to [to], over the given [duration]
  /// of time, following the given animation [curve].
  void animateTo(
    double to, {
    required Duration duration,
    Curve curve = Curves.easeInOut,
  }) {
    _scrollController!.animateTo(to, duration: duration, curve: curve);
  }

  ScrollController? _scrollController;

  void attach(ScrollController scrollController) {
    _scrollController = scrollController;
  }

  void detach() {
    _scrollController = null;
  }
}
