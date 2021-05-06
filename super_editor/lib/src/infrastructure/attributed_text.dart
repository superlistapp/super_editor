import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart';

import 'attributed_spans.dart';
import '_logging.dart';

final _log = Logger(scope: 'AttributedText');

/// Text with attributions applied to desired spans of text.
///
/// An attribution can be any object as long as each attribution
/// object implements equality. A `String` is typically a good
/// choice to use as an attribution type.
///
/// `AttributedText` is a convenient way to store and manipulate
/// text that might have overlapping styles and/or non-style
/// attributions. A common Flutter alternative is `TextSpan`, but
/// `TextSpan` does not support overlapping styles, and `TextSpan`
/// is exclusively intended for visual text styles.
///
/// To style Flutter text, `AttributedText` produces a
/// corresponding `TextSpan` with `computeTextSpan()`. Clients
/// style the text by providing an `AttributionStyleBuilder`,
/// which is responsible for interpreting the meaning of all
/// attributions applied to this `AttributedText`.
// TODO: there is a mixture of mutable and immutable behavior in this class.
//       Pick one or the other, or offer 2 classes: mutable and immutable (#113)
class AttributedText with ChangeNotifier {
  AttributedText({
    this.text = '',
    AttributedSpans? spans,
  }) : spans = spans ?? AttributedSpans();

  /// The text that this `AttributedText` attributes.
  final String text;

  /// The attributes applied to `text`.
  final AttributedSpans spans;

  /// Returns true if the given `attribution` is applied at `offset`.
  ///
  /// If the given `attribution` is null, returns `true` if any attribution
  /// exists at the given `offset`.
  bool hasAttributionAt(
    int offset, {
    dynamic attribution,
  }) {
    return spans.hasAttributionAt(offset, attribution: attribution);
  }

  /// Returns true if this `AttributedText` contains at least one
  /// character with each of the given `attributions` within the
  /// given `range` (inclusive).
  bool hasAttributionsWithin({
    required Set<dynamic> attributions,
    required TextRange range,
  }) {
    return spans.hasAttributionsWithin(
      attributions: attributions,
      start: range.start,
      end: range.end,
    );
  }

  /// Returns all attributions applied to the given `offset`.
  Set<dynamic> getAllAttributionsAt(int offset) {
    return spans.getAllAttributionsAt(offset);
  }

  /// Adds the given attribution to all characters within the given
  /// `range`, inclusive.
  void addAttribution(dynamic attribution, TextRange range) {
    spans.addAttribution(newAttribution: attribution, start: range.start, end: range.end);
    notifyListeners();
  }

  /// Removes the given attribution from all characters within the
  /// given `range`, inclusive.
  void removeAttribution(dynamic attribution, TextRange range) {
    spans.addAttribution(newAttribution: attribution, start: range.start, end: range.end);
    notifyListeners();
  }

  /// If ALL of the text in `range`, inclusive, contains the given `attribution`,
  /// that attribution is removed from the text in `range`, inclusive.
  /// Otherwise, all of the text in `range`, inclusive, is given the `attribution`.
  void toggleAttribution(dynamic attribution, TextRange range) {
    spans.toggleAttribution(attribution: attribution, start: range.start, end: range.end);
    notifyListeners();
  }

  /// Copies all text and attributions from `startOffset` to
  /// `endOffset`, inclusive, and returns them as a new `AttributedText`.
  AttributedText copyText(int startOffset, [int? endOffset]) {
    _log.log('copyText', 'start: $startOffset, end: $endOffset');

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
    _log.log('copyText', 'offsets, start: $startCopyOffset, end: $endCopyOffset');

    return AttributedText(
      text: text.substring(startOffset, endOffset),
      spans: spans.copyAttributionRegion(startCopyOffset, endCopyOffset),
    );
  }

  /// Returns a copy of this `AttributedText` with the `other` text
  /// and attributions appended to the end.
  AttributedText copyAndAppend(AttributedText other) {
    _log.log('copyAndAppend', 'our attributions before pushing them:');
    _log.log('copyAndAppend', spans.toString());
    if (other.text.isEmpty) {
      _log.log('copyAndAppend', '`other` has no text. Returning a direct copy of ourselves.');
      return AttributedText(
        text: text,
        spans: spans.copy(),
      );
    }
    if (text.isEmpty) {
      _log.log('copyAndAppend', 'our `text` is empty. Returning a direct copy of the `other` text.');
      return AttributedText(
        text: other.text,
        spans: other.spans.copy(),
      );
    }

    final newSpans = spans.copy()..addAt(other: other.spans, index: text.length);
    return AttributedText(
      text: text + other.text,
      spans: newSpans,
    );
  }

