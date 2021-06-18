import 'package:flutter/painting.dart';

class OuterBoxShadow extends BoxShadow {
  const OuterBoxShadow({
    Color color = const Color(0xFF000000),
    Offset offset = Offset.zero,
    double blurRadius = 0.0,
    double spreadRadius = 0.0,
  }) : super(color: color, offset: offset, blurRadius: blurRadius, spreadRadius: spreadRadius);

  @override
  Paint toPaint() {
    return Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, blurSigma);
  }
}
