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

    // We'll store the end of the most recently seen separator grapheme here
    int nextSeparatorEndCodePointOffset = 0;
    // ...and flush it to here when we see a non-separator grapheme. This
    // addresses the case where multiple consecutive separator graphemes
    // immediately precede the requested textOffset
    int lastSeparatorEndCodePointOffset = 0;

    // We want to return the code point index immediately after the last
    // separator grapheme, so keep track of the character and code point indices
    // one ahead of the current character in each iteration of the loop
    int nextCharacterIndex = 0;
    int nextCodePointIndex = 0;
    for (final character in characters) {
      nextCharacterIndex += 1;
      if (nextCharacterIndex >= textOffset) {
        // We're at the given text offset. The upstream word offset is in
        // lastWordStartIndex
        break;
      }

      nextCodePointIndex += character.length;
      final isInSeparator = _separatorRegex.hasMatch(character);

      if (isInSeparator) {
        // We're in a separator character but it might not be the last one in
        // a series of separators. Write the current index to our temporary
        // variable
        nextSeparatorEndCodePointOffset = nextCodePointIndex;
      } else {
        // We're in a non-separator character, so the last seen separator
        // character was the last one in its sequence. Update the variable
        // accordingly
        lastSeparatorEndCodePointOffset = nextSeparatorEndCodePointOffset;
      }
    }

    return lastSeparatorEndCodePointOffset;
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

    bool lastCharWasSeparator = true;
    int codePointIndex = 0;
    int characterIndex = 0;
    for (final character in characters) {
      if (characterIndex >= textOffset) {
        // No characters before textOffset will impact the results, so don't
        // bother running the regex on them
        final isInSeparator = _separatorRegex.hasMatch(character);
        if (characterIndex > textOffset && isInSeparator && !lastCharWasSeparator) {
          return codePointIndex;
        }
        lastCharWasSeparator = isInSeparator;
      }
      characterIndex += 1;
      codePointIndex += character.length;
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
