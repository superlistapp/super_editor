import 'package:characters/characters.dart';

extension CharacterMovement on String {
  /// Returns the code point index of the character that sits
  /// one word upstream from the given [textOffset] code point index.
  ///
  /// Examples:
  ///   |word up -> `null`
  ///   wo|rd up -> `0`
  ///   word| up -> `0`
  ///   word |up -> `4`
  ///   word up| -> `6`
  int? moveOffsetUpstreamByWord(int textOffset, {int characterCount = 1}) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == 0) {
      return null;
    }

    bool isInSpace = false;

    int lastSpaceStartCodePointOffset = 0;
    int lastSpaceEndCodePointOffset = 0;

    int visitedCharacterCount = 0;
    int codePointIndex = 0;
    for (final character in characters) {
      if (visitedCharacterCount >= textOffset - 1) {
        // We're at the given text offset. The upstream word offset is
        // at lastSpaceEndCodePointOffset.
        break;
      }

      if (character == " " && !isInSpace) {
        lastSpaceStartCodePointOffset = codePointIndex;
      }

      isInSpace = character == " ";
      codePointIndex += character.length;
      visitedCharacterCount += 1;

      if (character == " ") {
        lastSpaceEndCodePointOffset = codePointIndex;
      }
    }

    return lastSpaceEndCodePointOffset < textOffset ? lastSpaceEndCodePointOffset : lastSpaceStartCodePointOffset;
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
  /// one word downstream from given [textOffset] code point
  /// index.
  ///
  /// Examples:
  ///   |word up -> `4`
  ///   wo|rd up -> `4`
  ///   word| up -> `5`
  ///   word |up -> `7`
  ///   word up| -> `null`
  int? moveOffsetDownstreamByWord(int textOffset, {int characterCount = 1}) {
    if (textOffset < 0 || textOffset > length) {
      throw Exception("Index '$textOffset' is out of string range. Length: $length");
    }

    if (textOffset == length) {
      return null;
    }

    bool isInSpace = false;

    int lastSpaceStartCodePointOffset = 0;
    int lastSpaceEndCodePointOffset = 0;

    int codePointIndex = 0;
    for (final character in characters) {
      if (character == " " && !isInSpace) {
        lastSpaceStartCodePointOffset = codePointIndex;
      }

      isInSpace = character == " ";
      codePointIndex += character.length;

      if (character == " ") {
        lastSpaceEndCodePointOffset = codePointIndex;
      }

      if (lastSpaceStartCodePointOffset > textOffset) {
        return lastSpaceStartCodePointOffset;
      }
      if (lastSpaceEndCodePointOffset > textOffset) {
        return lastSpaceEndCodePointOffset;
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
