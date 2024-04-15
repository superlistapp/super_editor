import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/flutter/geometry.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

final _log = scrollingTextFieldLog;

/// A scrollable that positions its [child] based on text metrics.
///
/// The [child] must contain a [SuperText] in its tree,
/// [textKey] must refer to that [SuperText], and the
/// dimensions of the [child] subtree should match the dimensions
/// of the [SuperText] so that there are no surprises
/// when the scroll offset is configured based on where a given
/// character appears in the [child] layout.
///
/// [TextScrollView] defers to [textScrollController] for its
/// scroll offset. [TextScrollView] sets itself as a
/// [TextScrollControllerDelegate] on the [textScrollController].
/// This relationship allows the [textScrollController] to make
/// decisions about the scroll offset based on layout information
/// returned from this [TextScrollView].
class TextScrollView extends StatefulWidget {
  const TextScrollView({
    Key? key,
    required this.textScrollController,
    required this.textKey,
    required this.textEditingController,
    this.minLines,
    this.maxLines,
    this.lineHeight,
    this.perLineAutoScrollDuration = Duration.zero,
    this.showDebugPaint = false,
    this.textAlign = TextAlign.left,
    this.padding,
    required this.child,
  }) : super(key: key);

  /// Controller that sets the scroll offset and orchestrates
  /// auto-scrolling behavior.
  final TextScrollController textScrollController;

  /// [GlobalKey] that references the widget that contains the scrolling text.
  final GlobalKey<ProseTextState> textKey;

  /// Controller that owns the text content and text selection for
  /// the [SuperSelectableText] within the [child] subtree.
  final AttributedTextEditingController textEditingController;

  /// The minimum height of this text scroll view, represented as a
  /// line count.
  ///
  /// If [minLines] is non-null and greater than `1`, [lineHeight]
  /// must also be provided because there is no guarantee that all
  /// lines of text have the same height.
  ///
  /// See also:
  ///
  ///  * [maxLines]
  ///  * [lineHeight]
  final int? minLines;

  /// The maximum height of this text scroll view, represented as a
  /// line count.
  ///
  /// If [maxLines] is non-null and greater than `1`, [lineHeight]
  /// must also be provided because there is no guarantee that all
  /// lines of text have the same height.
  ///
  /// See also:
  ///
  ///  * [minLines]
  ///  * [lineHeight]
  final int? maxLines;

  /// The height of a single line of text in this text scroll view, used
  /// with [minLines] and [maxLines] to size the text field.
  ///
  /// If a [lineHeight] is provided, the [TextScrollView] is sized as a
  /// multiple of that [lineHeight]. If no [lineHeight] is provided, the
  /// [TextScrollView] is sized as a multiple of the line-height of the
  /// first line of text.
  final double? lineHeight;

  /// The time it takes to scroll to the next line, when auto-scrolling.
  ///
  /// A value of [Duration.zero] jumps immediately to the next line.
  final Duration perLineAutoScrollDuration;

  /// Whether to paint debug guides.
  final bool showDebugPaint;

  /// The text alignment within the scrollview.
  final TextAlign textAlign;

  /// Padding placed around the text content of this text field, but within the
  /// scrollable viewport.
  final EdgeInsets? padding;

  /// The child widget.
  final Widget child;

  @override
  State createState() => _TextScrollViewState();
}

