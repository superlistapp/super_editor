import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SelectableText extends StatefulWidget {
  const SelectableText({
    @required Key key,
    this.text = '',
    this.textSelection = const TextSelection.collapsed(offset: -1),
    this.hasCursor = false,
    this.style,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final String text;
  final TextSelection textSelection;
  final bool hasCursor;
  final TextStyle style;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  SelectableTextState createState() => SelectableTextState();
}

class SelectableTextState extends State<SelectableText> with SingleTickerProviderStateMixin implements TextLayout {
  final GlobalKey _textKey = GlobalKey();

  CursorBlinkController _cursorBlinkController;

  @override
  void initState() {
    super.initState();

    _cursorBlinkController = CursorBlinkController(
      tickerProvider: this,
    );
    _cursorBlinkController.caretPosition = widget.textSelection?.extent;
  }

  @override
  void didUpdateWidget(SelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cursorBlinkController.caretPosition = widget.textSelection?.extent;
  }

  @override
  void dispose() {
    _cursorBlinkController.dispose();
    super.dispose();
  }

  RenderParagraph get _renderParagraph => _textKey.currentContext?.findRenderObject() as RenderParagraph;

  TextPosition getPositionAtOffset(Offset localOffset) {
    return _renderParagraph.getPositionForOffset(localOffset);
  }

  Offset getOffsetForPosition(TextPosition position) {
    return _renderParagraph.getOffsetForCaret(position, Rect.zero);
  }

  TextPosition getPositionAtStartOfLine({
    TextPosition currentPosition,
  }) {
    final positionOffset = _renderParagraph.getOffsetForCaret(currentPosition, Rect.zero);
    final endOfLineOffset = Offset(0, positionOffset.dy);
    return _renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  TextPosition getPositionAtEndOfLine({
    TextPosition currentPosition,
  }) {
    final positionOffset = _renderParagraph.getOffsetForCaret(currentPosition, Rect.zero);
    final endOfLineOffset = Offset(_renderParagraph.size.width, positionOffset.dy);
    return _renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  TextPosition getPositionOneLineUp({
    TextPosition currentPosition,
  }) {
    // TODO: use TextPainter to get real line height.
    final lineHeight = widget.style.fontSize * widget.style.height;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        _renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineUpOffset = currentSelectionOffset - Offset(0, lineHeight);

    if (oneLineUpOffset.dy < 0) {
      // The first line is selected. There is no line above this.
      return null;
    }

    return _renderParagraph.getPositionForOffset(oneLineUpOffset);
  }

  TextPosition getPositionOneLineDown({
    TextPosition currentPosition,
  }) {
    // TODO: use TextPainter to get real line height.
    final lineHeight = widget.style.fontSize * widget.style.height;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        _renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineDownOffset = currentSelectionOffset + Offset(0, lineHeight);

    if (oneLineDownOffset.dy > _renderParagraph.size.height) {
      // The last line is selected. There is no line below that.
      return null;
    }

    return _renderParagraph.getPositionForOffset(oneLineDownOffset);
  }

  TextPosition getPositionInFirstLineAtX(double x) {
    return getPositionAtOffset(
      Offset(x, 0),
    );
  }

  TextPosition getPositionInLastLineAtX(double x) {
    return getPositionAtOffset(
      Offset(x, _renderParagraph.size.height),
    );
  }

  TextSelection getWordSelectionAt(TextPosition position) {
    final wordRange = _renderParagraph.getWordBoundary(position);
    return TextSelection(
      baseOffset: wordRange.start,
      extentOffset: wordRange.end,
    );
  }

  bool isTextAtOffset(Offset localOffset) {
    final textOffset = _renderParagraph.getPositionForOffset(localOffset);

    if (textOffset != null) {
      List<TextBox> boxes = _renderParagraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: widget.text.length,
        ),
      );

      for (final box in boxes) {
        if (box.toRect().contains(localOffset)) {
          return true;
        }
      }
    }

    return false;
  }

  // TODO: can we avoid exposing RenderObject knowledge? If not, maybe we have
  //       two different roles combined into one. Perhaps an EditorComponent and
  //       a TextLayout.
  Rect calculateLocalOverlap({
    Rect region,
    RenderObject ancestorCoordinateSpace,
  }) {
    final contentOffset = _renderParagraph.localToGlobal(Offset.zero, ancestor: ancestorCoordinateSpace);
    final textRect = contentOffset & _renderParagraph.size;

    if (region.overlaps(textRect)) {
      // Report the overlap in our local coordinate space.
      return region.translate(-contentOffset.dx, -contentOffset.dy);
    } else {
      return null;
    }
  }

  @override
  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset) {
    final contentHeight = _renderParagraph.size.height;
    final textLength = widget.text.length;

    // We don't know whether the base offset is higher or lower than the
    // extent offset. Regardless, if either offset is above the top of
    // the text then that text position should be 0. If either offset
    // is below the bottom of the text then that offset should be the
    // total length of the text.
    final basePosition = baseOffset.dy < 0
        ? 0
        : baseOffset.dy > contentHeight
            ? textLength
            : _renderParagraph.getPositionForOffset(baseOffset).offset;
    final extentPosition = extentOffset.dy < 0
        ? 0
        : extentOffset.dy > contentHeight
            ? textLength
            : _renderParagraph.getPositionForOffset(extentOffset).offset;

    final selection = TextSelection(
      baseOffset: basePosition,
      extentOffset: extentPosition,
    );

    return selection;
  }

  @override
  Widget build(BuildContext context) {
    if (_renderParagraph == null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {
          // Force another frame so that we can use the renderParagraph.
        });
      });
    }

    final desiredTextStyle = widget.style ?? Theme.of(context).textTheme.bodyText1;
    final textStyle = widget.showDebugPaint
        ? desiredTextStyle.copyWith(
            color: const Color(0xFF444444),
          )
        : desiredTextStyle;

    return Stack(
      children: [
        if (widget.showDebugPaint)
          Positioned.fill(
            child: CustomPaint(
              painter: DebugTextPainter(
                paragraph: _renderParagraph,
                text: widget.text,
              ),
              size: Size.infinite,
            ),
          ),
        CustomPaint(
          painter: TextSelectionPainter(
              text: widget.text,
              renderParagraph: _renderParagraph,
              selection: widget.textSelection,
              emptySelectionHeight: widget.style.fontSize * widget.style.height,
              highlightWhenEmpty: widget.highlightWhenEmpty,
              selectionColor: widget.showDebugPaint ? Colors.lightGreenAccent : Colors.lightBlueAccent),
        ),
        Text(
          widget.text,
          key: _textKey,
          style: textStyle,
        ),
        CustomPaint(
          painter: CursorPainter(
            blinkController: _cursorBlinkController,
            paragraph: _renderParagraph,
            cursorOffset: widget.textSelection != null ? widget.textSelection.extentOffset : -1,
            lineHeight: widget.style.fontSize * widget.style.height,
            caretHeight: (widget.style.fontSize * widget.style.height) * (widget.showDebugPaint ? 1.2 : 0.8),
            caretColor: widget.showDebugPaint ? Colors.red : Colors.black,
            isTextEmpty: widget.text == null || widget.text.isEmpty,
            showCursor: widget.hasCursor,
          ),
        ),
      ],
    );
  }
}

