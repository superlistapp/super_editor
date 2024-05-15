import 'dart:ui';
import 'package:flutter/widgets.dart';

import 'super_text.dart';

/// Contract to interrogate the layout of a blob of text.
abstract class TextLayout {
  /// Returns `true` if a text character overlaps the given [localOffset],
  /// or `false` otherwise.
  bool isTextAtOffset(Offset localOffset);

  /// Returns the [TextPosition] that overlaps the given [localOffset].
  TextPosition? getPositionAtOffset(Offset localOffset);

  /// Returns the height of the character at the given [position].
  double getLineHeightAtPosition(TextPosition position);

  /// Returns the estimated line height
  ///
  /// This is needed because if the text contains only emojis
  /// we can't get a [TextBox] from flutter to determine
  /// the line height
  ///
  /// WARNING: This method should be called only when absolutely necessary
  /// and may be removed in the future
  double get estimatedLineHeight;

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
  List<TextBox> getBoxesForSelection(
    TextSelection selection, {
    BoxHeightStyle boxHeightStyle = BoxHeightStyle.tight,
    BoxWidthStyle boxWidthStyle = BoxWidthStyle.tight,
  });

  /// Returns a bounding [TextBox] for the character at the given [position] or `null`
  /// if a character box couldn't be found.
  ///
  /// The only situation where this could return null is when the text
  /// contains only emojis
  TextBox? getCharacterBox(TextPosition position);

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

/// A block of text (probably a widget's State object) that includes a
/// [ProseTextLayout] somewhere within it.
///
/// The [ProseTextBlock] interface provides clients with access to the
/// internal [ProseTextLayout], no matter how deeply that text layout
/// might be buried within this block's widget tree.
///
/// For example, a [ProseTextBlock] might include an animated builder,
/// or stream builder that wraps the actual text layout. But you still want
/// to query details about the text layout. Rather than re-declare every
/// [ProseTextLayout] method and forward the calls, a [ProseTextBlock]
/// provides access to the inner [ProseTextLayout], directly.
abstract mixin class ProseTextBlock {
  /// Returns the [ProseTextLayout] that sits within this text block.
  ProseTextLayout get textLayout;
}

/// A [State] object that mixes in [ProseTextBlock], which is a useful base class
/// for [State] objects that include a [TextLayout] in their widget sub-tree.
///
/// A [ProseTextBlock] is anything that provides access to a [TextLayout]. Typically,
/// a [State] object is what provides access to a [TextLayout], by grabbing a reference
/// to a [TextLayout] in the [State]'s widget sub-tree.
///
/// A [State] object could extend `State<MyWidget>`, like normal, and then implement
/// `ProseTextBlock`. However, in practice, there are often [GlobalKey]s that are
/// created to access the [State] object and retrieve the [textLayout]. It would be
/// nice if those [GlobalKey]s could be strongly-typed to the [State] object, e.g.,
/// `GlobalKey<ProseTextState>`. This base class allows many different [GlobalKey]
/// declarations to declare their [State] type without needing access to every
/// different widget's [State] class, so long as any such widget's [State] class
/// extends this class.
abstract class ProseTextState<T extends StatefulWidget> extends State<T> with ProseTextBlock {}

/// A [TextLayout] that includes queries that pertain specifically to
/// prose-style text, i.e., regular human-to-human text - not code,
/// or phone numbers, or dates.
///
/// The [ProseTextLayout] is kept separate from [TextLayout] because some
/// [ProseTextLayout] APIs may not be applicable to some [TextLayout] content.
/// Furthermore, there may be various [TextLayout] use-cases for which [ProseTextLayout]
/// APIs aren't needed, and would therefore introduce undue implementation burden.
abstract class ProseTextLayout extends TextLayout {
  /// Returns a [TextSelection] that surrounds the word that contains the
  /// given [position].
  ///
  /// For example, given the text and position "Hello, wo|rld", this method
  /// would return a [TextSelection] that surrounds the word "world".
  TextSelection getWordSelectionAt(TextPosition position);
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

/// A [ProseTextLayout] that's backed by a [RenderLayoutAwareParagraph], which
/// is essentially a [RenderParagraph].
class RenderParagraphProseTextLayout implements ProseTextLayout {
  RenderParagraphProseTextLayout({
    required InlineSpan richText,
    required RenderLayoutAwareParagraph renderParagraph,
  })  : _richText = richText,
        _renderParagraph = renderParagraph {
    _textLength = _richText.toPlainText().length;
  }

  final InlineSpan _richText;
  final RenderLayoutAwareParagraph _renderParagraph;
  late final int _textLength;

  TextScaler get textScaler => _renderParagraph.textScaler;