class _TextScrollViewState extends State<TextScrollView>
    with SingleTickerProviderStateMixin
    implements TextScrollControllerDelegate {
  final _singleLineFieldAutoScrollGap = 24.0;
  final _mulitlineFieldAutoScrollGap = 20.0;

  final _textFieldViewportKey = GlobalKey();

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    widget.textScrollController
      ..delegate = this
      ..addListener(_onTextScrollChange);

    widget.textEditingController.addListener(_onTextOrSelectionChanged);
  }

  @override
  void didUpdateWidget(TextScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textScrollController != oldWidget.textScrollController) {
      oldWidget.textScrollController
        ..delegate = null
        ..removeListener(_onTextScrollChange);

      widget.textScrollController
        ..delegate = this
        ..addListener(_onTextScrollChange);
    }

    if (widget.textEditingController != oldWidget.textEditingController) {
      oldWidget.textEditingController.removeListener(_onTextOrSelectionChanged);
      widget.textEditingController.addListener(_onTextOrSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.textScrollController
      ..delegate = null
      ..removeListener(_onTextScrollChange);

    widget.textEditingController.removeListener(_onTextOrSelectionChanged);

    super.dispose();
  }

  @override
  double? get viewportWidth {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return null;
    }

    return renderBox.size.width;
  }

  @override
  double? get viewportHeight {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return null;
    }

    return renderBox.size.height;
  }

  @override
  Offset get textLayoutOffsetInViewport {
    final viewportBox = context.findRenderObject() as RenderBox;
    final textContentBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
    final textOffsetInViewport = textContentBox.localToGlobal(Offset.zero, ancestor: viewportBox);

    if (isMultiline) {
      return textOffsetInViewport.translate(0, _scrollController.offset);
    } else {
      return textOffsetInViewport.translate(_scrollController.offset, 0);
    }
  }

  @override
  bool get isMultiline => widget.maxLines == null || widget.maxLines! > 1;

  bool get isBounded => widget.maxLines != null;

  @override
  double get startScrollOffset => 0.0;

  @override
  double get endScrollOffset {
    final viewportWidth = this.viewportWidth;
    final viewportHeight = this.viewportHeight;
    if (viewportWidth == null || viewportHeight == null) {
      return 0;
    }

    final lastCharacterPosition = TextPosition(offset: widget.textEditingController.text.length - 1);
    return isMultiline
        ? (_textLayout.getCharacterBox(lastCharacterPosition)?.bottom ?? _textLayout.estimatedLineHeight) -
            viewportHeight +
            (widget.padding?.vertical ?? 0.0)
        : _scrollController.position.maxScrollExtent;
  }

  @override
  bool isTextPositionVisible(TextPosition position) {
    if (isMultiline) {
      final viewportHeight = this.viewportHeight;
      if (viewportHeight == null) {
        return false;
      }

      final characterBox = _textLayout.getCharacterBox(position);
      final scrolledCharacterTop = (characterBox?.top ?? 0.0) - _scrollController.offset;
      final scrolledCharacterBottom =
          (characterBox?.bottom ?? _textLayout.estimatedLineHeight) - _scrollController.offset;
      // Round the top/bottom values to avoid false negatives due to floating point accuracy.
      return scrolledCharacterTop.round() >= 0 && scrolledCharacterBottom.round() <= viewportHeight;
    } else {
      final viewportWidth = this.viewportWidth;
      if (viewportWidth == null) {
        return false;
      }

      // Find where the text sits from the edges of the viewport. This calculation implicitly
      // includes any padding around the content, as well as the current scroll offset.
      final viewportBox = context.findRenderObject() as RenderBox;
      final textContentBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
      final textOffsetInViewport = textContentBox.localToGlobal(Offset.zero, ancestor: viewportBox);

      // Find the offset of the text position within the viewport.
      final offsetInViewport = textOffsetInViewport + _textLayout.getOffsetAtPosition(position);

      // Round the top/bottom values to avoid false negatives due to floating point accuracy.
      return offsetInViewport.dx.round() >= 0 && offsetInViewport.dx.round() <= viewportWidth;
    }
  }

  @override
  bool isInAutoScrollToStartRegion(Offset offsetInViewport) {
    return calculateDistanceBeyondStartingAutoScrollBoundary(offsetInViewport) > 0;
  }

  @override
  double calculateDistanceBeyondStartingAutoScrollBoundary(Offset offsetInViewport) {
    if (isMultiline) {
      return max(_mulitlineFieldAutoScrollGap - offsetInViewport.dy, 0).abs().toDouble();
    } else {
      return max(_singleLineFieldAutoScrollGap - offsetInViewport.dx, 0).abs().toDouble();
    }
  }

  @override
  bool isInAutoScrollToEndRegion(Offset offsetInViewport) {
    return calculateDistanceBeyondEndingAutoScrollBoundary(offsetInViewport) > 0;
  }

  @override
  double calculateDistanceBeyondEndingAutoScrollBoundary(Offset offsetInViewport) {
    if (isMultiline) {
      final viewportHeight = this.viewportHeight;
      if (viewportHeight == null) {
        return 0;
      }

      return max(offsetInViewport.dy - (viewportHeight - _mulitlineFieldAutoScrollGap), 0);
    } else {
      final viewportWidth = this.viewportWidth;
      if (viewportWidth == null) {
        return 0;
      }

      return max(offsetInViewport.dx - (viewportWidth - _singleLineFieldAutoScrollGap), 0);
    }
  }

  @override
  Rect getViewportCharacterRectAtPosition(TextPosition position) {
    final viewportBox = context.findRenderObject() as RenderBox;
    final textBox = widget.textKey.currentContext!.findRenderObject() as RenderBox;
    final textOffsetInViewport = textBox.localToGlobal(Offset.zero, ancestor: viewportBox);

    final characterBoxInTextLayout =
        _textLayout.getCharacterBox(position)?.toRect() ?? Rect.fromLTRB(0, 0, 0, _textLayout.estimatedLineHeight);

    // The padding is applied inside of the scrollable area,
    // so we need to adjust the rect to account for it.
    return characterBoxInTextLayout.translate(textOffsetInViewport.dx, textOffsetInViewport.dy);
  }

  @override
  double getHorizontalOffsetForStartOfCharacterLeftOfViewport() {
    // Note: we look for an offset that is slightly further down than zero
    // to avoid any issues with the layout system differentiating between lines.
    final textPositionAtLeftEnd = _textLayout.getPositionNearestToOffset(Offset(_scrollController.offset, 5));
    final nextPosition = textPositionAtLeftEnd.offset <= 0
        ? textPositionAtLeftEnd
        : TextPosition(offset: textPositionAtLeftEnd.offset - 1);
    return _textLayout.getOffsetAtPosition(nextPosition).dx;
  }

  @override
  double getHorizontalOffsetForEndOfCharacterRightOfViewport() {
    final viewportWidth = (context.findRenderObject() as RenderBox).size.width;
    // Note: we look for an offset that is slightly further down than zero
    // to avoid any issues with the layout system differentiating between lines.
    final textOffsetInViewport = textLayoutOffsetInViewport;
    final textPositionAtRightEnd = _textLayout.getPositionNearestToOffset(
      Offset(viewportWidth + _scrollController.offset + textOffsetInViewport.dx, 5),
    );
    final nextPosition = textPositionAtRightEnd.offset >= widget.textEditingController.text.text.length - 1
        ? textPositionAtRightEnd
        : TextPosition(offset: textPositionAtRightEnd.offset + 1);
    return _textLayout.getOffsetAtPosition(nextPosition).dx + textOffsetInViewport.dx;
  }

  @override
  double getVerticalOffsetForTopOfLineAboveViewport() {
    final topOfFirstLine = _scrollController.offset;
    // Note: we nudge the vertical offset up a few pixels to see if we
    // find a text position in the line above.
    final textPositionOneLineUp = _textLayout.getPositionNearestToOffset(Offset(0, topOfFirstLine - 5));
    return _textLayout.getOffsetAtPosition(textPositionOneLineUp).dy;
  }

  @override
  double getVerticalOffsetForBottomOfLineBelowViewport() {
    if (viewportHeight == null) {
      _log.warning('Tried to calculate line below viewport but viewportHeight is null');
      return 0.0;
    }

    final bottomOfLastLine = viewportHeight! + _scrollController.offset;
    // Note: we nudge the vertical offset down a few pixels to see if we
    // find a text position in the line below.
    final textPositionOneLineDown = _textLayout.getPositionNearestToOffset(Offset(0, bottomOfLastLine + 5));
    final bottomOfCharacter =
        (_textLayout.getCharacterBox(textPositionOneLineDown)?.bottom ?? _textLayout.estimatedLineHeight);
    return bottomOfCharacter;
  }

  void _onTextScrollChange() {
    if (widget.perLineAutoScrollDuration == Duration.zero || !isMultiline) {
      _scrollController.jumpTo(widget.textScrollController.scrollOffset);
    } else {
      _scrollController.animateTo(
        widget.textScrollController.scrollOffset,
        duration: widget.perLineAutoScrollDuration,
        curve: Curves.easeOut,
      );
    }
  }

  /// Returns the [ProseTextLayout] that lays out and renders the
  /// text in this text field.
  ProseTextLayout get _textLayout => widget.textKey.currentState!.textLayout;

  void _onTextOrSelectionChanged() {
    // After the text changes, the user might have entered new lines.
    // Schedule a rebuild so our size is updated.
    scheduleBuildAfterBuild();
  }

  @override
  Widget build(BuildContext context) {
    return _TextLinesLimiter(
      textKey: widget.textKey,
      scrollController: _scrollController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      lineHeight: widget.lineHeight,
      padding: widget.padding,
      child: Stack(
        children: [
          _buildScrollView(
            child: widget.child,
          ),
          if (widget.showDebugPaint) ..._buildDebugScrollRegions(),
        ],
      ),
    );
  }

  Alignment _getAlignment() {
    switch (widget.textAlign) {
      case TextAlign.left:
      case TextAlign.justify:
        return Alignment.topLeft;
      case TextAlign.right:
        return Alignment.topRight;
      case TextAlign.center:
        return Alignment.topCenter;
      case TextAlign.start:
        return Directionality.of(context) == TextDirection.ltr ? Alignment.topLeft : Alignment.topRight;
      case TextAlign.end:
        return Directionality.of(context) == TextDirection.ltr ? Alignment.topRight : Alignment.topLeft;
    }
  }

  Widget _buildScrollView({
    required Widget child,
  }) {
    return Align(
      alignment: _getAlignment(),
      child: SingleChildScrollView(
        key: _textFieldViewportKey,
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: isMultiline ? Axis.vertical : Axis.horizontal,
        child: Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: widget.child,
        ),
      ),
    );
  }

  /// Paints guides where the auto-scroll regions sit.
  List<Widget> _buildDebugScrollRegions() {
    if (isMultiline) {
      return [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: Container(
              height: _mulitlineFieldAutoScrollGap,
              color: Colors.purpleAccent.withOpacity(0.5),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: _mulitlineFieldAutoScrollGap,
              color: Colors.purpleAccent.withOpacity(0.5),
            ),
          ),
        ),
      ];
    } else {
      return [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: _singleLineFieldAutoScrollGap,
            color: Colors.purpleAccent.withOpacity(0.5),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: _singleLineFieldAutoScrollGap,
            color: Colors.purpleAccent.withOpacity(0.5),
          ),
        ),
      ];
    }
  }
}

