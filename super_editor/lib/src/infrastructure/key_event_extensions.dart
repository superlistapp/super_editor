import 'package:flutter/services.dart';

extension IsArrowKeyExtension on KeyEvent {
  bool get isArrowKeyPressed =>
      logicalKey == LogicalKeyboardKey.arrowUp ||
      logicalKey == LogicalKeyboardKey.arrowDown ||
      logicalKey == LogicalKeyboardKey.arrowLeft ||
      logicalKey == LogicalKeyboardKey.arrowRight;
}

extension IsKeyPressed on KeyEvent {
  static HardwareKeyboard get instance => _testInstance ?? HardwareKeyboard.instance;
  static HardwareKeyboard? _testInstance;

  /// Allows setting of a keyboard to use during testing instead of
  /// [HardwareKeyboard.instance].
  ///
  /// Defaults to null, and resetting to null will revert to using
  /// [HardwareKeyboard.instance].
  static setTestKeyboard(HardwareKeyboard? keyboard) {
    _testInstance = keyboard;
  }

  bool isLogicalKeyPressed(LogicalKeyboardKey key) => instance.isLogicalKeyPressed(key);
  bool get isMetaPressed => instance.isMetaPressed;
  bool get isControlPressed => instance.isControlPressed;
  bool get isShiftPressed => instance.isShiftPressed;
  bool get isAltPressed => instance.isAltPressed;
}
