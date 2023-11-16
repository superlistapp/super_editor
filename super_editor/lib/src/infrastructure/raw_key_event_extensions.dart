import 'package:flutter/services.dart';

extension IsArrowKeyExtension on KeyEvent {
  bool get isArrowKeyPressed =>
      logicalKey == LogicalKeyboardKey.arrowUp ||
      logicalKey == LogicalKeyboardKey.arrowDown ||
      logicalKey == LogicalKeyboardKey.arrowLeft ||
      logicalKey == LogicalKeyboardKey.arrowRight;
}


extension IsKeyPressed on KeyEvent {
  bool isLogicalKeyPressed(LogicalKeyboardKey key) {
    return HardwareKeyboard.instance.logicalKeysPressed.contains(key);
  }

  bool get isMetaPressed {
    return isLogicalKeyPressed(LogicalKeyboardKey.metaLeft) ||
        isLogicalKeyPressed(LogicalKeyboardKey.metaRight);
  }

  bool get isControlPressed {
    return isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
        isLogicalKeyPressed(LogicalKeyboardKey.controlRight);
  }

  bool get isShiftPressed {
    return isLogicalKeyPressed(LogicalKeyboardKey.shiftLeft) ||
        isLogicalKeyPressed(LogicalKeyboardKey.shiftRight);
  }

  bool get isAltPressed {
    return isLogicalKeyPressed(LogicalKeyboardKey.altLeft) ||
        isLogicalKeyPressed(LogicalKeyboardKey.altRight);
  }
}