enum TextFieldSizePolicy {
  singleLine,
  multiLineBounded,
  multiLineUnbounded,
}

class TextScrollController with ChangeNotifier {
  static const _autoScrollTimePerLine = Duration(milliseconds: 500);
  static const _autoScrollTimePerCharacter = Duration(milliseconds: 50);

  TextScrollController({
    required AttributedTextEditingController textController,
    required TickerProvider tickerProvider,
  }) : _textController = textController {
    _ticker = tickerProvider.createTicker(_autoScrollTick);
  }

  final AttributedTextEditingController _textController;

  TextScrollControllerDelegate? _delegate;

  bool get isDelegateAttached => _delegate != null;

  set delegate(TextScrollControllerDelegate? delegate) {
    if (delegate != _delegate) {
      if (_delegate != null) {
        stopScrolling();
      }

      _delegate = delegate;
    }
  }

  late Ticker _ticker;

  // FIXME: This scroll offset creates an ambiguous source of truth as compared to
  //        the actual scroll offset, which is held within a ScrollController. Either
  //        this controller should treat the ScrollController offset like it's own, or
  //        a careful two-way sync'ing should be setup between this controller and it's
  //        associated ScrollController.
  double _scrollOffset = 0.0;
  double get scrollOffset => _scrollOffset;
  void _setScrollOffset(double newValue) {
    if (newValue == _scrollOffset) {
      return;
    }

    _scrollOffset = newValue;
    notifyListeners();
  }

