import 'package:flutter/material.dart';
import 'package:super_text_layout/super_text_layout.dart';

class BlinkingCaret extends StatefulWidget {
  const BlinkingCaret({
    Key? key,
    this.controller,
    this.caretOffset,
    this.caretHeight,
    required this.color,
    required this.width,
    this.borderRadius = BorderRadius.zero,
    this.isTextEmpty = false,
    this.showCaret = true,
  }) : super(key: key);

  final BlinkController? controller;
  final double? caretHeight;
  final Offset? caretOffset;
  final Color color;
  final double width;
  final BorderRadius borderRadius;
  final bool isTextEmpty;
  final bool showCaret;

  @override
  BlinkingCaretState createState() => BlinkingCaretState();
}

class BlinkingCaretState extends State<BlinkingCaret> with SingleTickerProviderStateMixin {
  // Controls the blinking caret animation.
  late BlinkController _caretBlinkController;

  @override
  void initState() {
    super.initState();

    _caretBlinkController = widget.controller ??
        BlinkController(
          tickerProvider: this,
        );
    if (widget.caretOffset != null) {
      _caretBlinkController.jumpToOpaque();
    }
  }

  @override
  void didUpdateWidget(BlinkingCaret oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.caretOffset != oldWidget.caretOffset) {
      if (widget.caretOffset != null) {
        _caretBlinkController.jumpToOpaque();
      } else {
        _caretBlinkController.stopBlinking();
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _caretBlinkController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.caretHeight ?? 0),
      painter: _CaretPainter(
        blinkController: _caretBlinkController,
        caretHeight: widget.caretHeight,
        caretOffset: widget.caretOffset,
        width: widget.width,
        borderRadius: widget.borderRadius,
        caretColor: widget.color,
        isTextEmpty: widget.isTextEmpty,
        showCaret: widget.showCaret,
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({
    required this.blinkController,
    required this.caretHeight,
    required this.caretOffset,
    required this.width,
    required this.borderRadius,
    required this.caretColor,
    required this.isTextEmpty,
    required this.showCaret,
  })  : caretPaint = Paint()..color = caretColor,
        super(repaint: blinkController);

  final BlinkController blinkController;
  final double? caretHeight;
  final Offset? caretOffset;
  final double width;
  final BorderRadius borderRadius;
  final bool isTextEmpty;
  final bool showCaret;
  final Color caretColor;
  final Paint caretPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (!showCaret) {
      return;
    }

    if (caretOffset == null) {
      return;
    }

    caretPaint.color = caretColor.withOpacity(blinkController.opacity);

    final height = caretHeight?.roundToDouble() ?? size.height;

    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        caretOffset!.dx.roundToDouble(),
        caretOffset!.dy.roundToDouble(),
        caretOffset!.dx.roundToDouble() + width,
        caretOffset!.dy.roundToDouble() + height,
        topLeft: borderRadius.topLeft,
        topRight: borderRadius.topRight,
        bottomLeft: borderRadius.bottomLeft,
        bottomRight: borderRadius.bottomRight,
      ),
      caretPaint,
    );
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) {
    return caretHeight != oldDelegate.caretHeight ||
        caretOffset != oldDelegate.caretOffset ||
        isTextEmpty != oldDelegate.isTextEmpty ||
        showCaret != oldDelegate.showCaret ||
        width != oldDelegate.width ||
        borderRadius != oldDelegate.borderRadius ||
        caretColor != oldDelegate.caretColor;
  }
}
