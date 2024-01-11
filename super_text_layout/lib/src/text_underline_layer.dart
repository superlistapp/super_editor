import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'text_layout.dart';

/// A [SuperText] layer that displays an underline beneath the text within a given
/// selection.
class TextUnderlineLayer extends StatefulWidget {
  const TextUnderlineLayer({
    Key? key,
    required this.textLayout,
    required this.underlines,
  }) : super(key: key);

  final TextLayout textLayout;
  final List<TextLayoutUnderline> underlines;

  @override
  State<TextUnderlineLayer> createState() => TextUnderlineLayerState();
}

@visibleForTesting
class TextUnderlineLayerState extends State<TextUnderlineLayer> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    if (widget.underlines.isEmpty) {
      return const SizedBox();
    }

    final paintableUnderlines = <_PaintableUnderline>[];
    for (final underline in widget.underlines) {
      // Convert selection bounding boxes into underline paths.
      final boxes = widget.textLayout.getBoxesForSelection(
        TextSelection(baseOffset: underline.range.start, extentOffset: underline.range.end),
        boxHeightStyle: BoxHeightStyle.max,
      );
      final lines = <Path>[];
      for (final box in boxes) {
        lines.add(
          Path()
            ..moveTo(box.left, box.bottom + underline.gap)
            ..lineTo(box.right, box.bottom + underline.gap),
        );
      }

      paintableUnderlines.add(
        _PaintableUnderline(
          color: underline.style.color,
          thickness: underline.style.thickness,
          capType: underline.style.capType,
          gap: underline.gap,
          lines: lines,
        ),
      );
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _UnderlinePainter(underlines: paintableUnderlines),
    );
  }
}

class TextLayoutUnderline {
  const TextLayoutUnderline({
    required this.style,
    required this.range,
    this.gap = 1,
  });

  final UnderlineStyle style;
  final TextRange range;
  final double gap;
}

class UnderlineStyle {
  const UnderlineStyle({
    this.color = const Color(0xFF000000),
    this.thickness = 2,
    this.capType = StrokeCap.square,
  });

  final Color color;
  final double thickness;
  final StrokeCap capType;

  UnderlineStyle copyWith({
    Color? color,
    double? thickness,
    StrokeCap? capType,
  }) {
    return UnderlineStyle(
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
      capType: capType ?? this.capType,
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter({
    required List<_PaintableUnderline> underlines,
  }) : _underlines = underlines;

  final List<_PaintableUnderline> _underlines;

  @override
  void paint(Canvas canvas, Size size) {
    if (_underlines.isEmpty) {
      return;
    }

    for (final underline in _underlines) {
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = underline.color
        ..strokeWidth = underline.thickness
        ..strokeCap = underline.capType;

      for (final line in underline.lines) {
        canvas.drawPath(line, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) {
    return !const DeepCollectionEquality().equals(_underlines, oldDelegate._underlines);
  }
}

class _PaintableUnderline {
  const _PaintableUnderline({
    required this.color,
    required this.thickness,
    required this.capType,
    required this.gap,
    required this.lines,
  });

  final Color color;
  final double thickness;
  final StrokeCap capType;
  final double gap;
  final List<Path> lines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PaintableUnderline &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          thickness == other.thickness &&
          capType == other.capType &&
          gap == other.gap &&
          const DeepCollectionEquality().equals(lines, other.lines);

  @override
  int get hashCode => color.hashCode ^ thickness.hashCode ^ capType.hashCode ^ gap.hashCode ^ lines.hashCode;
}