  _AutoScrollDirection? _autoScrollDirection;

  Offset? _userInteractionOffsetInViewport;
  Duration _timeOfPreviousAutoScroll = Duration.zero;
  Duration _timeOfNextAutoScroll = Duration.zero;

  double get startScrollOffset => _delegate!.startScrollOffset;

  double get endScrollOffset => _delegate!.endScrollOffset;

  bool isTextPositionVisible(TextPosition position) => _delegate!.isTextPositionVisible(position);

  void jumpToStart() {
    if (_delegate == null) {
      _log.warning("Can't calculate start scroll offset. The auto-scroll delegate is null.");
      return;
    }

    _log.fine('Jumping to start of scroll region');

    final startScrollOffset = _delegate!.startScrollOffset;
    if (_scrollOffset != startScrollOffset) {
      _log.finer(' - updated _scrollOffset to $_scrollOffset');
      _setScrollOffset(startScrollOffset);
    }
  }

  void jumpToEnd() {
    if (_delegate == null) {
      _log.warning("Can't calculate end scroll offset. The auto-scroll delegate is null.");
      return;
    }

    _log.fine('Jumping to end of scroll region');

    final endScrollOffset = _delegate!.endScrollOffset;
    if (_scrollOffset != endScrollOffset) {
      _log.finer(' - updated _scrollOffset to $_scrollOffset');
      _setScrollOffset(endScrollOffset);
    }
  }

  void updateAutoScrollingForTouchOffset({
    required Offset userInteractionOffsetInViewport,
  }) {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll. The auto-scroll delegate is null.");
      return;
    }