  /// Returns a copy of this `AttributedText` with `textToInsert`
  /// inserted at `startOffset`.
  ///
  /// Any attributions that span `startOffset` are applied to all
  /// of the inserted text. All spans that start after `startOffset`
  /// are pushed back by the length of `textToInsert`.
  AttributedText insertString({
    required String textToInsert,
    required int startOffset,
    Set<dynamic> applyAttributions = const {},
  }) {
    _log.log('insertString', 'text: "$textToInsert", start: $startOffset, attributions: $applyAttributions');

    _log.log('insertString', 'copying text to the left');
    final startText = this.copyText(0, startOffset);
    _log.log('insertString', 'startText: $startText');

    _log.log('insertString', 'copying text to the right');
    final endText = this.copyText(startOffset);
    _log.log('insertString', 'endText: $endText');

    _log.log('insertString', 'creating new attributed text for insertion');
    final insertedText = AttributedText(
      text: textToInsert,
    );
    final insertTextRange = TextRange(start: 0, end: textToInsert.length - 1);
    for (dynamic attribution in applyAttributions) {
      insertedText.addAttribution(attribution, insertTextRange);
    }
    _log.log('insertString', 'insertedText: $insertedText');

    _log.log('insertString', 'combining left text, insertion text, and right text');
    return startText.copyAndAppend(insertedText).copyAndAppend(endText);
  }

  /// Copies this `AttributedText` and removes  a region of text
  /// and attributions from `startOffset`, inclusive,
  /// to `endOffset`, exclusive.
  AttributedText removeRegion({
    required int startOffset,
    required int endOffset,
  }) {
    _log.log('removeRegion', 'Removing text region from $startOffset to $endOffset');
    _log.log('removeRegion', 'initial attributions:');
    _log.log('removeRegion', spans.toString());
    final reducedText = (startOffset > 0 ? text.substring(0, startOffset) : '') +
        (endOffset < text.length ? text.substring(endOffset) : '');

    AttributedSpans contractedAttributions = spans.copy()
      ..contractAttributions(
        startOffset: startOffset,
        count: endOffset - startOffset,
      );
    _log.log('removeRegion', 'reduced text length: ${reducedText.length}');
    _log.log('removeRegion', 'remaining attributions:');
    _log.log('removeRegion', contractedAttributions.toString());

    return AttributedText(
      text: reducedText,
      spans: contractedAttributions,
    );
  }

  void visitAttributions(AttributionVisitor visitor) {
    final collapsedSpans = spans.collapseSpans(contentLength: text.length);
    for (final span in collapsedSpans) {
      visitor(this, span.start, span.attributions, AttributionVisitEvent.start);
      visitor(this, span.end, span.attributions, AttributionVisitEvent.end);
    }
  }

  /// Returns a Flutter `TextSpan` that is styled based on the
  /// attributions within this `AttributedText`.
  ///
  /// The given `styleBuilder` interprets the meaning of every
  /// attribution and constructs `TextStyle`s accordingly.
  // TODO: remove this method and use [visitAttributions()] to compute TextSpan
  TextSpan computeTextSpan(AttributionStyleBuilder styleBuilder) {
    _log.log('computeTextSpan', 'text length: ${text.length}');
    _log.log('computeTextSpan', 'attributions used to compute spans:');
    _log.log('computeTextSpan', spans.toString());

    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      _log.log('computeTextSpan', 'text is empty. Returning empty TextSpan.');
      return TextSpan(text: '', style: styleBuilder({}));
    }

    final collapsedSpans = spans.collapseSpans(contentLength: text.length);
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

  @override
  String toString() {
    return '[AttributedText] - "$text"\n' + spans.toString();
  }
}

/// Visits the [start] and [end] of every span of attributions in
/// the given [AttributedText].
///
/// The [index] is the [String] index of the character where the span
/// either begins or ends. Note: most range-based operations expect the
/// closing index to be exclusive, but that is not how this callback
/// works. Both the [start] and [end] [index]es are inclusive.
typedef AttributionVisitor = void Function(
    AttributedText fullText, int index, Set<dynamic> attributions, AttributionVisitEvent event);

enum AttributionVisitEvent {
  start,
  end,
}

/// Creates the desired `TextStyle` given the `attributions` associated
/// with a span of text.
///
/// The `attributions` set may be empty.
typedef AttributionStyleBuilder = TextStyle Function(Set<dynamic> attributions);
