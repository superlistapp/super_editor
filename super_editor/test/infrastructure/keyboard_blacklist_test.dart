import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';

void main() {
  group("Infrastructure", () {
    group("keyboard", () {
      test("blacklists bad characters on web", () {
        // Ensure that invalid characters are black-listed.
        for (final invalidCharacter in _invalidCharacters) {
          expect(
            isCharacterBlacklisted(invalidCharacter),
            isTrue,
            reason: "'$invalidCharacter' should be black-listed, but it's permitted.",
          );
        }

        // Ensure that valid characters are permitted.
        for (final validCharacter in _validCharacters) {
          expect(
            isCharacterBlacklisted(validCharacter),
            isFalse,
            reason: "'$validCharacter' should be permitted, but it's black-listed.",
          );
        }
      });
    });
  });
}

const _invalidCharacters = {
  'Dead',
  'Shift',
  'Alt',
  'Escape',
  'CapsLock',
  'PageUp',
  'PageDown',
  'Home',
  'End',
  'Control',
  'Meta',
  'Enter',
  'Backspace',
  'Delete',
  'F1',
  'F2',
  'F3',
  'F4',
  'F5',
  'F6',
  'F7',
  'F8',
  'F9',
  'F10',
  'F11',
  'F12',
  'Num Lock',
  'Scroll Lock',
  'Insert',
  'Paste',
  'Print Screen',
  'Power',
};

const _validCharacters = {
  'A',
  'a',
  'Z',
  'z',
  '1',
  '234',
  '~',
  '!',
  '@',
  '#',
  '\$',
  '%',
  '^',
  '&',
  '*',
  '(',
  ')',
  'D##',
  'áé',
};