    _userInteractionOffsetInViewport = userInteractionOffsetInViewport;
    if (_delegate!.isInAutoScrollToStartRegion(userInteractionOffsetInViewport)) {
      startScrollingToStart();
    } else if (_delegate!.isInAutoScrollToEndRegion(userInteractionOffsetInViewport)) {
      startScrollingToEnd();
    } else {
      stopScrolling();
    }
  }

  /// Starts auto-scrolling to the start of the text.
  ///
  /// If already auto-scrolling to the start, does nothing.
  ///
  /// If auto-scrolling to the end, that auto-scroll is
  /// cancelled and replaced by auto-scrolling to the start.
  void startScrollingToStart() {
    if (_autoScrollDirection == _AutoScrollDirection.start) {
      // Already scrolling to start. Return.
      return;
    }

    stopScrolling();

    _log.fine('Auto-scrolling to start');
    _autoScrollDirection = _AutoScrollDirection.start;
    _timeOfPreviousAutoScroll = Duration.zero;
    _autoScrollTick(Duration.zero);
    _ticker.start();
  }

  /// Starts auto-scrolling to the end of the text.
  ///
  /// If already auto-scrolling to the end, does nothing.
  ///
  /// If auto-scrolling to the start, that auto-scroll is
  /// cancelled and replaced by auto-scrolling to the end.
  void startScrollingToEnd() {
    if (_autoScrollDirection == _AutoScrollDirection.end) {
      // Already scrolling to end. Return.
      return;
    }

    stopScrolling();

    _log.fine('Auto-scrolling to end');
    _autoScrollDirection = _AutoScrollDirection.end;
    _timeOfPreviousAutoScroll = Duration.zero;
    _autoScrollTick(Duration.zero);
    _ticker.start();
  }

  /// Stops any auto-scrolling that is currently in progress.
  void stopScrolling() {
    if (!_ticker.isTicking) {
      return;
    }
    _log.fine('stopping auto-scroll');
    _autoScrollDirection = null;
    _timeOfNextAutoScroll = Duration.zero;
    _ticker.stop();
  }

  /// Scrolls one line up/down if enough time has passed since
  /// the previous auto-scroll movement.
  ///
  /// If a line is scrolled, resets the time until the next
  /// auto scroll movement.
  void _autoScrollTick(Duration elapsedTime) {
    if (_delegate == null) {
      _log.warning('auto-scroll delegate was null in _autoScrollTick()');
      stopScrolling();
      return;
    }

    if (_autoScrollDirection == null) {
      _log.warning('_autoScrollDirection was null in _autoScrollTick()');
      stopScrolling();
      return;
    }

    if (elapsedTime < _timeOfNextAutoScroll) {
      _log.finest("Not enough time passed to do auto-scroll.");
      // Not enough time has passed to jump further in the scroll direction.
      return;
    }

    _log.finer('auto-scroll tick, is multiline: ${_delegate!.isMultiline}, direction: $_autoScrollDirection');
    final dt = elapsedTime - _timeOfPreviousAutoScroll;
    _timeOfPreviousAutoScroll = elapsedTime;
    final offsetBeforeScroll = _scrollOffset;

    if (_delegate!.isMultiline) {
      if (_autoScrollDirection == _AutoScrollDirection.start) {
        _autoScrollOneLineUp();
      } else {
        _autoScrollOneLineDown();
      }
    } else {
      if (_autoScrollDirection == _AutoScrollDirection.start) {
        _autoScrollToTheLeft(
          dt,
          _delegate!.calculateDistanceBeyondStartingAutoScrollBoundary(_userInteractionOffsetInViewport!),
        );
      } else {
        _autoScrollToTheRight(
          dt,
          _delegate!.calculateDistanceBeyondEndingAutoScrollBoundary(_userInteractionOffsetInViewport!),
        );
      }
    }

    if (_scrollOffset == offsetBeforeScroll) {
      _log.fine('Offset did not change during tick. Stopping scroll.');
      // We've reached the desired start or end. Stop auto-scrolling.
      stopScrolling();
    }
  }

  void _autoScrollToTheLeft(Duration dt, double distanceFromAutoScrollBoundary) {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll left. The scroll delegate is null.");
      return;
    }

    if (_scrollOffset <= 0) {
      // There's nowhere left to scroll.
      _log.fine("Can't auto-scroll left because we're already at the end.");
      return;
    }

    _log.finer('_autoScrollOneCharacterLeft. Scroll offset before: $scrollOffset');
    _timeOfNextAutoScroll += _autoScrollTimePerCharacter;
    _setScrollOffset(max(
      _scrollOffset - _calculateAutoScrollDistance(dt, distanceFromAutoScrollBoundary),
      0,
    ));
    _log.finer(' - _scrollOffset after: $_scrollOffset');
  }

  void _autoScrollToTheRight(Duration dt, double distanceFromAutoScrollBoundary) {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll right. The scroll delegate is null.");
      return;
    }

    final viewportWidth = _delegate!.viewportWidth;
    if (viewportWidth == null) {
      _log.warning("Can't auto-scroll right. Viewport width is null");
      return;
    }

    if (_scrollOffset >= _delegate!.endScrollOffset) {
      // There's nowhere left to scroll.
      _log.fine("Can't auto-scroll right because we're already at the end.");
      return;
    }

    _log.finer('Scrolling right - current scroll offset: $_scrollOffset, max scroll: ${_delegate?.endScrollOffset}');
    _timeOfNextAutoScroll += _autoScrollTimePerCharacter;
    final scrollDistance = _calculateAutoScrollDistance(dt, distanceFromAutoScrollBoundary);
    _setScrollOffset(min(
      _scrollOffset + scrollDistance,
      _delegate!.endScrollOffset,
    ));
    _log.finer(' - _scrollOffset after: $_scrollOffset');

    notifyListeners();
  }

  /// Calculates the distance that the field should auto-scroll in a single frame,
  /// based on the amount of time that has passed since the last auto-scroll, and
  /// given how far beyond the auto-scroll boundary the user has dragged.
  ///
  /// The larger [dt], the larger the auto-scroll.
  ///
  /// The larger [distanceFromAutoScrollBound], the larger the auto-scroll, capped at
  /// a sane value.
  double _calculateAutoScrollDistance(Duration dt, double distanceFromAutoScrollBound) {
    const minPixelsPerSecond = 50;
    const maxPixelsPerSecond = 1500;
    const maxDistanceFromScrollBound = 75;

    final speedPercent = min(distanceFromAutoScrollBound, maxDistanceFromScrollBound) / maxDistanceFromScrollBound;
    // Apply an exponential curve to the percent so that the user has more control over
    // slower speeds, but is also able to drag far away and achieve high speeds.
    final exponentialPercent = Curves.easeIn.transform(speedPercent);
    final speed = lerpDouble(minPixelsPerSecond, maxPixelsPerSecond, exponentialPercent)!;
    return speed * (dt.inMilliseconds / 1000);
  }

  /// Updates the scroll offset so that a new line of text is
  /// visible at the top of the viewport, if a line is available.
  void _autoScrollOneLineUp() {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll up. The scroll delegate is null.");
      return;
    }

    final viewportHeight = _delegate!.viewportHeight;
    if (viewportHeight == null) {
      _log.warning("Can't auto-scroll up. The viewport height is null");
      return;
    }

    final verticalOffsetForTopOfLineAboveViewport = _delegate!.getVerticalOffsetForTopOfLineAboveViewport();
    if (verticalOffsetForTopOfLineAboveViewport == null) {
      _log.warning("Can't auto-scroll up. Couldn't calculate the offset for the line above the viewport");
      return;
    }

    _log.fine('Auto-scrolling one line up');

    _log.finer('Old offset: $_scrollOffset.');
    _log.finer('Viewport height: $viewportHeight');
    _log.finer('Vertical offset for top of line above viewport: $verticalOffsetForTopOfLineAboveViewport');
    _timeOfNextAutoScroll += _autoScrollTimePerLine;
    _setScrollOffset(verticalOffsetForTopOfLineAboveViewport);
    _log.fine('New scroll offset: $_scrollOffset, time of next scroll: $_timeOfNextAutoScroll');
  }

  /// Updates the scroll offset so that a new line of text is
  /// visible at the bottom of the viewport, if a line is available.
  void _autoScrollOneLineDown() {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll down. The scroll delegate is null.");
      return;
    }

    final viewportHeight = _delegate!.viewportHeight;
    if (viewportHeight == null) {
      _log.warning("Can't auto-scroll down. The viewport height is null");
      return;
    }

    final verticalOffsetForBottomOfLineBelowViewport = _delegate!.getVerticalOffsetForBottomOfLineBelowViewport();
    if (verticalOffsetForBottomOfLineBelowViewport == null) {
      _log.warning("Can't auto-scroll down. Couldn't calculate the offset for the line below the viewport");
      return;
    }

    _log.fine('Auto-scrolling one line down');

    _log.finer('Old offset: $_scrollOffset.');
    _log.finer('Viewport height: ${_delegate!.viewportHeight}');
    _log.finer('Vertical offset for bottom of line below viewport: $verticalOffsetForBottomOfLineBelowViewport');
    _timeOfNextAutoScroll += _autoScrollTimePerLine;
    _setScrollOffset(verticalOffsetForBottomOfLineBelowViewport - viewportHeight);
    _log.fine('New scroll offset: $_scrollOffset, time of next scroll: $_timeOfNextAutoScroll');
  }

  /// Updates the scroll offset so that the current selection base
  /// position is visible in the viewport.
  ///
  /// Does nothing if the base position is already visible.
  void ensureBaseIsVisible() {
    if (_delegate == null) {
      _log.warning("Can't make base selection visible. The scroll delegate is null.");
      return;
    }

    if (_textController.selection.baseOffset < 0) {
      // There is no base selection to make visible.
      return;
    }

    if (_textController.text.text.isEmpty) {
      // There is no text to make visible.
      return;
    }

    final baseCharacterRect = _delegate!.getViewportCharacterRectAtPosition(_textController.selection.base);
    _ensureRectIsVisible(baseCharacterRect);
  }

  /// Updates the scroll offset so that the current selection extent
  /// position is visible in the viewport.
  ///
  /// Does nothing if the extent position is already visible.
  void ensureExtentIsVisible() {
    if (_delegate == null) {
      _log.warning("Can't make extent selection visible. The scroll delegate is null.");
      return;
    }

    if (_textController.selection.extentOffset < 0) {
      // There is no extent selection to make visible.
      return;
    }

    if (_textController.text.text.isEmpty) {
      // There is no text to make visible.
      return;
    }

    final characterIndex = _textController.selection.extentOffset >= _textController.text.length
        ? _textController.text.length - 1
        : _textController.selection.extentOffset;

    final extentCharacterRectInViewportSpace =
        _delegate!.getViewportCharacterRectAtPosition(TextPosition(offset: characterIndex));

    final extentCharacterRectInContentSpace = _delegate!.isMultiline
        ? extentCharacterRectInViewportSpace.translate(0, _scrollOffset)
        : extentCharacterRectInViewportSpace.translate(-_scrollOffset, 0);

    // Inflate the rectangle by 2px to the right to add visual space for a caret.
    // FIXME: This is a hack to achieve the desired result. Implement a general policy,
    //        e.g., add a little padding to the left and right in all cases, account for
    //        actual caret dimensions, and make that happen before getting to this point.
    final extentCharacterPlusCaretRectInContentSpace = extentCharacterRectInContentSpace.inflateRight(2);

    _ensureRectIsVisible(extentCharacterPlusCaretRectInContentSpace);
  }

  void _ensureRectIsVisible(Rect rectInContentSpace) {
    assert(_delegate != null);

    _log.finer('Ensuring rect is visible: $rectInContentSpace');
    if (_delegate!.isMultiline) {
      final firstCharRect = _delegate!.getViewportCharacterRectAtPosition(const TextPosition(offset: 0));
      final isAtFirstLine = rectInContentSpace.top == firstCharRect.top;
      final extraSpacingAboveTop = (isAtFirstLine ? rectInContentSpace.height / 2 : 0);

      final lastCharRect =
          _delegate!.getViewportCharacterRectAtPosition(TextPosition(offset: _textController.text.text.length - 1));
      final isAtLastLine = rectInContentSpace.top == lastCharRect.top;
      final extraSpacingBelowBottom = (isAtLastLine ? rectInContentSpace.height / 2 : 0);
      if (rectInContentSpace.top - extraSpacingAboveTop - _scrollOffset < 0) {
        // The character is entirely or partially above the top of the viewport.
        // Scroll the content down.
        _setScrollOffset(max(rectInContentSpace.top - extraSpacingAboveTop, 0));
        _log.finer(' - updated _scrollOffset to $_scrollOffset');
        return;
      } else if (rectInContentSpace.bottom - _scrollOffset + extraSpacingBelowBottom > _delegate!.viewportHeight!) {
        // The character is entirely or partially below the bottom of the viewport.
        // Scroll the content up.
        _setScrollOffset(min(rectInContentSpace.bottom - _delegate!.viewportHeight! + extraSpacingBelowBottom,
            _delegate!.endScrollOffset));
        _log.finer(' - updated _scrollOffset to $_scrollOffset');
        return;
      }
    } else {
      final rectInViewportSpace = rectInContentSpace.translate(_scrollOffset, 0);

      if (rectInViewportSpace.left < 0) {
        // The character is entirely or partially before the start of the viewport.
        // Scroll the content right.
        _log.finer('Auto-scrolling to the left by ${rectInViewportSpace.left} to show a desired rectangle');
        _setScrollOffset((_scrollOffset + rectInViewportSpace.left).clamp(0, _delegate!.endScrollOffset));
        return;
      } else if (rectInViewportSpace.right > _delegate!.viewportWidth!) {
        // The character is entirely or partially after the end of the viewport.
        // Scroll the content left.
        final scrollAmount = rectInViewportSpace.right - _delegate!.viewportWidth!;
        _log.finer('Auto-scrolling to the right by $scrollAmount to show a desired rectangle');
        _setScrollOffset((_scrollOffset + scrollAmount).clamp(0, _delegate!.endScrollOffset));
      }
    }
  }
}

