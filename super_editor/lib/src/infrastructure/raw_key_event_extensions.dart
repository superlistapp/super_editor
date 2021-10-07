import 'package:flutter/services.dart';

extension IsArrowKeyExtension on RawKeyEvent {
  bool get isArrowKeyPressed =>
      logicalKey == LogicalKeyboardKey.arrowUp ||
      logicalKey == LogicalKeyboardKey.arrowDown ||
      logicalKey == LogicalKeyboardKey.arrowLeft ||
      logicalKey == LogicalKeyboardKey.arrowRight;
}
