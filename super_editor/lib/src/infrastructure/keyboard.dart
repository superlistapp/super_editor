// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'platform_detector.dart';

/// Widget that responds to keyboard events for a given [focusNode] without
/// re-parenting the [focusNode].
///
/// The traditional [Focus] widget provides an `onKey` property, but that widget
/// automatically re-parents the [FocusNode] based on the structure of the widget
/// tree. Re-parenting is a problem in some situations, e.g., a popover toolbar
/// that appears while editing a document. The toolbar and the document are on
/// different branches of the widget tree, but they need to share focus. That shared
/// focus is impossible when the [Focus] widget forces re-parenting. The
/// [KeyboardFocus] widget provides an [onKey] property without re-parenting the
/// given [focusNode].
class KeyboardFocus extends StatefulWidget {
  const KeyboardFocus({
    Key? key,
    required this.focusNode,
    required this.onKey,
    required this.child,
  }) : super(key: key);

  /// The [FocusNode] that sends key events to [onKey].
  final FocusNode focusNode;

  /// The callback invoked whenever [focusNode] receives key events.
  final FocusOnKeyCallback onKey;

  /// The child of this widget.
  final Widget child;

  @override
  State<KeyboardFocus> createState() => _KeyboardFocusState();
}

class _KeyboardFocusState extends State<KeyboardFocus> {
  late FocusAttachment _keyboardFocusAttachment;

  @override
  void initState() {
    super.initState();
    _keyboardFocusAttachment = widget.focusNode.attach(context, onKey: widget.onKey);
  }

  @override
  void didUpdateWidget(KeyboardFocus oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode || widget.onKey != oldWidget.onKey) {
      _keyboardFocusAttachment.detach();
      _keyboardFocusAttachment = widget.focusNode.attach(context, onKey: widget.onKey);
    }
  }

  @override
  void dispose() {
    _keyboardFocusAttachment.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

extension PrimaryShortcutKey on RawKeyEvent {
  bool get isPrimaryShortcutKeyPressed =>
      (Platform.instance.isMac && isMetaPressed) || (!Platform.instance.isMac && isControlPressed);
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