abstract class TextScrollControllerDelegate {
  /// The width of the scrollable viewport.
  double? get viewportWidth;

  /// The height of the scrollable viewport.
  double? get viewportHeight;

  /// The offset between the top-left of the viewport and the top-left of the
  /// text layout.
  Offset get textLayoutOffsetInViewport;

  /// Whether the text in the scrollable area is displayed
  /// in a multi-line format (as opposed to single-line format).
  bool get isMultiline;

  /// The scroll offset for the first character in the text.
  double get startScrollOffset;

  /// The scroll offset for the last character in the text.
  double get endScrollOffset;

  /// Whether the given [TextPosition] is currently visible in
  /// viewport.
  bool isTextPositionVisible(TextPosition position);

  /// Whether the given [offsetInViewport] is sitting in the
  /// area where the user expects an auto-scroll to happen
  /// towards the start of the text.
  bool isInAutoScrollToStartRegion(Offset offsetInViewport);

  /// Calculates the distance between the auto-scroll boundary
  /// at the start of the text field and the given [offsetInViewport].
  ///
  /// This value might be used, for example, to increase/decrease
  /// the auto-scroll velocity.
  double calculateDistanceBeyondStartingAutoScrollBoundary(Offset offsetInViewport);

  /// Whether the given [offsetInViewport] is sitting in the
  /// area where the user expects an auto-scroll to happen
  /// towards the end of the text.
  bool isInAutoScrollToEndRegion(Offset offsetInViewport);

