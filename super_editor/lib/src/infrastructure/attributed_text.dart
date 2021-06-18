import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart';

import '_logging.dart';
import 'attributed_spans.dart';

final _log = attributionsLog;

/// Text with attributions applied to desired spans of text.
///
/// An attribution can be any subclass of [Attribution].
///
/// [AttributedText] is a convenient way to store and manipulate
/// text that might have overlapping styles and/or non-style
/// attributions. A common Flutter alternative is [TextSpan], but
/// [TextSpan] does not support overlapping styles, and [TextSpan]
/// is exclusively intended for visual text styles.
///
/// To style Flutter text, [AttributedText] produces a
/// corresponding [TextSpan] with [computeTextSpan()]. Clients
/// style the text by providing an [AttributionStyleBuilder],
/// which is responsible for interpreting the meaning of all
/// attributions applied to this [AttributedText].
// TODO: there is a mixture of mutable and immutable behavior in this class.
//       Pick one or the other, or offer 2 classes: mutable and immutable (#113)
class AttributedText with ChangeNotifier {
  AttributedText({
    this.text = '',
    AttributedSpans? spans,
  }) : spans = spans ?? AttributedSpans();

  /// The text that this [AttributedText] attributes.
  final String text;

  /// The attributes applied to [text].
  final AttributedSpans spans;

  /// Returns true if the given [attribution] is applied at [offset].
  ///
  /// If the given [attribution] is [null], returns [true] if any attribution
  /// exists at the given [offset].
  bool hasAttributionAt(
    int offset, {
    Attribution? attribution,
  }) {
    return spans.hasAttributionAt(offset, attribution: attribution);
  }

  /// Returns true if this [AttributedText] contains at least one
  /// character with each of the given [attributions] within the
  /// given [range] (inclusive).
  bool hasAttributionsWithin({
    required Set<Attribution> attributions,
    required TextRange range,
  }) {
    return spans.hasAttributionsWithin(
      attributions: attributions,
      start: range.start,
      end: range.end,
    );
  }

