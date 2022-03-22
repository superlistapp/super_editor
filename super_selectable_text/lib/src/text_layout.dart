import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Contract to interrogate the layout of a blob of text.
abstract class TextLayout {
  /// Returns `true` if a text character overlaps the given [localOffset],
  /// or `false` otherwise.
  bool isTextAtOffset(Offset localOffset);

  /// Returns the [TextPosition] that overlaps the given [localOffset].
  TextPosition? getPositionAtOffset(Offset localOffset);

  /// Returns the height of the character at the given [position].
  double getLineHeightAtPosition(TextPosition position);

  /// Returns the number of lines of text, given the current text layout.
  int getLineCount();

  /// Returns the [TextPosition] that overlaps the given [localOffset],
  /// or the [TextPosition] that is nearest the given [localOffset] if
  /// no [TextPosition] overlaps the given [localOffset].
  TextPosition getPositionNearestToOffset(Offset localOffset);

  /// Returns the [Offset] of the character at the given [position].
  Offset getOffsetAtPosition(TextPosition position);

  /// Returns the [Offset] to place a caret that precedes the given
  /// [position].
  Offset getOffsetForCaret(TextPosition position);

  /// Returns the height that a caret should occupy when the caret
  /// is placed at the given [position].
  ///
  /// The return type is nullable because the underlying implementation
  /// is also nullable. It's unclear when or why the value would be `null`.
  double? getHeightForCaret(TextPosition position);

  /// Returns a [List] of [TextBox]es that contain the given [selection].
  List<TextBox> getBoxesForSelection(TextSelection selection);

  /// Returns a bounding [TextBox] for the character at the given [position].
  TextBox getCharacterBox(TextPosition position);

  /// Returns the [TextPosition] that corresponds to a text location
  /// that is one line above the given [textPosition], or [null] if
  /// there is no position one line up.
  TextPosition? getPositionOneLineUp(TextPosition textPosition);

  /// Returns the [TextPosition] that corresponds to a text location
  /// that is one line below the given [textPosition], or [null] if
  /// there is no position one line down.
  TextPosition? getPositionOneLineDown(TextPosition textPosition);

  /// Returns the [TextPosition] that corresponds to the first character
  /// in the line of text that contains the given [textPosition].
  TextPosition getPositionAtStartOfLine(TextPosition textPosition);

  /// Returns the [TextPosition] that corresponds to the last character
  /// in the line of text that contains the given [textPosition].
  TextPosition getPositionAtEndOfLine(TextPosition textPosition);

  /// Returns the [TextPosition] in the first line within this
  /// [TextLayout] that is closest to the given `x`-value, or
  /// `-1` if the text is not laid out yet.
  TextPosition getPositionInFirstLineAtX(double x);

  /// Returns the [TextPosition] in the last line within this
  /// [TextLayout] that is closest to the given `x`-value, or
  /// `-1` if the text is not laid out yet.
  TextPosition getPositionInLastLineAtX(double x);

  /// Returns the [TextSelection] that corresponds to a selection
  /// rectangle formed by the span from [baseOffset] to [extentOffset], or
  /// a collapsed selection at `-1` if the text is not laid out yet.
  ///
  /// The [baseOffset] determines where the selection begins. The
  /// [extentOffset] determines where the selection ends.
  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset);

  /// Returns a [TextSelection] that surrounds the given [startingPosition] and expands
  /// outward until the given [expansion] chooses to stop expanding.
  TextSelection expandSelection(TextPosition startingPosition, TextExpansion expansion, TextAffinity affinity);
}

/// Function that expands from a given [startingPosition] to an expanded
/// [TextSelection], based on some expansion decision behavior.
typedef TextExpansion = TextSelection Function(String text, TextPosition startingPosition, TextAffinity affinity);

/// [TextExpansion] function that expands from [startingPosition] in both directions
/// to select a single paragraph.
TextSelection paragraphExpansionFilter(String text, TextPosition startingPosition, TextAffinity affinity) {
  // If the given position falls directly on a newline then return
  // just the newline character as the paragraph selection.
  if (startingPosition.offset < text.length && text[startingPosition.offset] == '\n') {
    return TextSelection.collapsed(offset: startingPosition.offset);
  }

  int start = startingPosition.offset;
  int end = startingPosition.offset;

  while (start > 0 && text[start - 1] != '\n') {
    start -= 1;
  }
  while (end < text.length && text[end] != '\n') {
    end += 1;
  }

  return affinity == TextAffinity.downstream
      ? TextSelection(
          baseOffset: start,
          extentOffset: end,
        )
      : TextSelection(
          baseOffset: end,
          extentOffset: start,
        );
}