  /// Calculates the distance between the auto-scroll boundary
  /// at the end of the text field and the given [offsetInViewport].
  ///
  /// This value might be used, for example, to increase/decrease
  /// the auto-scroll velocity.
  double calculateDistanceBeyondEndingAutoScrollBoundary(Offset offsetInViewport);

  double? getHorizontalOffsetForStartOfCharacterLeftOfViewport();

  double? getHorizontalOffsetForEndOfCharacterRightOfViewport();

  double? getVerticalOffsetForTopOfLineAboveViewport();

  double? getVerticalOffsetForBottomOfLineBelowViewport();

  /// Calculates and returns the bounding `Rect` for the character at the
  /// given [position] within the viewport's coordinates.
  ///
  /// The viewport coordinates implicitly include any padding between the
  /// viewport edges and the text, as well as the current scroll offset.
  Rect getViewportCharacterRectAtPosition(TextPosition position);
}

enum _AutoScrollDirection {
  start,
  end,
}

/// Sizes the [child] so its height falls within [minLines] and [maxLines], multiplied by the
/// given [lineHeight].
///
/// The [child] must contain a [SuperText] in its tree,
/// and the dimensions of the [child] subtree should match the dimensions
/// of the [SuperText]. The given [textKey] must be bound to the [SuperText]
/// within the [child]'s subtree.
class _TextLinesLimiter extends SingleChildRenderObjectWidget {
  const _TextLinesLimiter({
    required this.textKey,
    required this.scrollController,
    this.minLines,
    this.maxLines,
    this.lineHeight,
    this.padding,
    required super.child,
  });

  /// [GlobalKey] that references the [SuperText] within the [child]'s subtree.
  final GlobalKey<ProseTextState> textKey;

  /// The [ScrollController] associated with the multi-line text field that this
  /// widget is limiting - this controller must be provided so that during layout,
  /// while multiple layout passes are being run on the subtree, the initial scroll
  /// offset can be forcibly set after those intermediate layout passes.
  final ScrollController scrollController;

  /// The minimum height of this text scroll view, represented as a
  /// line count.
  final int? minLines;

  /// The maximum height of this text scroll view, represented as a
  /// line count.
  final int? maxLines;

  /// The height of a single line of text, used
  /// with [minLines] and [maxLines] to size the viewport.
  ///
  /// If a [lineHeight] is provided, the [_TextLinesLimiter] is sized as a
  /// multiple of that [lineHeight]. If no [lineHeight] is provided, the
  /// [_TextLinesLimiter] is sized as a multiple of the line-height of the
  /// first line of text.
  final double? lineHeight;

  /// Padding around the text.
  final EdgeInsets? padding;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTextViewport(
      textKey: textKey,
      scrollController: scrollController,
      minLines: minLines,
      maxLines: maxLines,
      lineHeight: lineHeight,
      padding: padding,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderTextViewport renderObject) {
    renderObject
      ..textKey = textKey
      ..scrollController = scrollController
      ..minLines = minLines
      ..maxLines = maxLines
      ..lineHeight = lineHeight
      ..padding = padding;
  }
}

class _RenderTextViewport extends RenderProxyBox {
  _RenderTextViewport({
    required GlobalKey<ProseTextState> textKey,
    required ScrollController scrollController,
    int? minLines,
    int? maxLines,
    double? lineHeight,
    EdgeInsets? padding,
  })  : _textKey = textKey,
        _scrollController = scrollController,
        _minLines = minLines,
        _maxLines = maxLines,
        _lineHeight = lineHeight,
        _padding = padding;

  GlobalKey<ProseTextState> _textKey;
  set textKey(GlobalKey<ProseTextState> value) {
    if (value == _textKey) {
      return;
    }

    _textKey = value;
    markNeedsLayout();
  }

