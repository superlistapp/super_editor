import 'package:flutter/widgets.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// An iOS-style blinking caret.
///
/// [IOSTextFieldCaret] should be displayed on top of its corresponding
/// text, and it should be displayed at the same width and height as the
/// text. [IOSTextFieldCaret] uses [textLayout] to calculate the
/// position of the caret from the top-left corner of the text and
/// then paints a blinking caret at that location.
class IOSTextFieldCaret extends StatefulWidget {
  const IOSTextFieldCaret({
    Key? key,
    required this.textLayout,
    required this.isTextEmpty,
    required this.selection,
    required this.caretColor,
    this.caretWidth = 2.0,
    this.caretBorderRadius = BorderRadius.zero,
  }) : super(key: key);

  final TextLayout textLayout;
  final bool isTextEmpty;
  final TextSelection selection;
  final Color caretColor;
  final double caretWidth;
  final BorderRadius caretBorderRadius;

  @override
  _IOSTextFieldCaretState createState() => _IOSTextFieldCaretState();
}

class _IOSTextFieldCaretState extends State<IOSTextFieldCaret> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(IOSTextFieldCaret oldWidget) {
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
      painter: _IOSCursorPainter(
        blinkController: _caretBlinkController,
        textLayout: widget.textLayout,
        width: widget.caretWidth,
        borderRadius: widget.caretBorderRadius,
        selection: widget.selection,
        caretColor: widget.caretColor,
        isTextEmpty: widget.isTextEmpty,
      ),
    );
  }
}

/// [CustomPainter] that renders an iOS-style caret.
///
/// On iOS, the caret is a thin, tall rectangle.
class _IOSCursorPainter extends CustomPainter {
  _IOSCursorPainter({
    required this.blinkController,
    required this.textLayout,
    required this.width,
    required this.borderRadius,
    required this.selection,
    required this.caretColor,
    required this.isTextEmpty,
  })  : caretPaint = Paint(),
        super(repaint: blinkController);

  final BlinkController blinkController;
  final TextLayout textLayout;
  final TextSelection selection;
  final double width;
  final BorderRadius borderRadius;
  final bool isTextEmpty;
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

    _drawCaret(canvas);
  }

  void _drawCaret(Canvas canvas) {
    caretPaint.color = caretColor.withOpacity(blinkController.opacity);

    final textPosition = selection.extent;
    double caretHeight = textLayout.getCharacterBox(textPosition)?.toRect().height ?? 0.0;
    caretHeight = caretHeight > 0 ? caretHeight : textLayout.getHeightForCaret(textPosition) ?? 0;
    caretHeight = caretHeight > 0 ? caretHeight : textLayout.getLineHeightAtPosition(textPosition);

    Offset caretOffset = isTextEmpty ? Offset.zero : textLayout.getOffsetAtPosition(textPosition);

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
  bool shouldRepaint(_IOSCursorPainter oldDelegate) {
    return blinkController != oldDelegate.blinkController ||
        textLayout != oldDelegate.textLayout ||
        selection != oldDelegate.selection ||
        width != oldDelegate.width ||
        borderRadius != oldDelegate.borderRadius ||
        isTextEmpty != oldDelegate.isTextEmpty ||
        caretColor != oldDelegate.caretColor;
  }
}
