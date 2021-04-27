import 'package:flutter/rendering.dart';

/// Contract for widgets that include editable text.
///
/// Examples: paragraphs, list items, images with captions.
///
/// The text positions accepted by a [TextComposable] are [dynamic]
/// rather than [TextPosition]s because a use-case might include
/// complex text composition, like tables, which might choose to
/// index positions based on cell IDs, or row and column indices.
abstract class TextComposable {
  /// Returns a [TextSelection] that encompasses the entire word
  /// found at the given [textPosition].
  ///
  /// Throws an exception if [textPosition] is not the right type
  /// for this [TextComposable].
  TextSelection getWordSelectionAt(dynamic textPosition);

  /// Returns all text surrounding [textPosition] that is not
  /// broken by white space.
  ///
  /// Throws an exception if [textPosition] is not the right type
  /// for this [TextComposable].
  String getContiguousTextAt(dynamic textPosition);

  /// Returns the text position that corresponds to a text location
  /// that is one line above the given [textPosition], or [null] if
  /// there is no position one line up.
  ///
  /// Throws an exception if [textPosition] is not the right type
  /// for this [TextComposable].
  dynamic getPositionOneLineUp(dynamic textPosition);

  /// Returns the node position that corresponds to a text location
  /// that is one line below the given [textPosition], or [null] if
  /// there is no position one line down.
  ///
  /// Throws an exception if [textPosition] is not the right type
  /// for this [TextComposable].
  dynamic getPositionOneLineDown(dynamic textPosition);

  /// Returns the node position that corresponds to the first character
  /// in the line of text that contains the given [textPosition].
  ///
  /// Throws an exception if [textPosition] is not the right type
  /// for this [TextComposable].
  dynamic getPositionAtStartOfLine(dynamic textPosition);

  /// Returns the node position that corresponds to the last character
  /// in the line of text that contains the given [textPosition].
  ///
  /// Throws an exception if [textPosition] is not the right type
  /// for this [TextComposable].
  dynamic getPositionAtEndOfLine(dynamic textPosition);
}
