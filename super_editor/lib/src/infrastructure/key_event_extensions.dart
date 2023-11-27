import 'package:flutter/services.dart';

extension IsArrowKeyExtension on KeyEvent {
  bool get isArrowKeyPressed =>
      logicalKey == LogicalKeyboardKey.arrowUp ||
      logicalKey == LogicalKeyboardKey.arrowDown ||
      logicalKey == LogicalKeyboardKey.arrowLeft ||
      logicalKey == LogicalKeyboardKey.arrowRight;
}
