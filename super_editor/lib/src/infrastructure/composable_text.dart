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

/// [TextComposable] that wraps, and defers to, a child [TextComposable].
///
/// [ProxyTextComposable] let's you apply decorations to a [childTextComposable]
/// when those decorations don't alter the layout of the child's text.
///
/// Implementers need to provide [childTextComposable].
mixin ProxyTextComposable implements TextComposable {
  TextComposable get childTextComposable;

  @override
  TextNodeSelection getWordSelectionAt(TextNodePosition textNodePosition) {
    return childTextComposable.getWordSelectionAt(textNodePosition);
  }

  @override
  String getContiguousTextAt(TextNodePosition textPosition) {
    return childTextComposable.getContiguousTextAt(textPosition);
  }

  @override
  TextNodePosition? getPositionOneLineUp(TextNodePosition textNodePosition) {
    return childTextComposable.getPositionOneLineUp(textNodePosition);
  }

  @override
  TextNodePosition? getPositionOneLineDown(TextNodePosition textNodePosition) {
    return childTextComposable.getPositionOneLineDown(textNodePosition);
  }

  @override
  TextNodePosition getPositionAtStartOfLine(TextNodePosition textNodePosition) {
    return childTextComposable.getPositionAtStartOfLine(textNodePosition);
  }

  @override
  TextNodePosition getPositionAtEndOfLine(TextNodePosition textNodePosition) {
    return childTextComposable.getPositionAtEndOfLine(textNodePosition);
  }
}