  @override
  double get estimatedLineHeight {
    final fontSize = _richText.style?.fontSize ?? 16;
    final lineHeight = _richText.style?.height ?? 1.0;
    return textScaler.scale(fontSize * lineHeight);
  }

  @override
  TextPosition? getPositionAtOffset(Offset localOffset) {
    if (_renderParagraph.needsLayout) {
      return null;
    }

    if (!_renderParagraph.size.contains(localOffset)) {
      return null;
    }

    return _renderParagraph.getPositionForOffset(localOffset);
  }

  @override
  TextPosition getPositionNearestToOffset(Offset localOffset) {
    if (_renderParagraph.needsLayout) {
      return const TextPosition(offset: -1);
    }

    return _renderParagraph.getPositionForOffset(localOffset);
  }

  @override
  Offset getOffsetAtPosition(TextPosition position) {
    if (_renderParagraph.needsLayout) {
      return Offset.zero;
    }

    return _renderParagraph.getOffsetForCaret(position, Rect.zero);
  }

  @override
  double getLineHeightAtPosition(TextPosition position) {
    if (_renderParagraph.needsLayout) {
      return 0;
    }

    final lineHeightMultiplier = _richText.style?.height ?? 1.0;

    // If no text is currently displayed, we can't use a character box
    // to measure, but we may be able to use related metrics.
    if (_textLength == 0) {
      final estimatedLineHeight = _renderParagraph.getFullHeightForCaret(position);
      return estimatedLineHeight * lineHeightMultiplier;
    }

    // There is some text in this layout. Get the bounding box for the
    // character at the given position and return its height.
    final characterBox = getCharacterBox(position);
    if (characterBox == null) {
      return estimatedLineHeight;
    }
    return characterBox.toRect().height * lineHeightMultiplier;
  }

  @override
  int getLineCount() {
    if (_renderParagraph.needsLayout) {
      return 0;
    }

    return _renderParagraph
        .getBoxesForSelection(TextSelection(
          baseOffset: 0,
          extentOffset: _textLength,
        ))
        .length;
  }

  @override
  Offset getOffsetForCaret(TextPosition position) {
    if (_renderParagraph.needsLayout) {
      return Offset.zero;
    }

    return _renderParagraph.getOffsetForCaret(position, Rect.zero);
  }

  @override
  double? getHeightForCaret(TextPosition position) {
    if (_renderParagraph.needsLayout) {
      return null;
    }

    return _renderParagraph.getFullHeightForCaret(position);
  }

  @override
  List<TextBox> getBoxesForSelection(
    TextSelection selection, {
    BoxHeightStyle boxHeightStyle = BoxHeightStyle.tight,
    BoxWidthStyle boxWidthStyle = BoxWidthStyle.tight,
  }) {
    if (_renderParagraph.needsLayout) {
      return [];
    }

    return _renderParagraph.getBoxesForSelection(
      selection,
      boxHeightStyle: boxHeightStyle,
      boxWidthStyle: boxWidthStyle,
    );
  }

  @override
  TextBox? getCharacterBox(TextPosition position) {
    if (_renderParagraph.needsLayout) {
      return const TextBox.fromLTRBD(0, 0, 0, 0, TextDirection.ltr);
    }

    final plainText = _richText.toPlainText();
    if (plainText.isEmpty) {
      final lineHeightEstimate = _renderParagraph.getFullHeightForCaret(const TextPosition(offset: 0));
      return TextBox.fromLTRBD(0, 0, 0, lineHeightEstimate, TextDirection.ltr);
    }

    // Ensure that the given TextPosition does not exceed available text length.
    var characterPosition = position.offset >= plainText.length ? TextPosition(offset: plainText.length - 1) : position;

    var boxes = _renderParagraph.getBoxesForSelection(TextSelection(
      baseOffset: characterPosition.offset,
      extentOffset: characterPosition.offset + 1,
    ));

    // For any regular character, boxes should return exactly one box
    // for the character. However, emojis don't return any boxes. In that
    // case, we walk the characters up and down the text, hoping to find
    // a non-emoji to measure. If all of the content is emojis, then we can't
    // get a measurement from Flutter.
    //
    // If we don't have any boxes, walk backward in the text to find
    // a character with a box.
    while (boxes.isEmpty && characterPosition.offset > 0) {
      characterPosition = TextPosition(offset: characterPosition.offset - 1);

      boxes = _renderParagraph.getBoxesForSelection(TextSelection(
        baseOffset: characterPosition.offset,
        extentOffset: characterPosition.offset + 1,
      ));
    }

    // If we still don't have any boxes, walk forward in the text to find
    // a character with a box.
    while (boxes.isEmpty && characterPosition.offset < _textLength - 1) {
      characterPosition = TextPosition(offset: characterPosition.offset + 1);

      boxes = _renderParagraph.getBoxesForSelection(TextSelection(
        baseOffset: characterPosition.offset,
        extentOffset: characterPosition.offset + 1,
      ));
    }

    if (boxes.isEmpty) {
      return null;
    }

    return boxes.first;
  }

