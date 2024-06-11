import 'package:flutter/painting.dart';

class OuterBoxShadow extends BoxShadow {
  const OuterBoxShadow({
    super.color,
    super.offset,
    super.blurRadius,
    super.spreadRadius,
  });

  @override
  Paint toPaint() {
    return Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, blurSigma);
  }
}
