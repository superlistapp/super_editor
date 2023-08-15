import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

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

/// Concrete version of [RawKeyEvent] used to manually simulate
/// a specific key event sent from Flutter.
///
/// [FakeRawKeyDownEvent] does not validate its configuration. It will
/// reflect whatever information you provide in the constructor, even
/// if that configuration couldn't exist in reality.
///
/// [FakeRawKeyDownEvent] might lack some controls or functionality. It's
/// a tool designed to meet the needs of specific tests. If new tests
/// require broader functionality, then that functionality should be
/// added to [FakeRawKeyDownEvent] and other associated classes.
class FakeRawKeyDownEvent extends RawKeyDownEvent {
  const FakeRawKeyDownEvent({
    required RawKeyEventData data,
    String? character,
  }) : super(data: data, character: character);

  @override
  bool get isMetaPressed => data.isMetaPressed;

  @override
  bool get isAltPressed => data.isAltPressed;

  @override
  bool get isControlPressed => data.isControlPressed;

  @override
  bool get isShiftPressed => data.isShiftPressed;
}

/// Concrete version of [FakeRawKeyEventData] used to manually simulate
/// a specific key event sent from Flutter.
///
/// [FakeRawKeyEventData] does not validate its configuration. It will
/// reflect whatever information you provide in the constructor, even
/// if that configuration couldn't exist in reality.
///
/// [FakeRawKeyEventData] might lack some controls or functionality. It's
/// a tool designed to meet the needs of specific tests. If new tests
/// require broader functionality, then that functionality should be
/// added to [FakeRawKeyEventData] and other associated classes.
class FakeRawKeyEventData extends RawKeyEventData {
  const FakeRawKeyEventData({
    this.keyLabel = 'fake_key_event',
    required this.logicalKey,
    required this.physicalKey,
    this.isMetaPressed = false,
    this.isControlPressed = false,
    this.isAltPressed = false,
    this.isModifierKeyPressed = false,
    this.isShiftPressed = false,
  });

  @override
  final String keyLabel;

  @override
  final LogicalKeyboardKey logicalKey;

  @override
  final PhysicalKeyboardKey physicalKey;

  final bool isModifierKeyPressed;

  @override
  final bool isMetaPressed;

  @override
  final bool isAltPressed;

  @override
  final bool isControlPressed;

  @override
  final bool isShiftPressed;

  @override
  bool isModifierPressed(ModifierKey key, {KeyboardSide side = KeyboardSide.any}) {
    return isModifierKeyPressed;
  }

  @override
  KeyboardSide? getModifierSide(ModifierKey key) {
    throw UnimplementedError();
  }
}
