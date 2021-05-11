import 'package:flutter/services.dart';

/// Concrete version of [RawKeyEvent] used to manually simulate
/// a specific key event sent from Flutter.
///
/// [FakeRawKeyEvent] does not validate its configuration. It will
/// reflect whatever information you provide in the constructor, even
/// if that configuration couldn't exist in reality.
///
/// [FakeRawKeyEvent] might lack some controls or functionality. It's
/// a tool designed to meet the needs of specific tests. If new tests
/// require broader functionality, then that functionality should be
/// added to [FakeRawKeyEvent] and other associated classes.
class FakeRawKeyEvent extends RawKeyEvent {
  const FakeRawKeyEvent({
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
