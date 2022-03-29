import 'dart:collection';

import 'package:characters/characters.dart';

// Match any characters we want skip over while moving by word. This will match
// Unicode graphemes with a General_Category value in:
// - Punctuation (P), such as ".", "-", and "。"
// - Separator (Z), such as " " (space), and "　" (ideographic space)
// See http://www.unicode.org/reports/tr44/#GC_Values_Table for details on
// on the Unicode General_Category property.
final _separatorRegex = RegExp(r'^[\p{Z}\p{P}]$', unicode: true);

extension CharacterMovement on String {
  /// Returns the code point index of the character that sits
  /// at the next start of word upstream from the given
  /// [textOffset] code point index.
  ///
  /// Examples:
  ///   |word up -> `null`
  ///   wo|rd up -> `0`
  ///   word| up -> `0`
  ///   word |up -> `0`
  ///   word up| -> `5`
  int? moveOffsetUpstreamByWord(int textOffset) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == 0) {
      return null;
    }

    bool isInSeparator = false;

    final separatorEnds = Queue<int>()..addFirst(0);

    int visitedCharacterCount = 0;
    int codePointIndex = 0;
    for (final character in characters) {
      isInSeparator = _separatorRegex.hasMatch(character);
      codePointIndex += character.length;
      visitedCharacterCount += 1;

      if (isInSeparator) {
        // If the last separator end was before this index, it wasn't really the
        // end. Remove and replace it. Always keep 0 as a special case to make
        // sure we can reach the start of the string.
        if (separatorEnds.first != 0 && separatorEnds.first == codePointIndex - character.length) {
          separatorEnds.removeFirst();
        }
        separatorEnds.addFirst(codePointIndex);
        if (separatorEnds.length > 2) {
          separatorEnds.removeLast();
        }
      }

      if (visitedCharacterCount >= textOffset) {
        // We're at the given text offset. The upstream word offset is
        // in the separatorEnds queue.
        break;
      }
    }

    return separatorEnds.first < textOffset ? separatorEnds.first : separatorEnds.last;
  }

  /// Returns the code point index of the character that sits
  /// [characterCount] upstream from the given [textOffset] code
  /// point index.
  ///
  /// Examples:
  ///   |a💙c -> `null`
  ///   a|💙c -> `0`
  ///   a💙|c -> `1`
  ///   a💙c| -> `3` (notice that we moved 2 units due to emoji length)
  int? moveOffsetUpstreamByCharacter(int textOffset, {int characterCount = 1}) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == 0) {
      return null;
    }

    int codePointIndex = 0;
    final characterIndices = <int>[];
    for (final character in characters) {
      if (codePointIndex == textOffset) {
        break;
      }

      characterIndices.add(codePointIndex);
      codePointIndex += character.length;
    }

    if (characterIndices.length < characterCount) {
      return null;
    }

    return characterIndices[characterIndices.length - characterCount];
  }

  /// Returns the code point index of the character that sits
  /// after the end of the next word downstream from the given
  /// [textOffset] code point index.
  ///
  /// Examples:
  ///   |word up -> `4`
  ///   wo|rd up -> `4`
  ///   word| up -> `7`
  ///   word |up -> `7`
  ///   word up| -> `null`
  int? moveOffsetDownstreamByWord(int textOffset) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == length) {
      return null;
    }

    bool isInSeparator = false;

    int lastSeparatorStartCodePointOffset = 0;

    int codePointIndex = 0;
    for (final character in characters) {
      final characterIsSeparator = _separatorRegex.hasMatch(character);

      if (characterIsSeparator && !isInSeparator) {
        lastSeparatorStartCodePointOffset = codePointIndex;
      }

      isInSeparator = characterIsSeparator;
      codePointIndex += character.length;

      if (lastSeparatorStartCodePointOffset > textOffset) {
        return lastSeparatorStartCodePointOffset;
      }
    }

    // The end of this string is as far as we can go.
    return length;
  }

  /// Returns the code point index of the character that sits
  /// [characterCount] downstream from given [textOffset] code
  /// point index.
  ///
  /// Examples:
  ///   |a💙c -> `1`
  ///   a|💙c -> `3` (notice that we moved 2 units due to emoji length)
  ///   a💙|c -> `4`
  ///   a💙c| -> `null`
  int? moveOffsetDownstreamByCharacter(int textOffset, {int characterCount = 1}) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == length) {
      return null;
    }

    int visitedCharacterCodePointLength = 0;
    int characterCountBeyondTextOffset = 0;
    for (final character in characters) {
      visitedCharacterCodePointLength += character.length;
      if (visitedCharacterCodePointLength > textOffset) {
        characterCountBeyondTextOffset += 1;
      }

      if (characterCountBeyondTextOffset == characterCount) {
        break;
      }
    }

    if (characterCountBeyondTextOffset < characterCount) {
      return null;
    }

    return visitedCharacterCodePointLength;
  }
}