  late ScrollController _scrollController;
  set scrollController(ScrollController value) {
    _scrollController = value;
  }

  int? _maxLines;
  set maxLines(int? value) {
    if (value == _maxLines) {
      return;
    }

    _maxLines = value;
    markNeedsLayout();
  }

  int? _minLines;
  set minLines(int? value) {
    if (value == _minLines) {
      return;
    }

    _minLines = value;
    markNeedsLayout();
  }

  double? _lineHeight;
  set lineHeight(double? value) {
    if (value == _lineHeight) {
      return;
    }

    _lineHeight = value;
    markNeedsLayout();
  }

  EdgeInsets? _padding;
  set padding(EdgeInsets? value) {
    if (value == _padding) {
      return;
    }

    _padding = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    // Note: Originally we had the following commented line setting the constraints
    //       for the child subtree. Due to some combination of changes for issue
    //       #1776, using these tightened constraints fails a test that checks for
    //       viewport re-sizing when the text gets longer.
    //
    //       Through experimentation, I found that in the test when we use tightened
    //       constraints, this text viewport doesn't even re-run its layout after the
    //       text changes. Maybe it's an issue with how we're reporting changes within
    //       SuperText, but I couldn't figure it out. For now, I'm leaving the original
    //       line commented, and using the version that seems to work for all tests and
    //       demo inspections. However, we should eventually figure out what's going
    //       wrong here with tightened constraints and then bring them back.
    // final childConstraints = constraints.tighten(width: constraints.maxWidth);
    final childConstraints = constraints;

    if (_minLines == null && _maxLines == null) {
      // We don't have restrictions about the number of visible lines.
      // Let the child size itself.
      child!.layout(childConstraints, parentUsesSize: true);
      size = child!.size;
      return;
    }

    // Log the current scroll offset because our multiple layout passes will
    // almost certainly cause the Scrollable to adjust the scroll offset as
    // the viewport thinks its size changes. We'll forcibly restore this
    // scroll offset at the end of layout.
    final scrollOffsetBeforeLayout = _scrollController.offset;

    // Layout the subtree with the text widget so we can query the text layout.
    child!.layout(childConstraints, parentUsesSize: true);

    final lineHeight = _computeLineHeight();
    final minHeight = _computeMinHeight(lineHeight);
    final maxHeight = _computeMaxHeight(lineHeight);

    // The height we need to enforce if the child doesn't already respects the line restrictions.
    double? adjustedChildHeight;

    // Compute the height the child wants to be.
    //
    // We layout instead of computing the child's intrinsic height, because RenderFlex doesn't
    // support calling getMinIntrinsicHeight if it has baseline cross-axis alignment.
    child!.layout(childConstraints.copyWith(maxHeight: double.infinity), parentUsesSize: true);
    final childIntrinsicHeight = child!.size.height;

    if (childIntrinsicHeight < minHeight) {
      adjustedChildHeight = minHeight;
    } else if (maxHeight != null && childIntrinsicHeight > maxHeight) {
      adjustedChildHeight = maxHeight;
    }

    if (adjustedChildHeight == null) {
      // The child's intrinsic height already respects the line restrictions.
      // Layout the text subtree again, this time forcing the child to be exactly its instrinsic height tall.
      child!.layout(childConstraints.tighten(height: childIntrinsicHeight), parentUsesSize: true);

      // Forcibly restore the scroll offset to the original pre-layout value.
      _scrollController.position.correctPixels(scrollOffsetBeforeLayout);

      size = child!.size;
      return;
    }

    // Layout the text subtree again, this time with forced height constraints.
    child!.layout(childConstraints.tighten(height: adjustedChildHeight), parentUsesSize: true);

    // Forcibly restore the scroll offset to the original pre-layout value.
    _scrollController.position.correctPixels(scrollOffsetBeforeLayout);

    size = child!.size;
  }

  double _computeMinHeight(double lineHeight) {
    final minContentHeight = _minLines != null //
        ? _minLines! * lineHeight
        : lineHeight; // Can't be shorter than 1 line.

    return minContentHeight + (_padding?.vertical ?? 0.0);
  }

  double? _computeMaxHeight(double lineHeight) {
    if (_maxLines == null) {
      return null;
    }

    return (_maxLines! * lineHeight) + (_padding?.vertical ?? 0.0);
  }

  double _computeLineHeight() {
    if (_lineHeight != null) {
      return _lineHeight!;
    }

    final textLayout = _textKey.currentState!.textLayout;

    // We don't expect getHeightForCaret to ever return null, but since its return type is nullable,
    // we use getLineHeightAtPosition as a backup.
    // More information in https://github.com/flutter/flutter/issues/145507.
    double lineHeight = textLayout.getHeightForCaret(const TextPosition(offset: 0)) ??
        textLayout.getLineHeightAtPosition(const TextPosition(offset: 0));
    _log.finer(' - line height at position 0: $lineHeight');

    // We got 0.0 for the line height at the beginning of text. Maybe the
    // text is empty. Ask the TextLayout to estimate a height for us that's
    // based on the text style.
    if (lineHeight == 0) {
      lineHeight = _textKey.currentState!.textLayout.estimatedLineHeight;
      _log.finer(' - estimated line height based on text styles: $lineHeight');
    }

    return lineHeight;
  }
}
