import 'package:flutter/services.dart';

/// A fake [HardwareKeyboard], which can be used to simulate keys being pressed while new
/// keys are pressed, e.g., `CMD` being pressed when the user then presses `C` to copy
/// or `V` to paste.
class FakeHardwareKeyboard extends HardwareKeyboard {
  FakeHardwareKeyboard({
    this.isAltPressed = false,
    this.isControlPressed = false,
    this.isMetaPressed = false,
    this.isShiftPressed = false,
  });

  @override
  bool isMetaPressed;
  @override
  bool isControlPressed;
  @override
  bool isAltPressed;
  @override
  bool isShiftPressed;

  @override
  bool isLogicalKeyPressed(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.shift || LogicalKeyboardKey.shiftLeft || LogicalKeyboardKey.shiftRight => isShiftPressed,
      LogicalKeyboardKey.alt || LogicalKeyboardKey.altLeft || LogicalKeyboardKey.altRight => isAltPressed,
      LogicalKeyboardKey.control ||
      LogicalKeyboardKey.controlLeft ||
      LogicalKeyboardKey.controlRight =>
        isControlPressed,
      LogicalKeyboardKey.meta || LogicalKeyboardKey.metaLeft || LogicalKeyboardKey.metaRight => isMetaPressed,
      _ => super.isLogicalKeyPressed(key)
    };
  }
}