  @override
  TextPosition getPositionAtStartOfLine(TextPosition currentPosition) {
    if (_renderParagraph.needsLayout) {
      return const TextPosition(offset: -1);
    }

    final renderParagraph = _renderParagraph;
    // TODO: use the character box instead of the estimated line height
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final positionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, estimatedLineHeight / 2);
    final endOfLineOffset = Offset(0, positionOffset.dy);
    return renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  @override
  TextPosition getPositionAtEndOfLine(TextPosition currentPosition) {
    if (_renderParagraph.needsLayout) {
      return const TextPosition(offset: -1);
    }

    final renderParagraph = _renderParagraph;
    // TODO: use the character box instead of the estimated line height
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final positionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, estimatedLineHeight / 2);
    final endOfLineOffset = Offset(renderParagraph.size.width, positionOffset.dy);
    return renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  @override
  TextPosition? getPositionOneLineUp(TextPosition currentPosition) {
    if (_renderParagraph.needsLayout) {
      return null;
    }

    final renderParagraph = _renderParagraph;
    // TODO: use the character box instead of the estimated line height
    final lineHeight = estimatedLineHeight;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineUpOffset = currentSelectionOffset - Offset(0, lineHeight);

    if (oneLineUpOffset.dy < 0) {
      // The first line is selected. There is no line above this.
      return null;
    }

    return renderParagraph.getPositionForOffset(oneLineUpOffset);
  }

  @override
  TextPosition? getPositionOneLineDown(TextPosition currentPosition) {
    if (_renderParagraph.needsLayout) {
      return null;
    }

    final renderParagraph = _renderParagraph;
    // TODO: use the character box instead of the estimated line height
    final lineHeight = estimatedLineHeight;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineDownOffset = currentSelectionOffset + Offset(0, lineHeight);

    if (oneLineDownOffset.dy > renderParagraph.size.height) {
      // The last line is selected. There is no line below that.
      return null;
    }

    return renderParagraph.getPositionForOffset(oneLineDownOffset);
  }

  @override
  TextPosition getPositionInFirstLineAtX(double x) {
    if (_renderParagraph.needsLayout) {
      return const TextPosition(offset: -1);
    }

    return getPositionNearestToOffset(Offset(x, 0));
  }

  @override
  TextPosition getPositionInLastLineAtX(double x) {
    if (_renderParagraph.needsLayout) {
      return const TextPosition(offset: -1);
    }

    return getPositionNearestToOffset(
      Offset(x, _renderParagraph.size.height),
    );
  }

  @override
  TextSelection expandSelection(TextPosition position, TextExpansion expansion, TextAffinity affinity) {
    return expansion(_richText.toPlainText(), position, affinity);
  }

  @override
  bool isTextAtOffset(Offset localOffset) {
    if (_renderParagraph.needsLayout) {
      return false;
    }

    List<TextBox> boxes = _renderParagraph.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: _textLength,
      ),
    );

    for (final box in boxes) {
      if (box.toRect().contains(localOffset)) {
        return true;
      }
    }

    return false;
  }

  @override
  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset) {
    if (_renderParagraph.needsLayout) {
      return const TextSelection.collapsed(offset: -1);
    }

    final renderParagraph = _renderParagraph;
    final contentHeight = renderParagraph.size.height;
    final textLength = _textLength;

    // We don't know whether the base offset is higher or lower than the
    // extent offset. Regardless, if either offset is above the top of
    // the text then that text position should be 0. If either offset
    // is below the bottom of the text then that offset should be the
    // total length of the text.
    final basePosition = baseOffset.dy < 0
        ? 0
        : baseOffset.dy > contentHeight
            ? textLength
            : renderParagraph.getPositionForOffset(baseOffset).offset;
    final extentPosition = extentOffset.dy < 0
        ? 0
        : extentOffset.dy > contentHeight
            ? textLength
            : renderParagraph.getPositionForOffset(extentOffset).offset;

    final selection = TextSelection(
      baseOffset: basePosition,
      extentOffset: extentPosition,
    );

    return selection;
  }

  @override
  TextSelection getWordSelectionAt(TextPosition position) {
    if (_renderParagraph.needsLayout) {
      return const TextSelection.collapsed(offset: -1);
    }

    final wordRange = _renderParagraph.getWordBoundary(position);
    return TextSelection(
      baseOffset: wordRange.start,
      extentOffset: wordRange.end,
    );
  }
}
