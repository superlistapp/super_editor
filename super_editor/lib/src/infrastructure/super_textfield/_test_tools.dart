import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'super_textfield.dart';

extension SuperTextFieldTesting on WidgetTester {
  Future<void> tapAtSuperTextPosition(Finder finder, int offset) async {
    final fieldFinder = _findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperDesktopTextField) {
      final didTap = await _tapAtTextPositionOnDesktop(state<SuperDesktopTextFieldState>(fieldFinder), offset);
      if (!didTap) {
        throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
      }
      return;
    }

    if (match is SuperAndroidTextField) {
      throw Exception("Entering text on an Android SuperTextField is not yet supported");
    }

    if (match is SuperIOSTextField) {
      throw Exception("Entering text on an iOS SuperTextField is not yet supported");
    }

    throw Exception("Couldn't find a SuperTextField with the given Finder: $finder");
  }

  Future<bool> _tapAtTextPositionOnDesktop(SuperDesktopTextFieldState textField, int offset) async {
    final textPositionOffset = textField.textLayout.getOffsetForCaret(TextPosition(offset: offset));
    final textFieldBox = textField.context.findRenderObject() as RenderBox;

    // There's a problem on Windows and Linux where we get -0.0 instead 0.0.
    // We adjust the offset to get rid of the -0.0, because a -0.0 fails the
    // Rect bounds check. (https://github.com/flutter/flutter/issues/100033)
    final adjustedOffset = Offset(
      textPositionOffset.dx,
      // I tried checking "== -0.0" but it didn't catch the problem. This
      // approach looks for an arbitrarily small epsilon and then interprets
      // any such bounds as zero.
      textPositionOffset.dy.abs() < 1e-6 ? 0.0 : textPositionOffset.dy,
    );

    if (!textFieldBox.size.contains(adjustedOffset)) {
      return false;
    }

    final globalTapOffset = adjustedOffset + textFieldBox.localToGlobal(Offset.zero);
    await tapAt(globalTapOffset);
    return true;
  }

  Future<void> enterSuperTextPlain(Finder finder, String plainText) async {
    final fieldFinder = _findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperDesktopTextField) {
      await _enterTextOnDesktop(plainText);
      return;
    }

    if (match is SuperAndroidTextField) {
      throw Exception("Entering text on an Android SuperTextField is not yet supported");
    }

    if (match is SuperIOSTextField) {
      throw Exception("Entering text on an iOS SuperTextField is not yet supported");
    }

    throw Exception("Couldn't find a SuperTextField with the given Finder: $finder");
  }

  Finder _findInnerPlatformTextField(Finder rootFieldFinder) {
    final rootMatches = rootFieldFinder.evaluate();
    if (rootMatches.isEmpty) {
      throw Exception("Couldn't find a super text field variant with the given finder: $rootFieldFinder");
    }
    if (rootMatches.length > 1) {
      throw Exception("Found more than 1 super text field match with finder: $rootFieldFinder");
    }

    final rootMatch = rootMatches.single.widget;
    if (rootMatch is! SuperTextField) {
      // The match isn't a generic SuperTextField. Assume that it's a platform
      // specific super text field, which is what we're looking for. Return it.
      return rootFieldFinder;
    }

    final desktopFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperDesktopTextField)).evaluate();
    if (desktopFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperDesktopTextField));
    }

    final androidFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperAndroidTextField)).evaluate();
    if (androidFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperAndroidTextField));
    }

    final iosFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperIOSTextField)).evaluate();
    if (iosFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperIOSTextField));
    }

    throw Exception(
        "Couldn't find the platform-specific super text field within the root SuperTextField. Root finder: $rootFieldFinder");
  }

  Future<void> _enterTextOnDesktop(String plainText) async {
    for (int i = 0; i < plainText.length; i += 1) {
      final character = plainText[i];
      final keyCombo = _keyCodeFromCharacter(character);

      if (keyCombo.isShiftPressed) {
        await sendKeyDownEvent(LogicalKeyboardKey.shift, platform: 'macos');
      }

      if (keyCombo.isShiftPressed) {
        await sendKeyDownEvent(keyCombo.physicalKey!, platform: 'macos', character: character);
        await sendKeyUpEvent(keyCombo.physicalKey!, platform: 'macos');
      } else {
        await sendKeyEvent(keyCombo.key, platform: 'macos');
      }

      if (keyCombo.isShiftPressed) {
        await sendKeyUpEvent(LogicalKeyboardKey.shift, platform: 'macos');
      }

      await pump();
    }
  }

  _KeyboardCombo _keyCodeFromCharacter(String character) {
    if (_charactersToKey.containsKey(character)) {
      return _KeyboardCombo(_charactersToKey[character]!);
    }
    if (_shiftCharactersToKey.containsKey(character)) {
      return _KeyboardCombo(
        _shiftCharactersToKey[character]!,
        isShiftPressed: true,
        physicalKey: _enUSShiftCharactersToPhysicalKey[character]!,
      );
    }

    throw Exception("Couldn't convert '$character' to a key combo.");
  }
}

