import 'package:characters/characters.dart';

/// Returns the code point index for the code point that ends the visual
/// character that begins at [startingCodePointIndex].
///
/// A single visual character might be comprised of multiple code points.
/// Each code point occupies a slot within a [String], which means that
/// an index into a [String] might refer to a piece of a single visual
/// character.
///
/// [startingCodePointIndex] is the traditional [String] index for the
/// leading code point of a visual character.
///
/// This function starts at the given [startingCodePointIndex] and walks
/// towards the end of [text] until it has accumulated an entire
/// visual character. The [String] index of the final code point for
/// the given character is returned.
int getCharacterEndBounds(String text, int startingCodePointIndex) {
  // This implementation was copied and adapted from text_editing_action_target
  // in the Flutter repo.
  assert(startingCodePointIndex >= 0 && startingCodePointIndex <= text.length);

  if (startingCodePointIndex == text.length) {
    return text.length;
  }

  final CharacterRange range = CharacterRange.at(text, 0, startingCodePointIndex);
  // If index is not on a character boundary, return the next character
  // boundary.
  if (range.current.length != startingCodePointIndex) {
    return range.current.length;
  }

  range.expandNext();
  return range.current.length;
}

/// Returns the code point index for the code point that begins the visual
/// character that ends at [endingCodePointIndex].
///
/// A single visual character might be comprised of multiple code points.
/// Each code point occupies a slot within a [String], which means that
/// an index into a [String] might refer to a piece of a single visual
/// character.
///
/// [endingCodePointIndex] is the traditional [String] index for the
/// trailing code point of a visual character.
///
/// This function starts at the given [endingCodePointIndex] and walks
/// towards the beginning of [text] until it has accumulated an entire
/// visual character. The [String] index of the initial code point for
/// the given character is returned.
int getCharacterStartBounds(String text, int endingCodePointIndex) {
  // This implementation was copied and adapted from text_editing_action_target
  // in the Flutter repo.
  assert(endingCodePointIndex >= 0 && endingCodePointIndex <= text.length);

  if (endingCodePointIndex == 0) {
    return 0;
  }

  final CharacterRange range = CharacterRange.at(text, 0, endingCodePointIndex);
  // If index is not on a character boundary, return the previous character
  // boundary.
  if (range.current.length != endingCodePointIndex) {
    range.dropLast();
    return range.current.length;
  }

  range.dropLast();
  return range.current.length;
}
