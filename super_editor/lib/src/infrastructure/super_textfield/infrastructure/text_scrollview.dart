import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text/super_selectable_text.dart';

final _log = scrollingTextFieldLog;

/// A scrollable that positions its [child] based on text metrics.
///
/// The [child] must contain a [SuperSelectableText] in its tree,
/// [textKey] must refer to that [SuperSelectableText], and the
/// dimensions of the [child] subtree should match the dimensions
/// of the [SuperSelectableText] so that there are no surprises
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
    required this.child,
  })  : assert(minLines == null || minLines == 1 || lineHeight != null, 'minLines > 1 requires a non-null lineHeight'),
        assert(maxLines == null || maxLines == 1 || lineHeight != null, 'maxLines > 1 requires a non-null lineHeight'),
        super(key: key);

  /// Controller that sets the scroll offset and orchestrates
  /// auto-scrolling behavior.
  final TextScrollController textScrollController;

  /// [GobalKey] that references the [SuperSelectableText] within
  /// the [child] subtree.
  final GlobalKey<SuperSelectableTextState> textKey;

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
  /// An explicit [lineHeight] is required for multi-line text fields
  /// because rich text in this text scroll view might have lines of
  /// varying height, which would result in a constantly changing text
  /// field height during scrolling. To avoid that situation, a single,
  /// explicit [lineHeight] is provided and used for all text field height
  /// calculations.
  final double? lineHeight;

  /// The time it takes to scroll to the next line, when auto-scrolling.
  ///
  /// A value of [Duration.zero] jumps immediately to the next line.
  final Duration perLineAutoScrollDuration;

  /// Whether to paint debug guides.
  final bool showDebugPaint;

  /// The child widget.
  final Widget child;

  @override
  _TextScrollViewState createState() => _TextScrollViewState();
}