  /// Returns true if this [AttributedText] contains each of the
  /// given [attributions] throughout the given [range] (inclusive).
  bool hasAttributionsThroughout({
    required Set<Attribution> attributions,
    required TextRange range,
  }) {
    for (int i = range.start; i <= range.end; i += 1) {
      for (final attribution in attributions) {
        if (!spans.hasAttributionAt(i, attribution: attribution)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Returns all attributions applied to the given [offset].
  Set<Attribution> getAllAttributionsAt(int offset) {
    return spans.getAllAttributionsAt(offset);
  }

  /// Returns all attributions that appear throughout the entirety
  /// of the given [range].
  Set<Attribution> getAllAttributionsThroughout(TextRange range) {
    final attributionsThroughout = spans.getAllAttributionsAt(range.start);
    int index = range.start + 1;

    while (index <= range.end && attributionsThroughout.isNotEmpty) {
      final missingAttributions = <Attribution>{};
      for (final attribution in attributionsThroughout) {
        if (!hasAttributionAt(index)) {
          missingAttributions.add(attribution);
        }
      }
      attributionsThroughout.removeAll(missingAttributions);
      index += 1;
    }

    return attributionsThroughout;
  }

  /// Returns spans for each attribution that (at least partially) appear
  /// within the given [range], as selected by [attributionFilter].
  ///
  /// By default, the returned spans represent the full, contiguous span
  /// of each attribution. This means that if a portion of an attribution
  /// appears within the given [range], the entire attribution span is
  /// returned, including the area that sits outside the given [range].
  ///
  /// To obtain attribution spans that are cut down and limited to the
  /// given [range], pass [true] for [resizeSpansToFitInRange]. This setting
  /// only effects the returned spans, it does not alter the attributions
  /// within this [AttributedText].
  Set<AttributionSpan> getAttributionSpansInRange({
    required AttributionFilter attributionFilter,
    required TextRange range,
    bool resizeSpansToFitInRange = false,
  }) {
    return spans.getAttributionSpansInRange(
      attributionFilter: attributionFilter,
      start: range.start,
      end: range.end,
      resizeSpansToFitInRange: resizeSpansToFitInRange,
    );
  }

  /// Adds the given [attribution] to all characters within the given
  /// [range], inclusive.
  void addAttribution(Attribution attribution, TextRange range) {
    spans.addAttribution(newAttribution: attribution, start: range.start, end: range.end);
    notifyListeners();
  }

  /// Removes the given [attribution] from all characters within the
  /// given [range], inclusive.
  void removeAttribution(Attribution attribution, TextRange range) {
    spans.removeAttribution(attributionToRemove: attribution, start: range.start, end: range.end);
    notifyListeners();
  }

  /// Removes all attributions within the given [range].
  void clearAttributions(TextRange range) {
    // TODO: implement this capability within AttributedSpans
    //       This implementation uses existing round-about functionality
    //       to avoid adding new complexity to AttributedSpans while
    //       working on unrelated behavior (mobile text fields - Sept 17, 2021).
    //       Come back and implement clearAttributions in AttributedSpans
    //       in an efficient manner and add tests for it.
    final attributions = <Attribution>{};
    for (var i = range.start; i <= range.end; i += 1) {
      attributions.addAll(spans.getAllAttributionsAt(i));
    }
    for (final attribution in attributions) {
      spans.removeAttribution(attributionToRemove: attribution, start: range.start, end: range.end);
    }
  }

  /// If ALL of the text in [range], inclusive, contains the given [attribution],
  /// that [attribution] is removed from the text in [range], inclusive.
  /// Otherwise, all of the text in [range], inclusive, is given the [attribution].
  void toggleAttribution(Attribution attribution, TextRange range) {
    spans.toggleAttribution(attribution: attribution, start: range.start, end: range.end);
    notifyListeners();
  }

  /// Copies all text and attributions from [startOffset] to
  /// [endOffset], inclusive, and returns them as a new [AttributedText].
  AttributedText copyText(int startOffset, [int? endOffset]) {
    _log.fine('start: $startOffset, end: $endOffset');

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
    _log.fine('offsets, start: $startCopyOffset, end: $endCopyOffset');

    return AttributedText(
      text: text.substring(startOffset, endOffset),
      spans: spans.copyAttributionRegion(startCopyOffset, endCopyOffset),
    );
  }

  /// Returns a copy of this [AttributedText] with the [other] text
  /// and attributions appended to the end.
  AttributedText copyAndAppend(AttributedText other) {
    _log.fine('our attributions before pushing them:');
    _log.fine(spans.toString());
    if (other.text.isEmpty) {
      _log.fine('`other` has no text. Returning a direct copy of ourselves.');
      return AttributedText(
        text: text,
        spans: spans.copy(),
      );
    }
    if (text.isEmpty) {
      _log.fine('our `text` is empty. Returning a direct copy of the `other` text.');
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

  /// Returns a copy of this [AttributedText] with [textToInsert] inserted
  /// at [startOffset], retaining whatever attributions are already applied
  /// to [textToInsert].
  AttributedText insert({
    required AttributedText textToInsert,
    required int startOffset,
  }) {
    final startText = copyText(0, startOffset);
    final endText = copyText(startOffset);
    return startText.copyAndAppend(textToInsert).copyAndAppend(endText);
  }

  /// Returns a copy of this [AttributedText] with [textToInsert]
  /// inserted at [startOffset].
  ///
  /// Any attributions that span [startOffset] are applied to all
  /// of the inserted text. All spans that start after [startOffset]
  /// are pushed back by the length of [textToInsert].
  AttributedText insertString({
    required String textToInsert,
    required int startOffset,
    Set<Attribution> applyAttributions = const {},
  }) {
    _log.fine('text: "$textToInsert", start: $startOffset, attributions: $applyAttributions');

    _log.fine('copying text to the left');
    final startText = copyText(0, startOffset);
    _log.fine('startText: $startText');

    _log.fine('copying text to the right');
    final endText = copyText(startOffset);
    _log.fine('endText: $endText');

    _log.fine('creating new attributed text for insertion');
    final insertedText = AttributedText(
      text: textToInsert,
    );
    final insertTextRange = TextRange(start: 0, end: textToInsert.length - 1);
    for (dynamic attribution in applyAttributions) {
      insertedText.addAttribution(attribution, insertTextRange);
    }
    _log.fine('insertedText: $insertedText');

    _log.fine('combining left text, insertion text, and right text');
    return startText.copyAndAppend(insertedText).copyAndAppend(endText);
  }

  /// Copies this [AttributedText] and removes  a region of text
  /// and attributions from [startOffset], inclusive,
  /// to [endOffset], exclusive.
  AttributedText removeRegion({
    required int startOffset,
    required int endOffset,
  }) {
    _log.fine('Removing text region from $startOffset to $endOffset');
    _log.fine('initial attributions:');
    _log.fine(spans.toString());
    final reducedText = (startOffset > 0 ? text.substring(0, startOffset) : '') +
        (endOffset < text.length ? text.substring(endOffset) : '');

    AttributedSpans contractedAttributions = spans.copy()
      ..contractAttributions(
        startOffset: startOffset,
        count: endOffset - startOffset,
      );
    _log.fine('reduced text length: ${reducedText.length}');
    _log.fine('remaining attributions:');
    _log.fine(contractedAttributions.toString());

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

  /// Returns a Flutter [TextSpan] that is styled based on the
  /// attributions within this [AttributedText].
  ///
  /// The given [styleBuilder] interprets the meaning of every
  /// attribution and constructs [TextStyle]s accordingly.
  // TODO: remove this method and use [visitAttributions()] to compute TextSpan
  TextSpan computeTextSpan(AttributionStyleBuilder styleBuilder) {
    _log.fine('text length: ${text.length}');
    _log.fine('attributions used to compute spans:');
    _log.fine(spans.toString());

    if (text.isEmpty) {
      // There is no text and therefore no attributions.
      _log.fine('text is empty. Returning empty TextSpan.');
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
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AttributedText && runtimeType == other.runtimeType && text == other.text && spans == other.spans;
  }

  @override
  int get hashCode => text.hashCode ^ spans.hashCode;

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
    AttributedText fullText, int index, Set<Attribution> attributions, AttributionVisitEvent event);

enum AttributionVisitEvent {
  start,
  end,
}

/// Creates the desired [TextStyle] given the [attributions] associated
/// with a span of text.
///
/// The [attributions] set may be empty.
typedef AttributionStyleBuilder = TextStyle Function(Set<Attribution> attributions);
