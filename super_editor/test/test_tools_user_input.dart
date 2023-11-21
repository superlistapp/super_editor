import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkify/linkify.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/src/infrastructure/key_event_extensions.dart';

final inputSourceVariant = ValueVariant({
  TextInputSource.keyboard,
  TextInputSource.ime,
});

final inputAndGestureVariants = ValueVariant<InputAndGestureTuple>(
  {
    const InputAndGestureTuple(TextInputSource.keyboard, DocumentGestureMode.mouse),
    const InputAndGestureTuple(TextInputSource.keyboard, DocumentGestureMode.iOS),
    const InputAndGestureTuple(TextInputSource.keyboard, DocumentGestureMode.android),
    const InputAndGestureTuple(TextInputSource.ime, DocumentGestureMode.mouse),
    const InputAndGestureTuple(TextInputSource.ime, DocumentGestureMode.iOS),
    const InputAndGestureTuple(TextInputSource.ime, DocumentGestureMode.android),
  },
);

/// A combination of an [inputSource] and a [gestureMode].
class InputAndGestureTuple {
  const InputAndGestureTuple(this.inputSource, this.gestureMode);

  final TextInputSource inputSource;
  final DocumentGestureMode gestureMode;

  @override
  String toString() {
    return '${inputSource.name} Input Source & ${gestureMode.name} Gesture Mode';
  }
}

/// A [TextInputConnection] that tracks the number of content updates, to verify
/// within tests.
class ImeConnectionWithUpdateCount extends TextInputConnectionDecorator {
  ImeConnectionWithUpdateCount(TextInputConnection client) : super(client);

  int get contentUpdateCount => _contentUpdateCount;
  int _contentUpdateCount = 0;

  @override
  void setEditingState(TextEditingValue value) {
    super.setEditingState(value);
    _contentUpdateCount += 1;
  }
}

class FakeHardwareKeyboard extends HardwareKeyboard {
  FakeHardwareKeyboard({
    this.isAltPressed = false,
    this.isControlPressed = false,
    this.isMetaPressed = false,
    this.isShiftPressed = false,
  });

  @override
  final bool isMetaPressed;
  @override
  final bool isControlPressed;
  @override
  final bool isAltPressed;
  @override
  final bool isShiftPressed;

  @override
  bool isLogicalKeyPressed(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.shift || LogicalKeyboardKey.shiftLeft || LogicalKeyboardKey.shiftRight => isShiftPressed,
      LogicalKeyboardKey.alt || LogicalKeyboardKey.altLeft || LogicalKeyboardKey.altRight => isAltPressed,
      LogicalKeyboardKey.control || LogicalKeyboardKey.controlLeft || LogicalKeyboardKey.controlRight => isControlPressed,
      LogicalKeyboardKey.meta || LogicalKeyboardKey.metaLeft || LogicalKeyboardKey.metaRight => isMetaPressed,
      _ => HardwareKeyboard.instance.isLogicalKeyPressed(key)
    };
  }
}
