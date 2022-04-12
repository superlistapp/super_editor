import 'package:flutter/material.dart';
import 'package:super_text/super_text.dart';

class TextLayoutUserLabel extends StatelessWidget {
  const TextLayoutUserLabel({
    Key? key,
    this.textLayout,
    required this.style,
    required this.label,
    this.position,
  }) : super(key: key);

  final TextLayout? textLayout;
  final UserLabelStyle style;
  final String label;
  final TextPosition? position;

  @override
  Widget build(BuildContext context) {
    if (textLayout == null || position == null) {
      return const SizedBox();
    }

    final offset = textLayout!.getOffsetForCaret(position!) + const Offset(2, 0);
    return Stack(
      children: [
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: _UserLabel(
            style: style,
            label: label,
          ),
        ),
      ],
    );
  }
}

class _UserLabel extends StatelessWidget {
  const _UserLabel({
    Key? key,
    required this.style,
    required this.label,
  }) : super(key: key);

  final UserLabelStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: style.shape,
        color: style.color,
      ),
      padding: style.padding,
      child: Text(label),
    );
  }
}

class UserLabelStyle {
  const UserLabelStyle({
    required this.color,
    required this.shape,
    this.padding = const EdgeInsets.only(top: 2, bottom: 6, left: 8, right: 8),
    this.labelStyle = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    ),
  });

  final Color color;
  final ShapeBorder shape;
  final EdgeInsets padding;
  final TextStyle labelStyle;
}
