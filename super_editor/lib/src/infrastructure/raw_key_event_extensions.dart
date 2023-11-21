import 'package:flutter/services.dart';

extension IsArrowKeyExtension on KeyEvent {
  bool get isArrowKeyPressed =>
      logicalKey == LogicalKeyboardKey.arrowUp ||
      logicalKey == LogicalKeyboardKey.arrowDown ||
      logicalKey == LogicalKeyboardKey.arrowLeft ||
      logicalKey == LogicalKeyboardKey.arrowRight;
}


extension IsKeyPressed on KeyEvent {
  bool isLogicalKeyPressed(LogicalKeyboardKey key) => HardwareKeyboard.instance.isLogicalKeyPressed(key);
  bool get isMetaPressed => HardwareKeyboard.instance.isMetaPressed;
  bool get isControlPressed => HardwareKeyboard.instance.isControlPressed;
  bool get isShiftPressed => HardwareKeyboard.instance.isShiftPressed;
  bool get isAltPressed => HardwareKeyboard.instance.isAltPressed;
}
