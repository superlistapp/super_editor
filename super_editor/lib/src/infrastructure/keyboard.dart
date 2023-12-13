// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';

enum ExecutionInstruction {
  /// The handler has no relation to the key event and
  /// took no action.
  ///
  /// Other handlers should be given a chance to act on
  /// the key press.
  continueExecution,

  /// The handler recognized the key event but chose to
  /// take no action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **should** bubble up the tree to
  /// (possibly) be handled by other keyboard/shortcut
  /// listeners.
  blocked,

  /// The handler recognized the key event and chose to
  /// take an action.
  ///
  /// No other handler should receive the key event.
  ///
  /// The key event **shouldn't** bubble up the tree.
  haltExecution,
}

extension PrimaryShortcutKey on KeyEvent {
  bool get isPrimaryShortcutKeyPressed =>
      (CurrentPlatform.isApple && HardwareKeyboard.instance.isMetaPressed) || //
      (!CurrentPlatform.isApple && HardwareKeyboard.instance.isControlPressed);
}

/// Whether the given [character] should be ignored when it's received within
/// a [KeyEvent] on web.
///
/// Flutter has had issues where [KeyEvent]s on web report `character` values that
/// hold the name of the given key, e.g. "Scroll Lock". The `character` for those
/// events should be `null`. This method determines whether such a character should
/// be ignored.
bool isKeyEventCharacterBlacklisted(String? character) {
  if (!kIsWeb || character == null) {
    return false;
  }

  return isCharacterBlacklisted(character);
}

/// This method is the implementation for [isKeyEventCharacterBlacklisted], but without
/// the `kIsWeb` check, so that the behavior can be unit tested.
///
/// Examples of what's permitted: "a", "2", "234", "D##", "áé"
///
/// Examples of what's prohibited: "F1", "Scroll Lock"
@visibleForTesting
bool isCharacterBlacklisted(String character) {
  return character.length > 1 && _isUpperCase(character.codeUnits.first) && _isAllAlphaNumeric(character.codeUnits);
}

const _ascii_A = 0x41;
const _ascii_Z = 0x5a;
const _ascii_a = 0x61;
const _ascii_z = 0x7a;
const _ascii_0 = 0x30;
const _ascii_9 = 0x39;
const _ascii_space = 0x20;

/// Whether the given [codeUnit] refers to an ASCII alphabet character
/// that's capitalized.
bool _isUpperCase(int codeUnit) {
  return (_ascii_A <= codeUnit) && (codeUnit <= _ascii_Z);
}

/// Whether any of the given [codeUnits], after the first code-unit, refer to an
/// ASCII symbol, i.e., a character that's not alpha-numeric, e.g., "#", "?".
bool _isAllAlphaNumeric(List<int> codeUnits) {
  for (final codeUnit in codeUnits) {
    if (!_isAlphaNumeric(codeUnit)) {
      return false;
    }
  }
  return true;
}

/// Whether the given [codeUnit] refers to an ASCII alpha-numeric
/// character, e.g., "A", "a", "1", " ".
bool _isAlphaNumeric(int codeUnit) {
  return codeUnit >= _ascii_A && codeUnit <= _ascii_Z ||
      codeUnit >= _ascii_a && codeUnit <= _ascii_z ||
      codeUnit >= _ascii_0 && codeUnit <= _ascii_9 ||
      codeUnit == _ascii_space;
}