class _TextScrollViewState extends State<TextScrollView>
    with SingleTickerProviderStateMixin
    implements TextScrollControllerDelegate {
  final _singleLineFieldAutoScrollGap = 24.0;
  final _mulitlineFieldAutoScrollGap = 20.0;

  final _textFieldViewportKey = GlobalKey();

  final _scrollController = ScrollController();

  bool _needViewportHeight = true;
  double? _viewportHeight;

  @override
  void initState() {
    super.initState();

    widget.textScrollController
      ..delegate = this
      ..addListener(_onTextScrollChange);
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

    if (widget.minLines != oldWidget.minLines ||
        widget.maxLines != oldWidget.maxLines ||
        widget.lineHeight != oldWidget.lineHeight) {
      // Force a new viewport height calculation.
      setState(() {
        _log.fine('Need another viewport height');
        _needViewportHeight = true;
      });
    }
  }

  @override
  void dispose() {
    widget.textScrollController
      ..delegate = null
      ..removeListener(_onTextScrollChange);

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
  bool get isMultiline => widget.maxLines == null || widget.maxLines! > 1;

  bool get isBounded => widget.maxLines != null;

  @override
  double get startScrollOffset => 0.0;

  @override
  double get endScrollOffset {
    final viewportHeight = this.viewportHeight;
    if (viewportHeight == null) {
      return 0;
    }

    final lastCharacterPosition = TextPosition(offset: widget.textEditingController.text.text.length - 1);
    return _text.getCharacterBox(lastCharacterPosition).bottom - viewportHeight;
  }

  @override
  bool isTextPositionVisible(TextPosition position) {
    if (isMultiline) {
      final viewportHeight = this.viewportHeight;
      if (viewportHeight == null) {
        return false;
      }

      final characterBox = _text.getCharacterBox(position);
      final scrolledCharacterTop = characterBox.top - _scrollController.offset;
      final scrolledCharacterBottom = characterBox.bottom - _scrollController.offset;
      // Round the top/bottom values to avoid false negatives due to floating point accuracy.
      return scrolledCharacterTop.round() >= 0 && scrolledCharacterBottom.round() <= viewportHeight;
    } else {
      final viewportWidth = this.viewportWidth;
      if (viewportWidth == null) {
        return false;
      }

      final offsetInViewport = _text.getOffsetAtPosition(position) - Offset(_scrollController.offset, 0);
      // Round the top/bottom values to avoid false negatives due to floating point accuracy.
      return offsetInViewport.dx.round() >= 0 && offsetInViewport.dx.round() <= viewportWidth;
    }
  }

  @override
  bool isInAutoScrollToStartRegion(Offset offsetInViewport) {
    if (isMultiline) {
      return offsetInViewport.dy <= _mulitlineFieldAutoScrollGap;
    } else {
      return offsetInViewport.dx <= _singleLineFieldAutoScrollGap;
    }
  }

  @override
  bool isInAutoScrollToEndRegion(Offset offsetInViewport) {
    if (isMultiline) {
      final viewportHeight = this.viewportHeight;
      if (viewportHeight == null) {
        return false;
      }

      return offsetInViewport.dy >= viewportHeight - _mulitlineFieldAutoScrollGap;
    } else {
      final viewportWidth = this.viewportWidth;
      if (viewportWidth == null) {
        return false;
      }

      return offsetInViewport.dx >= viewportWidth - _singleLineFieldAutoScrollGap;
    }
  }

  @override
  Rect getCharacterRectAtPosition(TextPosition position) {
    return _text.getCharacterBox(position).toRect();
  }

  @override
  double getHorizontalOffsetForStartOfCharacterLeftOfViewport() {
    // Note: we look for an offset that is slightly further down than zero
    // to avoid any issues with the layout system differentiating between lines.
    final textPositionAtLeftEnd = _text.getPositionNearestToOffset(Offset(_scrollController.offset, 5));
    final nextPosition = textPositionAtLeftEnd.offset <= 0
        ? textPositionAtLeftEnd
        : TextPosition(offset: textPositionAtLeftEnd.offset - 1);
    return _text.getOffsetAtPosition(nextPosition).dx;
  }

  @override
  double getHorizontalOffsetForEndOfCharacterRightOfViewport() {
    final viewportWidth = (context.findRenderObject() as RenderBox).size.width;
    // Note: we look for an offset that is slightly further down than zero
    // to avoid any issues with the layout system differentiating between lines.
    final textPositionAtRightEnd =
        _text.getPositionNearestToOffset(Offset(viewportWidth + _scrollController.offset, 5));
    final nextPosition = textPositionAtRightEnd.offset >= widget.textEditingController.text.text.length - 1
        ? textPositionAtRightEnd
        : TextPosition(offset: textPositionAtRightEnd.offset + 1);
    return _text.getOffsetAtPosition(nextPosition).dx;
  }

  @override
  double getVerticalOffsetForTopOfLineAboveViewport() {
    final topOfFirstLine = _scrollController.offset;
    // Note: we nudge the vertical offset up a few pixels to see if we
    // find a text position in the line above.
    final textPositionOneLineUp = _text.getPositionNearestToOffset(Offset(0, topOfFirstLine - 5));
    return _text.getOffsetAtPosition(textPositionOneLineUp).dy;
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
    final textPositionOneLineDown = _text.getPositionNearestToOffset(Offset(0, bottomOfLastLine + 5));
    final bottomOfCharacter = _text.getCharacterBox(textPositionOneLineDown).bottom;
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

  /// Returns true if the viewport height changed, false otherwise.
  bool _updateViewportHeight() {
    _log.finer('Updating viewport height...');

    final linesOfText = _getLineCount();
    _log.finer(' - lines of text: $linesOfText');

    final estimatedContentHeight = linesOfText * widget.lineHeight!;
    _log.finer(' - estimated content height: $estimatedContentHeight');

    final minHeight = widget.minLines != null
        ? widget.minLines! * widget.lineHeight!
        : widget.lineHeight; // Can't be shorter than 1 line
    final maxHeight = widget.maxLines != null //
        ? widget.maxLines! * widget.lineHeight! //
        : null;
    _log.finer(' - minHeight: $minHeight, maxHeight: $maxHeight');

    double? viewportHeight;
    if (maxHeight != null && estimatedContentHeight >= maxHeight) {
      _log.finer(' - setting viewport height to maxHeight');
      viewportHeight = maxHeight;
    } else if (minHeight != null && estimatedContentHeight <= minHeight) {
      _log.finer(' - setting viewport height to minHeight');
      viewportHeight = minHeight;
    }

    if (!_needViewportHeight && viewportHeight == _viewportHeight) {
      // The height of the viewport hasn't changed. Return.
      _log.finer(' - viewport height hasn\'t changed');
      return false;
    }

    if (viewportHeight == null && isMultiline && !isBounded) {
      // We don't have a viewport height, but we're multiline and
      // unbounded so a null viewport height is fine. We'll wrap
      // the intrinsic height of the text.
      _log.finer(' - viewport height is null, but TextScrollView is unbounded so that is OK');
      final didChange = viewportHeight != _viewportHeight;
      if (mounted) {
        setState(() {
          _needViewportHeight = false;
          _viewportHeight = null;
        });
      }
      return didChange;
    }

    if (viewportHeight != null) {
      setState(() {
        _log.finer(' - new viewport height: $viewportHeight');
        _needViewportHeight = false;
        _viewportHeight = viewportHeight;
      });

      return true;
    } else {
      _log.finer(' - could not calculate a viewport height. Rescheduling calculation.');

      // We still don't have a resolved viewport height. Run again next frame.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (mounted) {
          setState(() {
            _updateViewportHeight();
          });
        }
      });

      return false;
    }
  }

  int _getLineCount() {
    if (widget.textEditingController.text.text.isEmpty) {
      return 0;
    }

    if (widget.textKey.currentState == null) {
      return 0;
    }

    return widget.textKey.currentState!.getLineCount();
  }

  /// Returns the [SuperSelectableTextState] that lays out and renders the
  /// text in this text field.
  SuperSelectableTextState get _text => widget.textKey.currentState!;

  @override
  Widget build(BuildContext context) {
    if (widget.textKey.currentContext == null || _needViewportHeight) {
      // The text hasn't been laid out yet, which means our calculations
      // for text height is probably wrong. Schedule a post frame callback
      // to re-calculate the height after initial layout.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (mounted) {
          _updateViewportHeight();
        }
      });
    }

    return Opacity(
      opacity: (widget.maxLines != null && widget.maxLines! > 1 && _viewportHeight == null) ? 0.0 : 1.0,
      child: SizedBox(
        width: double.infinity,
        height: _viewportHeight,
        child: Stack(
          children: [
            _buildScrollView(
              child: widget.child,
            ),
            if (widget.showDebugPaint) ..._buildDebugScrollRegions(),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollView({
    required Widget child,
  }) {
    return SingleChildScrollView(
      key: _textFieldViewportKey,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: isMultiline ? Axis.vertical : Axis.horizontal,
      child: widget.child,
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

  double _scrollOffset = 0.0;
  double get scrollOffset => _scrollOffset;

  _AutoScrollDirection? _autoScrollDirection;

  Duration _timeOfNextAutoScroll = Duration.zero;

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
      _scrollOffset = startScrollOffset;
      notifyListeners();
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
      _scrollOffset = endScrollOffset;
      notifyListeners();
    }
  }

  void updateAutoScrollingForTouchOffset({
    required Offset userInteractionOffsetInViewport,
  }) {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll. The auto-scroll delegate is null.");
      return;
    }

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
      // Already scrolling to start. Return.
      return;
    }

    stopScrolling();

    _log.fine('Auto-scrolling to end');
    _autoScrollDirection = _AutoScrollDirection.end;
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
      // Not enough time has passed to jump further in the scroll direction.
      return;
    }

    _log.finer('auto-scroll tick, is multiline: ${_delegate!.isMultiline}, direction: $_autoScrollDirection');
    final offsetBeforeScroll = _scrollOffset;

    if (_delegate!.isMultiline) {
      if (_autoScrollDirection == _AutoScrollDirection.start) {
        _autoScrollOneLineUp();
      } else {
        _autoScrollOneLineDown();
      }
    } else {
      // TODO: implement RTL support
      if (_autoScrollDirection == _AutoScrollDirection.start) {
        _autoScrollOneCharacterLeft();
      } else {
        _autoScrollOneCharacterRight();
      }
    }

    if (_scrollOffset == offsetBeforeScroll) {
      _log.fine('Offset did not change during tick. Stopping scroll.');
      // We've reached the desired start or end. Stop auto-scrolling.
      stopScrolling();
    }
  }

  void _autoScrollOneCharacterLeft() {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll left. The scroll delegate is null.");
      return;
    }

    final horizontalOffsetForStartOfCharacterLeftOfViewport =
        _delegate!.getHorizontalOffsetForStartOfCharacterLeftOfViewport();
    if (horizontalOffsetForStartOfCharacterLeftOfViewport == null) {
      _log.warning(
          "Can't auto-scroll left. Couldn't calculate the horizontal offset for the first character beyond the viewport");
      return;
    }

    _log.finer('_autoScrollOneCharacterLeft. Scroll offset before: $scrollOffset');
    _scrollOffset = horizontalOffsetForStartOfCharacterLeftOfViewport;
    _log.finer(' - _scrollOffset after: $_scrollOffset');
    _timeOfNextAutoScroll += _autoScrollTimePerCharacter;

    notifyListeners();
  }

  void _autoScrollOneCharacterRight() {
    if (_delegate == null) {
      _log.warning("Can't auto-scroll right. The scroll delegate is null.");
      return;
    }

    final viewportWidth = _delegate!.viewportWidth;
    if (viewportWidth == null) {
      _log.warning("Can't auto-scroll right. Viewport width is null");
      return;
    }

    final horizontalOffsetForEndOfCharacterRightOfViewport =
        _delegate!.getHorizontalOffsetForEndOfCharacterRightOfViewport();
    if (horizontalOffsetForEndOfCharacterRightOfViewport == null) {
      _log.warning(
          "Can't auto-scroll right. Couldn't calculate the horizontal offset for the first character beyond the viewport");
      return;
    }

    _log.finer('Scrolling right');
    _scrollOffset = horizontalOffsetForEndOfCharacterRightOfViewport - viewportWidth;
    _log.finer(' - _scrollOffset after: $_scrollOffset');
    _timeOfNextAutoScroll += _autoScrollTimePerCharacter;

    notifyListeners();
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
    _scrollOffset = verticalOffsetForTopOfLineAboveViewport;
    _timeOfNextAutoScroll += _autoScrollTimePerLine;
    _log.fine('New scroll offset: $_scrollOffset, time of next scroll: $_timeOfNextAutoScroll');

    notifyListeners();
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
    _scrollOffset = verticalOffsetForBottomOfLineBelowViewport - viewportHeight;
    _timeOfNextAutoScroll += _autoScrollTimePerLine;
    _log.fine('New scroll offset: $_scrollOffset, time of next scroll: $_timeOfNextAutoScroll');

    notifyListeners();
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

    final baseCharacterRect = _delegate!.getCharacterRectAtPosition(_textController.selection.base);
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

    final characterIndex = _textController.selection.extentOffset >= _textController.text.text.length
        ? _textController.text.text.length - 1
        : _textController.selection.extentOffset;
    final extentCharacterRect = _delegate!.getCharacterRectAtPosition(TextPosition(offset: characterIndex));
    _ensureRectIsVisible(extentCharacterRect);
  }

  void _ensureRectIsVisible(Rect rect) {
    assert(_delegate != null);

    _log.finer('Ensuring rect is visible: $rect');
    if (rect.top < 0) {
      // The character is entirely or partially above the top of the viewport.
      // Scroll the content down.
      _scrollOffset = rect.top;
      _log.finer(' - updated _scrollOffset to $_scrollOffset');
    } else if (rect.bottom > _delegate!.viewportHeight!) {
      // The character is entirely or partially below the bottom of the viewport.
      // Scroll the content up.
      _scrollOffset = rect.bottom - _delegate!.viewportHeight!;
      _log.finer(' - updated _scrollOffset to $_scrollOffset');
    }

    notifyListeners();
  }
}

abstract class TextScrollControllerDelegate {
  /// The width of the scrollable viewport.
  double? get viewportWidth;

  /// The height of the scrollable viewport.
  double? get viewportHeight;

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

  /// Whether the given [offsetInViewport] is sitting in the
  /// area where the user expects an auto-scroll to happen
  /// towards the end of the text.
  bool isInAutoScrollToEndRegion(Offset offsetInViewport);

  double? getHorizontalOffsetForStartOfCharacterLeftOfViewport();

  double? getHorizontalOffsetForEndOfCharacterRightOfViewport();

  double? getVerticalOffsetForTopOfLineAboveViewport();

  double? getVerticalOffsetForBottomOfLineBelowViewport();

  Rect getCharacterRectAtPosition(TextPosition position);
}

enum _AutoScrollDirection {
  start,
  end,
}
