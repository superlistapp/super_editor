import 'package:super_editor/src/default_editor/text.dart';

/// Contract for widgets that include editable text.
///
/// Examples: paragraphs, list items, images with captions.
///
/// The reason that this interface is tied to visual details, e.g., widgets,
/// is because queries about line positions depend on how text is flowed
/// within the layout. Those queries don't have any meaning with layout.
///
/// The [TextComposable] API includes methods that are very similar to
/// `TextLayout` from `super_text_layout`, except that the APIs in
/// [TextComposable] accept and return document node positions, instead of
/// `TextPosition`s. You can think of this interface like the parts of
/// `TextLayout` related to position movement and text composition, but
/// in terms of document semantics instead of text semantics.
abstract class TextComposable {
  /// Returns all text in this text composable.
  String getAllText();

  /// Returns all text surrounding [textPosition] that isn't
  /// broken by newlines.
  String getContiguousTextAt(TextNodePosition textPosition);

  /// Returns a [TextNodeSelection] that encompasses the entire word
  /// found at the given [textNodePosition].
  TextNodeSelection getWordSelectionAt(TextNodePosition textNodePosition);

  /// Returns a [TextNodeSelection] that encompasses all text surrounding
  /// [textPosition] that isn't broken by newlines.
  TextNodeSelection getContiguousTextSelectionAt(TextNodePosition textPosition);

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
  String getAllText() {
    return childTextComposable.getAllText();
  }

  @override
  String getContiguousTextAt(TextNodePosition textPosition) {
    return childTextComposable.getContiguousTextAt(textPosition);
  }

  @override
  TextNodeSelection getWordSelectionAt(TextNodePosition textNodePosition) {
    return childTextComposable.getWordSelectionAt(textNodePosition);
  }

  @override
  TextNodeSelection getContiguousTextSelectionAt(TextNodePosition textNodePosition) {
    return childTextComposable.getContiguousTextSelectionAt(textNodePosition);
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