const _charactersToKey = {
  'a': LogicalKeyboardKey.keyA,
  'b': LogicalKeyboardKey.keyB,
  'c': LogicalKeyboardKey.keyC,
  'd': LogicalKeyboardKey.keyD,
  'e': LogicalKeyboardKey.keyE,
  'f': LogicalKeyboardKey.keyF,
  'g': LogicalKeyboardKey.keyG,
  'h': LogicalKeyboardKey.keyH,
  'i': LogicalKeyboardKey.keyI,
  'j': LogicalKeyboardKey.keyJ,
  'k': LogicalKeyboardKey.keyK,
  'l': LogicalKeyboardKey.keyL,
  'm': LogicalKeyboardKey.keyM,
  'n': LogicalKeyboardKey.keyN,
  'o': LogicalKeyboardKey.keyO,
  'p': LogicalKeyboardKey.keyP,
  'q': LogicalKeyboardKey.keyQ,
  'r': LogicalKeyboardKey.keyR,
  's': LogicalKeyboardKey.keyS,
  't': LogicalKeyboardKey.keyT,
  'u': LogicalKeyboardKey.keyU,
  'v': LogicalKeyboardKey.keyV,
  'w': LogicalKeyboardKey.keyW,
  'x': LogicalKeyboardKey.keyX,
  'y': LogicalKeyboardKey.keyY,
  'z': LogicalKeyboardKey.keyZ,
  ' ': LogicalKeyboardKey.space,
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
  '`': LogicalKeyboardKey.backquote,
  '-': LogicalKeyboardKey.minus,
  '=': LogicalKeyboardKey.equal,
  '[': LogicalKeyboardKey.bracketLeft,
  ']': LogicalKeyboardKey.bracketRight,
  '\\': LogicalKeyboardKey.backslash,
  ';': LogicalKeyboardKey.semicolon,
  '\'': LogicalKeyboardKey.quoteSingle,
  ',': LogicalKeyboardKey.comma,
  '.': LogicalKeyboardKey.period,
  '/': LogicalKeyboardKey.slash,
};

const _shiftCharactersToKey = {
  'A': LogicalKeyboardKey.keyA,
  'B': LogicalKeyboardKey.keyB,
  'C': LogicalKeyboardKey.keyC,
  'D': LogicalKeyboardKey.keyD,
  'E': LogicalKeyboardKey.keyE,
  'F': LogicalKeyboardKey.keyF,
  'G': LogicalKeyboardKey.keyG,
  'H': LogicalKeyboardKey.keyH,
  'I': LogicalKeyboardKey.keyI,
  'J': LogicalKeyboardKey.keyJ,
  'K': LogicalKeyboardKey.keyK,
  'L': LogicalKeyboardKey.keyL,
  'M': LogicalKeyboardKey.keyM,
  'N': LogicalKeyboardKey.keyN,
  'O': LogicalKeyboardKey.keyO,
  'P': LogicalKeyboardKey.keyP,
  'Q': LogicalKeyboardKey.keyQ,
  'R': LogicalKeyboardKey.keyR,
  'S': LogicalKeyboardKey.keyS,
  'T': LogicalKeyboardKey.keyT,
  'U': LogicalKeyboardKey.keyU,
  'V': LogicalKeyboardKey.keyV,
  'W': LogicalKeyboardKey.keyW,
  'X': LogicalKeyboardKey.keyX,
  'Y': LogicalKeyboardKey.keyY,
  'Z': LogicalKeyboardKey.keyZ,
  '!': LogicalKeyboardKey.exclamation,
  '@': LogicalKeyboardKey.at,
  '#': LogicalKeyboardKey.numberSign,
  '\$': LogicalKeyboardKey.dollar,
  '%': LogicalKeyboardKey.percent,
  '^': LogicalKeyboardKey.caret,
  '&': LogicalKeyboardKey.ampersand,
  '*': LogicalKeyboardKey.asterisk,
  '(': LogicalKeyboardKey.parenthesisLeft,
  ')': LogicalKeyboardKey.parenthesisRight,
  '~': LogicalKeyboardKey.tilde,
  '_': LogicalKeyboardKey.underscore,
  '+': LogicalKeyboardKey.add,
  '{': LogicalKeyboardKey.braceLeft,
  '}': LogicalKeyboardKey.braceRight,
  '|': LogicalKeyboardKey.bar,
  ':': LogicalKeyboardKey.colon,
  '"': LogicalKeyboardKey.quote,
  '<': LogicalKeyboardKey.less,
  '>': LogicalKeyboardKey.greater,
  '?': LogicalKeyboardKey.question,
};

/// A mapping of shift characters to physical keys on en_US keyboards
const _enUSShiftCharactersToPhysicalKey = {
  '!': LogicalKeyboardKey.digit1,
  '@': LogicalKeyboardKey.digit2,
  '#': LogicalKeyboardKey.digit3,
  '\$': LogicalKeyboardKey.digit4,
  '%': LogicalKeyboardKey.digit5,
  '^': LogicalKeyboardKey.digit6,
  '&': LogicalKeyboardKey.digit7,
  '*': LogicalKeyboardKey.digit8,
  '(': LogicalKeyboardKey.digit9,
  ')': LogicalKeyboardKey.digit0,
  '~': LogicalKeyboardKey.backquote,
  '_': LogicalKeyboardKey.minus,
  '+': LogicalKeyboardKey.equal,
  '{': LogicalKeyboardKey.bracketLeft,
  '}': LogicalKeyboardKey.bracketRight,
  '|': LogicalKeyboardKey.backslash,
  ':': LogicalKeyboardKey.semicolon,
  '"': LogicalKeyboardKey.quoteSingle,
  '<': LogicalKeyboardKey.comma,
  '>': LogicalKeyboardKey.period,
  '?': LogicalKeyboardKey.slash,
};

class _KeyboardCombo {
  _KeyboardCombo(
    this.key, {
    this.isShiftPressed = false,
    this.physicalKey,
  }) : assert(isShiftPressed ? physicalKey != null : physicalKey == null);

  final LogicalKeyboardKey key;
  final bool isShiftPressed;
  final LogicalKeyboardKey? physicalKey;
}
