import 'package:flutter/widgets.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// An Android-style blinking caret.
///
/// [AndroidTextFieldCaret] should be displayed on top of its corresponding
/// text, and it should be displayed at the same width and height as the
/// text. [AndroidTextFieldCaret] uses [textLayout] to calculate the
/// position of the caret from the top-left corner of the text and
/// then paints a blinking caret at that location.
class AndroidTextFieldCaret extends StatefulWidget {
  const AndroidTextFieldCaret({
    Key? key,
    required this.textLayout,
    required this.isTextEmpty,
    required this.emptyTextCaretHeight,
    required this.selection,
    required this.caretColor,
    this.caretWidth = 2.0,
    this.caretBorderRadius = BorderRadius.zero,
  }) : super(key: key);

  /// The laid-out text upon which the caret is painted.
  final TextLayout textLayout;

  /// Whether the text in the associated [SuperSelectableText] is empty.
  final bool isTextEmpty;

  /// The height of the caret when the text is empty, i.e., there is no
  /// text to measure.
  final double emptyTextCaretHeight;

  /// The current text selection of the associated [SuperSelectableText].
  final TextSelection selection;

  /// The color of the caret.
  final Color caretColor;

  /// The width of the caret.
  final double caretWidth;

  /// The border radius of the caret.
  final BorderRadius caretBorderRadius;

  @override
  _AndroidTextFieldCaretState createState() => _AndroidTextFieldCaretState();
}

class _AndroidTextFieldCaretState extends State<AndroidTextFieldCaret> with SingleTickerProviderStateMixin {
  late BlinkController _caretBlinkController;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = BlinkController(tickerProvider: this);
    if (widget.selection.extent.offset >= 0) {
      _caretBlinkController.jumpToOpaque();
    }
  }

  @override
  void didUpdateWidget(AndroidTextFieldCaret oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      if (widget.selection.extent.offset >= 0) {
        _caretBlinkController.jumpToOpaque();
      } else {
        _caretBlinkController.stopBlinking();
      }
    }
  }

  @override
  void dispose() {
    _caretBlinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AndroidCursorPainter(
        blinkController: _caretBlinkController,
        textLayout: widget.textLayout,
        width: widget.caretWidth,
        borderRadius: widget.caretBorderRadius,
        selection: widget.selection,
        caretColor: widget.caretColor,
        isTextEmpty: widget.isTextEmpty,
        emptyTextCaretHeight: widget.emptyTextCaretHeight,
      ),
    );
  }
}

/// A [CustomPainter] that paints an Android-style caret.
class AndroidCursorPainter extends CustomPainter {
  AndroidCursorPainter({
    required this.blinkController,
    required this.textLayout,
    required this.width,
    required this.borderRadius,
    required this.selection,
    required this.caretColor,
    required this.isTextEmpty,
    required this.emptyTextCaretHeight,
  })  : caretPaint = Paint()..color = caretColor,
        super(repaint: blinkController);

  final BlinkController blinkController;
  final TextLayout textLayout;
  final TextSelection selection;
  final double width;
  final BorderRadius borderRadius;
  final bool isTextEmpty;
  final double emptyTextCaretHeight;
  final Color caretColor;
  final Paint caretPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (selection.extentOffset < 0) {
      return;
    }

    if (!selection.isCollapsed) {
      return;
    }

    if (blinkController.opacity == 0.0) {
      return;
    }

    _drawCaret(canvas: canvas);
  }

  void _drawCaret({
    required Canvas canvas,
  }) {
    caretPaint.color = caretColor.withOpacity(blinkController.opacity);

    double caretHeight = textLayout.getHeightForCaret(selection.extent) ?? emptyTextCaretHeight;
    final caretOffset = textLayout.getOffsetAtPosition(selection.extent);

    if (borderRadius == BorderRadius.zero) {
      canvas.drawRect(
        Rect.fromLTWH(
          caretOffset.dx.roundToDouble() - (width / 2),
          caretOffset.dy.roundToDouble(),
          width,
          caretHeight.roundToDouble(),
        ),
        caretPaint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          caretOffset.dx.roundToDouble(),
          caretOffset.dy.roundToDouble(),
          caretOffset.dx.roundToDouble() + width,
          caretOffset.dy.roundToDouble() + caretHeight.roundToDouble(),
          topLeft: borderRadius.topLeft,
          topRight: borderRadius.topRight,
          bottomLeft: borderRadius.bottomLeft,
          bottomRight: borderRadius.bottomRight,
        ),
        caretPaint,
      );
    }
  }

  @override
  bool shouldRepaint(AndroidCursorPainter oldDelegate) {
    return textLayout != oldDelegate.textLayout ||
        selection != oldDelegate.selection ||
        isTextEmpty != oldDelegate.isTextEmpty;
  }
}
