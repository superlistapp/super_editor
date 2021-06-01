import 'package:super_editor/src/default_editor/text.dart';

/// Contract for widgets that include editable text.
///
/// Examples: paragraphs, list items, images with captions.
abstract class TextComposable {
  /// Returns a [TextNodeSelection] that encompasses the entire word
  /// found at the given [textNodePosition].
  TextNodeSelection getWordSelectionAt(TextNodePosition textNodePosition);

  /// Returns all text surrounding [textPosition] that is not
  /// broken by white space.
  String getContiguousTextAt(TextNodePosition textPosition);

  /// Returns the [TextNodePosition] that corresponds to a text location
  /// that is one line above the given [textNodePosition], or [null] if
  /// there is no position one line up.
  TextNodePosition? getPositionOneLineUp(TextNodePosition textNodePosition);

  /// Returns the [TextNodePosition] that corresponds to a text location
  /// that is one line below the given [textNodePosition], or [null] if
  /// there is no position one line down.
  TextNodePosition? getPositionOneLineDown(TextNodePosition textNodePosition);

  /// Returns the node position that corresponds to the first character
  /// in the line of text that contains the given [textNodePosition].
  TextNodePosition getPositionAtStartOfLine(TextNodePosition textNodePosition);

  /// Returns the [TextNodePosition] that corresponds to the last character
  /// in the line of text that contains the given [textNodePosition].
  TextNodePosition getPositionAtEndOfLine(TextNodePosition textNodePosition);
}
