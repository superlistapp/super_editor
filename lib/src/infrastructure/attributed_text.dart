import 'package:flutter/painting.dart';

import 'attributed_spans.dart';

/// Text with attributions applied to desired spans of text.
///
/// An attribution can be any object as long as each attribution
/// object implements equality such that any two instances of an
/// equivalent attribution are considered equal. A `String` is
/// typically a good choice to use as an attribution type.
class AttributedText {
  AttributedText({
    this.text = '',
    List<SpanMarker>? attributions,
  }) : _spans = AttributedSpans(length: text.length, attributions: attributions ?? []);

  final String text;
  final AttributedSpans _spans;

  /// Returns true if the text has the given attribution at
  /// `offset`, or false otherwise.
  bool hasAttributionAt(
    int offset, {
    dynamic attribution,
  }) {
    return _spans.hasAttributionAt(offset, attribution: attribution);
  }

  /// Returns true if the text contains at least one character of
  /// attribution for each of the given `attributions` within the
  /// given `range`, returns false otherwise.
  bool hasAttributionsWithin({
    required Set<dynamic> attributions,
    required TextRange range,
  }) {
    return _spans.hasAttributionsWithin(
      attributions: attributions,
      start: range.start,
      end: range.end,
    );
  }

  /// Returns all attributions that cover the given `offset` within
  /// the text.
  Set<dynamic> getAllAttributionsAt(int offset) {
    return _spans.getAllAttributionsAt(offset);
  }

  /// Adds the given attribution to all characters within the given
  /// `range`, inclusive.
  void addAttribution(dynamic attribution, TextRange range) {
    _spans.addAttribution(newAttribution: attribution, start: range.start, end: range.end);
  }

  /// Removes the given attribution from all characters within the
  /// given `range`, inclusive.
  void removeAttribution(dynamic attribution, TextRange range) {
    _spans.addAttribution(newAttribution: attribution, start: range.start, end: range.end);
  }

  /// If ALL of the text in `range` contains the given `attribution`,
  /// that attribution is removed from the text in `range`.
  /// Otherwise, all of the text in `range` is given the `attribution`.
  void toggleAttribution(dynamic attribution, TextRange range) {
    _spans.toggleAttribution(attribution: attribution, start: range.start, end: range.end);
  }

  TextSpan computeTextSpan(AttributionStyleBuilder styleBuilder) {
    print('computeTextSpan() - text length: ${text.length}');
    print(' - attributions used to compute spans:');
    print(_spans);

    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      print(' - text is empty. Returning empty TextSpan.');
      return TextSpan(text: '', style: styleBuilder({}));
    }

    final collapsedSpans = _spans.collapseSpans();
    final textSpans = collapsedSpans
        .map((attributedSpan) => TextSpan(
              text: text.substring(attributedSpan.start, attributedSpan.end + 1),
              style: styleBuilder(attributedSpan.attributions),
            ))
        .toList();

    return textSpans.length == 1
        ? textSpans.first
        : TextSpan(
            children: textSpans,
            style: styleBuilder({}),
          );
  }

  /// Copies all text and attributions from `startOffset` to
  /// `endOffset`, inclusive.
  AttributedText copyText(int startOffset, [int? endOffset]) {
    print('copyText() - start: $startOffset, end: $endOffset');

    // Note: -1 because copyText() uses an exclusive `start` and `end` but
    // _copyAttributionRegion() uses an inclusive `start` and `end`.
    final startCopyOffset = startOffset < text.length ? startOffset : text.length - 1;
    int endCopyOffset;
    if (endOffset == startOffset) {
      endCopyOffset = startCopyOffset;
    } else if (endOffset != null) {
      endCopyOffset = endOffset - 1;
    } else {
      endCopyOffset = text.length - 1;
    }
    print(' - copy offsets, start: $startCopyOffset, end: $endCopyOffset');

    return AttributedText(
      text: text.substring(startOffset, endOffset),
      attributions: _spans.copyAttributionRegion(startCopyOffset, endCopyOffset).attributions,
    );
  }

  /// Copies this `AttributedText` and appends the text and spans
  /// in the `other` AttributedText` to the end of the copy.
  AttributedText copyAndAppend(AttributedText other) {
    print('copyAndAppend()');
    print(' - our attributions before pushing them:');
    print(_spans);
    if (other.text.isEmpty) {
      print(' - `other` has no text. Returning a direct copy of ourselves.');
      return AttributedText(
        text: text,
        attributions: _spans.copy().attributions,
      );
    }

    final newSpans = _spans.copy()..addToEnd(other._spans);
    return AttributedText(
      text: text + other.text,
      attributions: newSpans.attributions,
    );
  }

  /// Returns a copy of this `AttributedText` with `textToInsert`
  /// inserted at `startOffset`.
  ///
  /// Any attributions that spanned `startOffset` are applied to
  /// the inserted text. All spans that start after `startOffset`
  /// are pushed back by the length of `textToInsert`.
  AttributedText insertString({
    required String textToInsert,
    required int startOffset,
    Set<dynamic> applyAttributions = const {},
  }) {
    print('insertString() - text: "$textToInsert", start: $startOffset, attributions: $applyAttributions');

    print(' - copying text to the left');
    final startText = this.copyText(0, startOffset);
    print(' - startText: $startText');

    print(' - copying text to the right');
    final endText = this.copyText(startOffset);
    print(' - endText: $endText');

    print(' - creating new attributed text for insertion');
    final insertedText = AttributedText(
      text: textToInsert,
    );
    final insertTextRange = TextRange(start: 0, end: textToInsert.length - 1);
    for (dynamic attribution in applyAttributions) {
      insertedText.addAttribution(attribution, insertTextRange);
    }
    print(' - insertedText: $insertedText');

    print(' - combining left text, insertion text, and right text');
    return startText.copyAndAppend(insertedText).copyAndAppend(endText);
  }

  /// Cuts a region of text and attributions from `startOffset`,
  /// inclusive, to `endOffset`, exclusive.
  AttributedText removeRegion({
    required int startOffset,
    required int endOffset,
  }) {
    print('Removing text region from $startOffset to $endOffset');
    print(' - initial attributions:');
    print(_spans);
    final reducedText = (startOffset > 0 ? text.substring(0, startOffset) : '') +
        (endOffset < text.length ? text.substring(endOffset) : '');

    AttributedSpans contractedAttributions = _spans.copy()
      ..contractAttributions(
        startOffset: startOffset,
        count: endOffset - startOffset,
      );
    print(' - reduced text length: ${reducedText.length}');
    print(' - remaining attributions:');
    print(contractedAttributions);

    return AttributedText(
      text: reducedText,
      attributions: contractedAttributions.attributions,
    );
  }

  @override
  String toString() {
    return '[AttributedText] - "$text"\n' + _spans.toString();
  }
}

/// Creates the desired `TextStyle` given the `attributions` associated
/// with a span of text.
///
/// The `attributions` set may be empty.
typedef AttributionStyleBuilder = TextStyle Function(Set<dynamic> attributions);