abstract class TextLayout {
  TextPosition getPositionAtOffset(Offset localOffset);

  Offset getOffsetForPosition(TextPosition position);

  TextPosition getPositionAtStartOfLine({
    TextPosition currentPosition,
  });

  TextPosition getPositionAtEndOfLine({
    TextPosition currentPosition,
  });

  TextPosition getPositionOneLineUp({
    TextPosition currentPosition,
  });

  TextPosition getPositionOneLineDown({
    TextPosition currentPosition,
  });

  TextPosition getPositionInFirstLineAtX(double x);

  TextPosition getPositionInLastLineAtX(double x);

  bool isTextAtOffset(Offset localOffset);

  Rect calculateLocalOverlap({
    Rect region,
    RenderObject ancestorCoordinateSpace,
  });

  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset);
}

class TextSelectionPainter extends CustomPainter {
  TextSelectionPainter({
    @required this.text,
    @required this.renderParagraph,
    @required this.selection,
    @required this.emptySelectionHeight,
    @required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : selectionPaint = Paint()..color = selectionColor;

  final String text;
  final RenderParagraph renderParagraph;
  final TextSelection selection;
  final emptySelectionHeight;
  // When true, an empty, collapsed selection will be highlighted
  // for the purpose of showing a highlighted empty line.
  final bool highlightWhenEmpty;
  final Color selectionColor;
  final Paint selectionPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (renderParagraph == null || selection == null) {
      return;
    }

    if (text.isEmpty && highlightWhenEmpty && selection.isCollapsed && selection.extentOffset == 0) {
      //&& highlightWhenEmpty) {
      // This is an empty paragraph, which is selected. Paint a small selection.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 5, 20),
        selectionPaint,
      );
    }

    final selectionBoxes = renderParagraph.getBoxesForSelection(selection);

    for (final box in selectionBoxes) {
      final rect = box.toRect();
      canvas.drawRect(
        // Note: If the rect has no width then we've selected an empty line. Give
        //       that line a slight width for visibility.
        rect.width > 0 ? rect : Rect.fromLTWH(rect.left, rect.top, 5, rect.height),
        selectionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TextSelectionPainter oldDelegate) {
    return renderParagraph != oldDelegate.renderParagraph || selection != oldDelegate.selection;
  }
}

class CursorPainter extends CustomPainter {
  CursorPainter({
    @required this.blinkController,
    @required this.paragraph,
    @required this.cursorOffset,
    @required this.caretHeight,
    @required this.lineHeight,
    @required this.caretColor,
    @required this.isTextEmpty,
    @required this.showCursor,
  })  : caretPaint = Paint()..color = caretColor,
        super(repaint: blinkController);

  final CursorBlinkController blinkController;
  final RenderParagraph paragraph;
  final int cursorOffset;
  final double caretHeight; // TODO: find a way to get this from the TextPainter, which is the correct place to get it.
  final double lineHeight; // TODO: this should probably also come from the TextPainter.
  final bool isTextEmpty;
  final bool showCursor;
  final Color caretColor;
  final Paint caretPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (!showCursor || paragraph == null || cursorOffset == null) {
      return;
    }

    caretPaint..color = caretColor.withOpacity(blinkController.opacity);

    Offset caretOffset = isTextEmpty
        ? Offset(0, (lineHeight - caretHeight) / 2)
        : paragraph.getOffsetForCaret(TextPosition(offset: cursorOffset), Rect.zero);
    caretOffset = caretOffset.translate(0, -(caretHeight - lineHeight) / 2);
    canvas.drawRect(
      Rect.fromLTWH(
        caretOffset.dx.roundToDouble(),
        caretOffset.dy.roundToDouble(),
        2,
        caretHeight.roundToDouble(),
      ),
      caretPaint,
    );
  }

  @override
  bool shouldRepaint(CursorPainter oldDelegate) {
    return paragraph != oldDelegate.paragraph ||
        cursorOffset != oldDelegate.cursorOffset ||
        isTextEmpty != oldDelegate.isTextEmpty ||
        showCursor != oldDelegate.showCursor;
  }
}

class CursorBlinkController with ChangeNotifier {
  CursorBlinkController({
    @required TickerProvider tickerProvider,
    Duration flashPeriod = const Duration(milliseconds: 500),
  }) : _animationController = AnimationController(
          vsync: tickerProvider,
          duration: flashPeriod,
        ) {
    print('Creating CursorBlinkController');
    _animationController
      ..addListener(() {
        notifyListeners();
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  AnimationController _animationController;
  double get opacity => 1.0 - _animationController.value.roundToDouble();

  TextPosition _caretPosition;
  set caretPosition(TextPosition newPosition) {
    if (newPosition != _caretPosition) {
      _caretPosition = newPosition;

      if (newPosition == null) {
        _animationController.stop();
      } else {
        _animationController.forward(from: 0.0);
      }
    }
  }
}

class DebugTextPainter extends CustomPainter {
  DebugTextPainter({
    @required this.paragraph,
    @required this.text,
  });

  final RenderParagraph paragraph;
  final String text;
  final Paint leftBoundaryPaint = Paint()..color = const Color(0xFFCCCCCC);
  final Paint textBoxesPaint = Paint()
    ..color = const Color(0xFFCCCCCC)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (paragraph == null || text == null) {
      return;
    }

    // Paint boxes.
    final textBoxes = paragraph.getBoxesForSelection(TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    ));

    for (final box in textBoxes) {
      final rect = box.toRect();
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
  bool shouldRepaint(DebugTextPainter oldDelegate) {
    return paragraph != oldDelegate.paragraph || text != oldDelegate.text;
  }
}
