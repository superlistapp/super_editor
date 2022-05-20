import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';

// TODO: Write golden tests for scrolling minimap
//       (Matt - April, 2022) - I tried writing the tests but couldn't get the
//       minimap attached to the Scrollable. There might be some issue that's
//       specific to testing. The minimap is mostly functional in the example
//       app. I'm committing this code without tests because we need to move
//       forward with other things.

/// Repository of scrolling minimap statuses, used to coordinate between
/// a `Scrollable` and the minimap that represents that `Scrollable`.
///
/// A [ScrollingMinimap] displays a miniature representation of some
/// `Scrollable` widget. Since the [ScrollingMinimap] and the `Scrollable`
/// appear different places in the widget tree, [ScrollingMinimaps] acts
/// as a shared ancestor to connect a `Scrollable` to a [ScrollingMinimap].
class ScrollingMinimaps extends StatefulWidget {
  static ScrollingMinimapsRepository? of(BuildContext context) {
    return context.findAncestorStateOfType<_ScrollingMinimapsState>();
  }

  const ScrollingMinimaps({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  @override
  State<ScrollingMinimaps> createState() => _ScrollingMinimapsState();
}

class _ScrollingMinimapsState extends State<ScrollingMinimaps> with ScrollingMinimapsRepository {
  final _instrumentations = <String, ScrollableInstrumentation?>{};

  @override
  ScrollableInstrumentation? get(String id) => _instrumentations[id];

  @override
  void put(String id, ScrollableInstrumentation? instrumentation) => _instrumentations[id] = instrumentation;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

abstract class ScrollingMinimapsRepository {
  bool hasInstrumentation(String id) => get(id) != null;

  ScrollableInstrumentation? get(String id);

  void put(String id, ScrollableInstrumentation? instrumentation);
}

/// A miniature display of a `Scrollable` viewport and the boundary
/// of its content, which helps to diagnose scrolling bugs.
class ScrollingMinimap extends StatefulWidget {
  const ScrollingMinimap.fromRepository({
    Key? key,
    required this.minimapId,
    this.minimapScale = 0.1,
  })  : instrumentation = null,
        super(key: key);

  const ScrollingMinimap({
    Key? key,
    required this.instrumentation,
    this.minimapScale = 0.1,
  })  : minimapId = null,
        super(key: key);

  final String? minimapId;
  final ScrollableInstrumentation? instrumentation;
  final double minimapScale;

  @override
  State<ScrollingMinimap> createState() => _ScrollingMinimapState();
}

class _ScrollingMinimapState extends State<ScrollingMinimap> {
  ScrollableInstrumentation? get _instrumentation =>
      widget.instrumentation ?? ScrollingMinimaps.of(context)?.get(widget.minimapId!);

  RenderBox? get _viewportBox => _instrumentation?.viewport.value?.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    if (_instrumentation == null) {
      return const SizedBox();
    }

    final viewportBox = _viewportBox;
    if (viewportBox == null) {
      return const SizedBox();
    }
    if (!viewportBox.hasSize) {
      // The viewport hasn't laid out yet. Try again next frame.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return const SizedBox();
    }

    final scrollPosition = _instrumentation!.scrollPosition.value;
    if (scrollPosition == null) {
      return const SizedBox();
    }

    return MultiListenableBuilder(
      listenables: {
        _instrumentation!.scrollPosition,
        scrollPosition,
        _instrumentation!.startDragInViewport,
        _instrumentation!.endDragInViewport,
        _instrumentation!.startDragInContent,
        _instrumentation!.endDragInContent,
        _instrumentation!.scrollDirection,
        _instrumentation!.autoScrollEdge,
      },
      builder: (context) {
        return SizedBox.fromSize(
          size: viewportBox.size * widget.minimapScale,
          child: CustomPaint(
            painter: ScrollingMinimapPainter(
              minimapScale: widget.minimapScale,
              viewportSize: viewportBox.size,
              scrollOffset: scrollPosition.pixels,
              contentHeight: scrollPosition.hasContentDimensions ? scrollPosition.fullExtent : null,
              viewportStartDragOffset: _instrumentation!.startDragInViewport.value,
              viewportEndDragOffset: _instrumentation!.endDragInViewport.value,
              contentStartDragOffset: _instrumentation!.startDragInContent.value,
              contentEndDragOffset: _instrumentation!.endDragInContent.value,
              scrollingDirection: _instrumentation!.scrollDirection.value,
              autoScrollingEdge: _instrumentation!.autoScrollEdge.value,
            ),
          ),
        );
      },
    );
  }
}

extension on ScrollPosition {
  double get fullExtent => extentBefore + extentInside + extentAfter;
}

/// Connections to, and information about a scrolling experience that's
/// used for visual debugging.
class ScrollableInstrumentation {
  ScrollableInstrumentation()
      : viewport = ValueNotifier(null),
        scrollPosition = ValueNotifier(null),
        scrollDirection = ValueNotifier(null),
        startDragInViewport = ValueNotifier(null),
        endDragInViewport = ValueNotifier(null),
        startDragInContent = ValueNotifier(null),
        endDragInContent = ValueNotifier(null),
        autoScrollEdge = ValueNotifier(null);

  final ValueNotifier<BuildContext?> viewport;

  final ValueNotifier<ScrollPosition?> scrollPosition;

  final ValueNotifier<ScrollDirection?> scrollDirection;

  final ValueNotifier<Offset?> startDragInViewport;
  final ValueNotifier<Offset?> endDragInViewport;

  final ValueNotifier<Offset?> startDragInContent;
  final ValueNotifier<Offset?> endDragInContent;

  final ValueNotifier<ViewportEdge?> autoScrollEdge;
}

/// Paints a minimap for a `Scrollable`, showing a miniature viewport,
/// scroll offset, current scroll direction, etc.
@visibleForTesting
class ScrollingMinimapPainter extends CustomPainter {
  ScrollingMinimapPainter({
    required this.minimapScale,
    required this.viewportSize,
    this.contentHeight,
    required this.scrollOffset,
    this.viewportStartDragOffset,
    this.viewportEndDragOffset,
    this.contentStartDragOffset,
    this.contentEndDragOffset,
    this.autoScrollingEdge,
    this.scrollingDirection,
  });

  /// The scale (percent) of this minimap, as compared to the actual
  /// `Scrollable`.
  ///
  /// For example, a `minimapScale` of `0.1` displays a minimap that's
  /// 10% the size of the real content.
  final double minimapScale;

  /// The size of the `Scrollable`'s viewport.
  final Size viewportSize;

  /// The height of the content within the `Scrollable`,
  /// or `null` if the height is unknown, e.g., a sliver list
  /// doesn't know its content's height.
  final double? contentHeight;

  /// The current scroll offset, in pixels.
  final double scrollOffset;

  /// The offset, in the viewport, where the user started to drag,
  /// or `null` if you don't want to display user drag positions.
  final Offset? viewportStartDragOffset;

  /// The offset, in the viewport, where the user is currently
  /// dragging, or stopped dragging, or `null` if you don't want
  /// to display drag positions.
  final Offset? viewportEndDragOffset;

  /// The offset, in the content space, where the user started to drag,
  /// or `null` if you don't want to display user drag positions.
  final Offset? contentStartDragOffset;

  /// The offset, in the content space, where the user is currently
  /// dragging, or stopped dragging, or `null` if you don't want
  /// to display drag positions.
  final Offset? contentEndDragOffset;

  /// The edge of the viewport in the direction of an on-going
  /// auto-scroll behavior, or `null` if the viewport is not
  /// auto-scrolling.
  final ViewportEdge? autoScrollingEdge;

  /// The direction of an active scroll behavior, or `null` if
  /// the viewport is not scrolling.
  final ScrollDirection? scrollingDirection;

  final Paint _viewportPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _contentPaint = Paint()
    ..color = const Color(0xFFF0F0F0)
    ..style = PaintingStyle.fill;
  final Paint _scrollOffsetPaint = Paint()
    ..color = Colors.lightBlueAccent
    ..style = PaintingStyle.fill;
  final Paint _viewportDragPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.fill;
  final Paint _contentDragPaint = Paint()
    ..color = Colors.lightBlueAccent
    ..style = PaintingStyle.fill;
  final Paint _autoScrollEdgePaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.fill;
  final Paint _scrollingPaint = Paint()
    ..color = Colors.lightGreenAccent
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint a content rectangle, if we know how tall the content is.
    if (contentHeight != null) {
      canvas.drawRect(
        Rect.fromPoints(
          _scaleOffset(Offset(0.0, -scrollOffset)),
          _scaleOffset(Offset(viewportSize.width, contentHeight! - scrollOffset)),
        ),
        _contentPaint,
      );
    }

    // Paint a border that represents the viewport.
    canvas.drawRect(
      Rect.fromPoints(Offset.zero, _scaleOffset(viewportSize.bottomRight(Offset.zero))),
      _viewportPaint,
    );

    // Paint a line that shows the scroll offset, i.e., the top of the
    // content within the viewport.
    canvas.drawRect(
      Rect.fromPoints(
        _scaleOffset(Offset(0.0, -scrollOffset)),
        _scaleOffset(Offset(viewportSize.width, -scrollOffset)) + const Offset(0, 2),
      ),
      _scrollOffsetPaint,
    );

    // If the user is auto-scrolling, paint an indicator for the
    // auto-scroll region.
    if (autoScrollingEdge != null) {
      if (autoScrollingEdge == ViewportEdge.trailing) {
        // Paint indicator on bottom edge.
        canvas.drawRect(
          Rect.fromPoints(
            _scaleOffset(viewportSize.bottomLeft(Offset.zero)) - const Offset(0, 20),
            _scaleOffset(viewportSize.bottomRight(Offset.zero)),
          ),
          _autoScrollEdgePaint,
        );
      } else {
        // Paint indicator on top edge.
        canvas.drawRect(
          Rect.fromPoints(
            _scaleOffset(Offset.zero),
            _scaleOffset(viewportSize.topRight(Offset.zero)) + const Offset(0, 20),
          ),
          _autoScrollEdgePaint,
        );
      }
    }

    // If the content is actively scrolling, paint an indicator on
    // the scrolling edge.
    if (scrollingDirection != null) {
      if (scrollingDirection == ScrollDirection.forward) {
        // Paint indicator on bottom edge.
        canvas.drawRect(
          Rect.fromPoints(
            _scaleOffset(viewportSize.bottomLeft(Offset.zero)) - const Offset(0, 2),
            _scaleOffset(viewportSize.bottomRight(Offset.zero)),
          ),
          _scrollingPaint,
        );
      } else {
        // Paint indicator on top edge.
        canvas.drawRect(
          Rect.fromPoints(
            _scaleOffset(Offset.zero),
            _scaleOffset(viewportSize.topRight(Offset.zero)) + const Offset(0, 2),
          ),
          _scrollingPaint,
        );
      }
    }

    // Paint a representation of the user's drag behavior in the viewport.
    if (viewportStartDragOffset != null && viewportEndDragOffset != null) {
      canvas.drawCircle(_scaleOffset(viewportStartDragOffset!), 2, _viewportDragPaint);
      canvas.drawCircle(_scaleOffset(viewportEndDragOffset!), 2, _viewportDragPaint);
      canvas.drawLine(_scaleOffset(viewportStartDragOffset!), _scaleOffset(viewportEndDragOffset!), _viewportDragPaint);
    }

    // Paint a representation of the user's drag behavior in the content.
    if (contentStartDragOffset != null && contentEndDragOffset != null) {
      canvas.drawCircle(_scaleOffset(contentStartDragOffset!), 2, _contentDragPaint);
      canvas.drawCircle(_scaleOffset(contentEndDragOffset!), 2, _contentDragPaint);
      canvas.drawLine(_scaleOffset(contentStartDragOffset!), _scaleOffset(contentEndDragOffset!), _contentDragPaint);
    }
  }

  Offset _scaleOffset(Offset offset) => Offset(
        _scaleValue(offset.dx),
        _scaleValue(offset.dy),
      );

  double _scaleValue(double value) => value * minimapScale;

  @override
  bool shouldRepaint(ScrollingMinimapPainter oldDelegate) {
    return minimapScale != oldDelegate.minimapScale ||
        viewportSize != oldDelegate.viewportSize ||
        contentHeight != oldDelegate.contentHeight ||
        scrollOffset != oldDelegate.scrollOffset ||
        viewportStartDragOffset != oldDelegate.viewportStartDragOffset ||
        viewportEndDragOffset != oldDelegate.viewportEndDragOffset ||
        contentStartDragOffset != oldDelegate.contentStartDragOffset ||
        contentEndDragOffset != oldDelegate.contentEndDragOffset ||
        autoScrollingEdge != oldDelegate.autoScrollingEdge ||
        scrollingDirection != oldDelegate.scrollingDirection;
  }
}

enum ViewportEdge {
  leading,
  trailing,
}
