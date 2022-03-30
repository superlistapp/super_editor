import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'caret.dart';
import 'text_layout.dart';

/// Displays text with a selection highlight and a caret.
///
/// [SuperSelectableText] does not recognize any user interaction. It's the
/// responsibility of ancestor widgets to recognize interactions that
/// should alter this widget's text selection and/or caret position.
///
/// [textSelection] determines the span of text to be painted
/// with a selection highlight.
///
/// [showCaret] and [textSelection] together determine whether or not the
/// caret is painted in this [SuperSelectableText]. If [textSelection] is collapsed
/// with an offset `< 0`, then no caret is displayed. If [showCaret] is
/// `false` then no caret is displayed. If [textSelection] has a [baseOffset]
/// or [extentOffset] that is `>= 0` and [showCaret] is `true`, then a caret is
/// displayed. An explicit [showCaret] control is offered because multiple
/// [SuperSelectableText] widgets might be displayed together with a selection
/// spanning multiple [SuperSelectableText] widgets, but only one of the
/// [SuperSelectableText] widgets displays a caret.
///
/// If [text] is empty, and a [textSelection] with an extent `>= 0` is provided, and
/// [highlightWhenEmpty] is `true`, then [SuperSelectableText] will paint a small
/// highlight, despite having no content. This is useful when showing that
/// one or more empty text areas are selected.
class SuperSelectableText extends StatefulWidget {
  /// [SuperSelectableText] that displays plain text (only one text style).
  SuperSelectableText.plain({
    Key? key,
    required String text,
    required TextStyle style,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.textSelection = const TextSelection.collapsed(offset: -1),
    this.textSelectionDecoration = const TextSelectionDecoration(
      selectionColor: Color(0xFFACCEF7),
    ),
    this.showCaret = false,
    this.textCaretFactory = const TextCaretFactory(
      color: Colors.black,
      width: 1,
      borderRadius: BorderRadius.zero,
    ),
    this.highlightWhenEmpty = false,
  })  : richText = TextSpan(text: text, style: style),
        super(key: key);

  /// [SuperSelectableText] that displays styled text.
  const SuperSelectableText({
    Key? key,
    required TextSpan textSpan,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.textSelection = const TextSelection.collapsed(offset: -1),
    this.textSelectionDecoration = const TextSelectionDecoration(
      selectionColor: Color(0xFFACCEF7),
    ),
    this.highlightWhenEmpty = false,
    this.showCaret = false,
    this.textCaretFactory = const TextCaretFactory(
      color: Colors.black,
      width: 1,
      borderRadius: BorderRadius.zero,
    ),
  })  : richText = textSpan,
        super(key: key);

  /// The text to display in this [SuperSelectableText] widget.
  final TextSpan richText;

  /// The alignment to use for [richText] display.
  final TextAlign textAlign;

  /// The text direction to use for [richText] display.
  final TextDirection textDirection;

  /// The portion of [richText] to display with the
  /// [textSelectionDecoration].
  final TextSelection textSelection;

  /// The visual decoration to apply to the [textSelection].
  final TextSelectionDecoration textSelectionDecoration;

  /// Builds the visual representation of the caret in this
  /// [SuperSelectableText] widget.
  final TextCaretFactory textCaretFactory;

  /// True to show a thin selection highlight when [richText]
  /// is empty, or false to avoid showing a selection highlight
  /// when [richText] is empty.
  ///
  /// This is useful when multiple [SuperSelectableText] widgets
  /// are selected and some of the selected [SuperSelectableText]
  /// widgets are empty.
  final bool highlightWhenEmpty;

  /// True to display a caret in this [SuperSelectableText] at
  /// the [extent] of [textSelection], or false to avoid
  /// displaying a caret.
  final bool showCaret;

  @override
  SuperSelectableTextState createState() => SuperSelectableTextState();
}

