import 'package:flutter/material.dart';

/// Paints a rectangle border around the given `selectionRect`.
class DragRectanglePainter extends CustomPainter {
  DragRectanglePainter({
    this.selectionRect,
  });

  final Rect selectionRect;
  final Paint _selectionBorderPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke;
  final Paint _selectionFillPaint = Paint()
    ..color = Colors.red.withOpacity(0.1)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect != null) {
      canvas.drawRect(selectionRect, _selectionFillPaint);
      canvas.drawRect(selectionRect, _selectionBorderPaint);
    }
  }

  @override
  bool shouldRepaint(DragRectanglePainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}
