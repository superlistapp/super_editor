import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates common key combinations on a hardware keyboard.
extension CommonKeyCombos on WidgetTester {
  Future<void> pressEnter(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  Future<void> pressCmdEnter(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();
  }

  Future<void> pressNumpadEnter(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();
  }

  Future<void> pressCmdNumpadEnter(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();
  }

  Future<void> pressLeftArrow(WidgetTester tester, {bool shift = false}) async {
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }

    await tester.pumpAndSettle();
  }

  Future<void> pressAltLeftArrow(WidgetTester tester, {bool shift = false}) async {
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }

    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);

    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }

    await tester.pumpAndSettle();
  }

  Future<void> pressCmdLeftArrow(WidgetTester tester, {bool shift = false}) async {
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);

    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }

    await tester.pumpAndSettle();
  }

  Future<void> pressRightArrow(WidgetTester tester, {bool shift = false}) async {
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }

    await tester.pumpAndSettle();
  }

  Future<void> pressAltRightArrow(WidgetTester tester, {bool shift = false}) async {
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }

    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);

    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }

    await tester.pumpAndSettle();
  }

  Future<void> pressCmdRightArrow(WidgetTester tester, {bool shift = false}) async {
    if (shift) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);

    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }

    await tester.pumpAndSettle();
  }
}

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