class SuperSelectableTextState extends State<SuperSelectableText> implements TextLayout {
  // [GlobalKey] that provides access to the [RenderParagraph] associated
  // with the text that this [SuperSelectableText] widget displays.
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _updateTextLength();
  }

  @override
  void didUpdateWidget(SuperSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.richText != oldWidget.richText) {
      _updateTextLength();
    }
  }

  // The current length of the text displayed by this widget. The value
  // is cached because computing the length of rich text may have
  // non-trivial performance implications.
  late int _cachedTextLength;
  int get _textLength => _cachedTextLength;
  void _updateTextLength() {
    _cachedTextLength = widget.richText.toPlainText().length;
  }

  RenderParagraph? get _renderParagraph =>
      _textKey.currentContext != null ? _textKey.currentContext!.findRenderObject() as RenderParagraph : null;

  // TODO: use TextPainter line height when Flutter makes the info available. (#46)
  double get _lineHeight {
    final fontSize = widget.richText.style?.fontSize;
    final lineHeight = widget.richText.style?.height;
    return (fontSize ?? 16) * (lineHeight ?? 1.0);
  }

  @override
  TextPosition getPositionAtOffset(Offset localOffset) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    // TODO: bring back this condition by changing existing uses of
    //       getPositionAtOffset to getPositionNearestToOffset
    // if (!_renderParagraph!.size.contains(localOffset)) {
    //   return TextPosition(offset: -1);
    // }

    return _renderParagraph!.getPositionForOffset(localOffset);
  }

  @override
  TextPosition getPositionNearestToOffset(Offset localOffset) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    return _renderParagraph!.getPositionForOffset(localOffset);
  }

  @override
  Offset getOffsetAtPosition(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SelectableText does not yet have a RenderParagraph. Can\'t getOffsetForPosition().');
    }

    if (_renderParagraph!.hasSize && (kDebugMode && _renderParagraph!.debugNeedsLayout)) {
      // This condition was added because getOffsetForCaret() was throwing
      // an exception when debugNeedsLayout is true. It's unclear what we're
      // supposed to do at our level to ensure that condition doesn't happen
      // so until we figure it out, we'll just return a zero Offset.
      //
      // Later, hasSize was added to this check because it was discovered that
      // debugNeedsLayout can be only be accessed in debug mode. The hope is that
      // hasSize will roughly approximate the same information in profile and
      // release modes.
      return Offset.zero;
    }

    return _renderParagraph!.getOffsetForCaret(position, Rect.zero);
  }

  @override
  double getLineHeightAtPosition(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SelectableText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }
    if (kDebugMode && _renderParagraph!.debugNeedsLayout) {
      // We can't ask the RenderParagraph for metrics when it's dirty, so we have
      // to estimate the line height based on the text style, if it exists.
      return (widget.richText.style?.fontSize ?? 0.0) * (widget.richText.style?.height ?? 1.0);
    }

    final lineHeightMultiplier = widget.richText.style?.height ?? 1.0;

    // If no text is currently displayed, we can't use a character box
    // to measure, but we may be able to use related metrics.
    if (widget.richText.toPlainText().isEmpty) {
      final estimatedLineHeight =
          _renderParagraph!.getFullHeightForCaret(position) ?? widget.richText.style?.fontSize ?? 0.0;
      return estimatedLineHeight * lineHeightMultiplier;
    }

    // There is some text in this layout. Get the bounding box for the
    // character at the given position and return its height.
    return getCharacterBox(position).toRect().height * lineHeightMultiplier;
  }

  @override
  int getLineCount() {
    if (_renderParagraph == null) {
      throw Exception('SelectableText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }
    if (kDebugMode && _renderParagraph!.debugNeedsLayout) {
      return 0;
    }

    return _renderParagraph!
        .getBoxesForSelection(TextSelection(
          baseOffset: 0,
          extentOffset: widget.richText.toPlainText().length,
        ))
        .length;
  }

  @override
  Offset getOffsetForCaret(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SelectableText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }

    return _renderParagraph!.getOffsetForCaret(position, Rect.zero);
  }

  @override
  double? getHeightForCaret(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SelectableText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }

    return _renderParagraph!.getFullHeightForCaret(position);
  }

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    if (_renderParagraph == null) {
      throw Exception('SelectableText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }

    return _renderParagraph!.getBoxesForSelection(selection);
  }

  @override
  TextBox getCharacterBox(TextPosition position) {
    if (_renderParagraph == null) {
      return const TextBox.fromLTRBD(0, 0, 0, 0, TextDirection.ltr);
    }

    final plainText = widget.richText.toPlainText();
    if (plainText.isEmpty) {
      final lineHeightEstimate = _renderParagraph!.getFullHeightForCaret(const TextPosition(offset: 0)) ?? 0.0;
      return TextBox.fromLTRBD(0, 0, 0, lineHeightEstimate, TextDirection.ltr);
    }

    // Ensure that the given TextPosition does not exceed available text length.
    var characterPosition = position.offset >= plainText.length ? TextPosition(offset: plainText.length - 1) : position;

    var boxes = _renderParagraph!.getBoxesForSelection(TextSelection(
      baseOffset: characterPosition.offset,
      extentOffset: characterPosition.offset + 1,
    ));

    // For any regular character, boxes should return exactly one box
    // for the character. However, emojis don't return any boxes. In that
    // case, we walk the characters up and down the text, hoping to find
    // a non-emoji to measure. If all of the content is emojis, then we can't
    // get a measurement from Flutter.
    //
    // If we don't have any boxes, walk backward in the text to find
    // a character with a box.
    while (boxes.isEmpty && characterPosition.offset > 0) {
      characterPosition = TextPosition(offset: characterPosition.offset - 1);

      boxes = _renderParagraph!.getBoxesForSelection(TextSelection(
        baseOffset: characterPosition.offset,
        extentOffset: characterPosition.offset + 1,
      ));
    }

    // If we still don't have any boxes, walk forward in the text to find
    // a character with a box.
    while (boxes.isEmpty && characterPosition.offset < _textLength - 1) {
      characterPosition = TextPosition(offset: characterPosition.offset + 1);

      boxes = _renderParagraph!.getBoxesForSelection(TextSelection(
        baseOffset: characterPosition.offset,
        extentOffset: characterPosition.offset + 1,
      ));
    }

    return boxes.first;
  }

  @override
  TextPosition getPositionAtStartOfLine(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    final renderParagraph = _renderParagraph!;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final positionOffset = renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, _lineHeight / 2);
    final endOfLineOffset = Offset(0, positionOffset.dy);
    return renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  @override
  TextPosition getPositionAtEndOfLine(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    final renderParagraph = _renderParagraph!;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final positionOffset = renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, _lineHeight / 2);
    final endOfLineOffset = Offset(renderParagraph.size.width, positionOffset.dy);
    return renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  @override
  TextPosition? getPositionOneLineUp(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return null;
    }

    final renderParagraph = _renderParagraph!;
    final lineHeight = _lineHeight;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineUpOffset = currentSelectionOffset - Offset(0, lineHeight);

    if (oneLineUpOffset.dy < 0) {
      // The first line is selected. There is no line above this.
      return null;
    }

    return renderParagraph.getPositionForOffset(oneLineUpOffset);
  }

  @override
  TextPosition? getPositionOneLineDown(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return null;
    }

    final renderParagraph = _renderParagraph!;
    final lineHeight = _lineHeight;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineDownOffset = currentSelectionOffset + Offset(0, lineHeight);

    if (oneLineDownOffset.dy > renderParagraph.size.height) {
      // The last line is selected. There is no line below that.
      return null;
    }

    return renderParagraph.getPositionForOffset(oneLineDownOffset);
  }

  @override
  TextPosition getPositionInFirstLineAtX(double x) {
    return getPositionAtOffset(
      Offset(x, 0),
    );
  }

  @override
  TextPosition getPositionInLastLineAtX(double x) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    return getPositionAtOffset(
      Offset(x, _renderParagraph!.size.height),
    );
  }

  TextSelection getWordSelectionAt(TextPosition position) {
    if (_renderParagraph == null) {
      return const TextSelection.collapsed(offset: -1);
    }

    final wordRange = _renderParagraph!.getWordBoundary(position);
    return TextSelection(
      baseOffset: wordRange.start,
      extentOffset: wordRange.end,
    );
  }

  @override
  TextSelection expandSelection(TextPosition position, TextExpansion expansion, TextAffinity affinity) {
    return expansion(widget.richText.toPlainText(), position, affinity);
  }

  @override
  bool isTextAtOffset(Offset localOffset) {
    if (_renderParagraph == null) {
      return false;
    }

    List<TextBox> boxes = _renderParagraph!.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: _textLength,
      ),
    );

    for (final box in boxes) {
      if (box.toRect().contains(localOffset)) {
        return true;
      }
    }

    return false;
  }

  Rect calculateLocalOverlap({
    required Rect region,
    required RenderObject ancestorCoordinateSpace,
  }) {
    if (_renderParagraph == null) {
      return Rect.zero;
    }

    final renderParagraph = _renderParagraph!;
    final contentOffset = renderParagraph.localToGlobal(Offset.zero, ancestor: ancestorCoordinateSpace);
    final textRect = contentOffset & renderParagraph.size;

    if (region.overlaps(textRect)) {
      // Report the overlap in our local coordinate space.
      return region.translate(-contentOffset.dx, -contentOffset.dy);
    } else {
      return Rect.zero;
    }
  }

  @override
  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset) {
    if (_renderParagraph == null) {
      return const TextSelection.collapsed(offset: -1);
    }

    final renderParagraph = _renderParagraph!;
    final contentHeight = renderParagraph.size.height;
    final textLength = _textLength;

    // We don't know whether the base offset is higher or lower than the
    // extent offset. Regardless, if either offset is above the top of
    // the text then that text position should be 0. If either offset
    // is below the bottom of the text then that offset should be the
    // total length of the text.
    final basePosition = baseOffset.dy < 0
        ? 0
        : baseOffset.dy > contentHeight
            ? textLength
            : renderParagraph.getPositionForOffset(baseOffset).offset;
    final extentPosition = extentOffset.dy < 0
        ? 0
        : extentOffset.dy > contentHeight
            ? textLength
            : renderParagraph.getPositionForOffset(extentOffset).offset;

    final selection = TextSelection(
      baseOffset: basePosition,
      extentOffset: extentPosition,
    );

    return selection;
  }

  @override
  Widget build(BuildContext context) {
    if (_renderParagraph == null) {
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        if (mounted) {
          setState(() {
            // Force another frame so that we can use the renderParagraph.
          });
        }
      });
    }

    // The only item in this Stack with intrinsic height is the text.
    // We wrap with IntrinsicHeight so that the text selection widget and
    // the text controls widget have explicit bounds, so that they can
    // position their content relative to the text without inadvertently
    // expanding to take up all available space on the screen.
    return IntrinsicHeight(
      child: IntrinsicWidth(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildTextSelection(),
            _FillWidthIfConstrained(
              child: _buildText(),
            ),
            _buildTextCaret(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSelection() {
    if (_renderParagraph == null) {
      return const SizedBox();
    }

    return widget.textSelectionDecoration.build(
      context: context,
      renderParagraph: _renderParagraph!,
      selection: widget.textSelection,
      isTextEmpty: _textLength == 0,
      highlightWhenEmpty: widget.highlightWhenEmpty,
      emptyLineHeight: _lineHeight,
    );
  }

  Widget _buildText() {
    return RichText(
      key: _textKey,
      text: widget.richText,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
    );
  }

  Widget _buildTextCaret() {
    if (_renderParagraph == null) {
      return const SizedBox();
    }

    return RepaintBoundary(
      child: widget.textCaretFactory.build(
        context: context,
        textLayout: this,
        selection: widget.textSelection,
        isTextEmpty: _textLength == 0,
        showCaret: widget.showCaret,
      ),
    );
  }
}

class TextSelectionDecoration {
  const TextSelectionDecoration({
    required this.selectionColor,
  });

  final Color selectionColor;

  Widget build({
    required BuildContext context,
    required RenderParagraph renderParagraph,
    required TextSelection selection,
    required bool isTextEmpty,
    required bool highlightWhenEmpty,
    required double emptyLineHeight,
  }) {
    return CustomPaint(
      painter: _TextSelectionPainter(
        renderParagraph: renderParagraph,
        selection: selection,
        selectionColor: selectionColor,
        isTextEmpty: isTextEmpty,
        highlightWhenEmpty: highlightWhenEmpty,
        emptySelectionHeight: emptyLineHeight,
      ),
    );
  }
}

class _TextSelectionPainter extends CustomPainter {
  _TextSelectionPainter({
    required this.isTextEmpty,
    required this.renderParagraph,
    required this.selection,
    required this.emptySelectionHeight,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : selectionPaint = Paint()..color = selectionColor;

  final bool isTextEmpty;
  final RenderParagraph renderParagraph;
  final TextSelection selection;
  final double emptySelectionHeight;
  // When true, an empty, collapsed selection will be highlighted
  // for the purpose of showing a highlighted empty line.
  final bool highlightWhenEmpty;
  final Color selectionColor;
  final Paint selectionPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (isTextEmpty && highlightWhenEmpty && selection.isCollapsed && selection.extentOffset == 0) {
      //&& highlightWhenEmpty) {
      // This is an empty paragraph, which is selected. Paint a small selection.
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 5, 20),
        selectionPaint,
      );
    }

    final selectionBoxes = renderParagraph.getBoxesForSelection(selection);

    for (final box in selectionBoxes) {
      final rawRect = box.toRect();
      final rect = Rect.fromLTWH(rawRect.left, rawRect.top - 2, rawRect.width, rawRect.height + 4);

      canvas.drawRect(
        // Note: If the rect has no width then we've selected an empty line. Give
        //       that line a slight width for visibility.
        rect.width > 0 ? rect : Rect.fromLTWH(rect.left, rect.top, 5, rect.height),
        selectionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TextSelectionPainter oldDelegate) {
    return renderParagraph != oldDelegate.renderParagraph || selection != oldDelegate.selection;
  }
}

class TextCaretFactory {
  const TextCaretFactory({
    required Color color,
    double width = 1.0,
    BorderRadius borderRadius = BorderRadius.zero,
  })  : _color = color,
        _width = width,
        _borderRadius = borderRadius;

  final Color _color;
  final double _width;
  final BorderRadius _borderRadius;

  Widget build({
    required BuildContext context,
    required TextLayout textLayout,
    required TextSelection selection,
    required bool isTextEmpty,
    required bool showCaret,
  }) {
    return BlinkingTextCaret(
      textLayout: textLayout,
      color: _color,
      width: _width,
      borderRadius: _borderRadius,
      textPosition: selection.extent,
      isTextEmpty: isTextEmpty,
      showCaret: showCaret,
    );
  }
}

/// Wraps a given [SuperSelectableText] and paints extra decoration
/// to visualize text boundaries.
class DebugSelectableTextDecorator extends StatefulWidget {
  const DebugSelectableTextDecorator({
    Key? key,
    required this.selectableTextKey,
    required this.textLength,
    required this.child,
    this.showDebugPaint = false,
  }) : super(key: key);

  final GlobalKey selectableTextKey;
  final int textLength;
  final SuperSelectableText child;
  final bool showDebugPaint;

  @override
  _DebugSelectableTextDecoratorState createState() => _DebugSelectableTextDecoratorState();
}

class _DebugSelectableTextDecoratorState extends State<DebugSelectableTextDecorator> {
  SuperSelectableTextState? get _selectableTextState =>
      widget.selectableTextKey.currentState as SuperSelectableTextState?;

  RenderParagraph? get _renderParagraph => _selectableTextState?._renderParagraph;

  List<Rect> _computeTextRectangles(RenderParagraph renderParagraph) {
    return renderParagraph
        .getBoxesForSelection(TextSelection(
          baseOffset: 0,
          extentOffset: widget.textLength,
        ))
        .map((box) => box.toRect())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.showDebugPaint) _buildDebugPaint(),
        widget.child,
      ],
    );
  }

  Widget _buildDebugPaint() {
    if (_selectableTextState == null) {
      // Schedule another frame so we can compute the debug paint.
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return const SizedBox();
    }
    if (_renderParagraph == null) {
      // Schedule another frame so we can compute the debug paint.
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return const SizedBox();
    }
    if (_renderParagraph!.hasSize && (kDebugMode && _renderParagraph!.debugNeedsLayout)) {
      // Schedule another frame so we can compute the debug paint.
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return const SizedBox();
    }

    return Positioned.fill(
      child: CustomPaint(
        painter: _DebugTextPainter(
          textRectangles: _computeTextRectangles(_renderParagraph!),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DebugTextPainter extends CustomPainter {
  _DebugTextPainter({
    required this.textRectangles,
  });

  final List<Rect> textRectangles;
  final Paint leftBoundaryPaint = Paint()..color = const Color(0xFFCCCCCC);
  final Paint textBoxesPaint = Paint()
    ..color = const Color(0xFFCCCCCC)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    for (final rect in textRectangles) {
      canvas.drawRect(
        rect,
        textBoxesPaint,
      );
    }

    // Paint left boundary.
    canvas.drawRect(
      Rect.fromLTWH(-6, 0, 2, size.height),
      leftBoundaryPaint,
    );
  }

  @override
  bool shouldRepaint(_DebugTextPainter oldDelegate) {
    return textRectangles != oldDelegate.textRectangles;
  }
}

/// Forces [child] to take up all available width when the
/// incoming width constraint is bounded, otherwise the [child]
/// is sized by its intrinsic width.
///
/// If there is an existing widget that does this, get rid of this
/// widget and use the standard widget.
class _FillWidthIfConstrained extends SingleChildRenderObjectWidget {
  const _FillWidthIfConstrained({
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
