import 'attributed_spans.dart';
import 'attribution.dart';
import 'logging.dart';
import 'span_range.dart';

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
// TODO: there is a mixture of mutable and immutable behavior in this class.
//       Pick one or the other, or offer 2 classes: mutable and immutable (#113)
class AttributedText {
  AttributedText({
    this.text = '',
    AttributedSpans? spans,
  }) : spans = spans ?? AttributedSpans();

  void dispose() {
    _listeners.clear();
  }

  /// The text that this [AttributedText] attributes.
  final String text;

  /// The attributes applied to [text].
  final AttributedSpans spans;

  final _listeners = <VoidCallback>{};

  bool get hasListeners => _listeners.isNotEmpty;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

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
    required SpanRange range,
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
    required SpanRange range,
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
  Set<Attribution> getAllAttributionsThroughout(SpanRange range) {
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
    required SpanRange range,
    bool resizeSpansToFitInRange = false,
  }) {
    return spans.getAttributionSpansInRange(
      attributionFilter: attributionFilter,
      start: range.start,
      end: range.end,
      resizeSpansToFitInRange: resizeSpansToFitInRange,
    );
  }

  /// Returns the range about [offset], which is attributed with all given [attributions].
  ///
  /// [attributions] must not be empty.
  SpanRange getAttributedRange(Set<Attribution> attributions, int offset) {
    return spans.getAttributedRange(attributions, offset);
  }

  /// Adds the given [attribution] to all characters within the given
  /// [range], inclusive.
  void addAttribution(Attribution attribution, SpanRange range) {
    spans.addAttribution(newAttribution: attribution, start: range.start, end: range.end);
    _notifyListeners();
  }

  /// Removes the given [attribution] from all characters within the
  /// given [range], inclusive.
  void removeAttribution(Attribution attribution, SpanRange range) {
    spans.removeAttribution(attributionToRemove: attribution, start: range.start, end: range.end);
    _notifyListeners();
  }

  /// Removes all attributions within the given [range].
  void clearAttributions(SpanRange range) {
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
  void toggleAttribution(Attribution attribution, SpanRange range) {
    spans.toggleAttribution(attribution: attribution, start: range.start, end: range.end);
    _notifyListeners();
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
    final insertTextRange = SpanRange(start: 0, end: textToInsert.length - 1);
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
    final startingAttributions = Set<Attribution>();
    final endingAttributions = Set<Attribution>();
    int currentIndex = -1;

    visitor.onVisitBegin();

    for (final marker in spans.markers) {
      // If the marker offset differs from the currentIndex it means
      // we already added all the attributions that start or end
      // at currentIndex.
      if (marker.offset != currentIndex) {
        if (currentIndex >= 0) {
          visitor.visitAttributions(this, currentIndex, startingAttributions, endingAttributions);
        }

        currentIndex = marker.offset;
        startingAttributions.clear();
        endingAttributions.clear();
      }

      if (marker.isStart) {
        startingAttributions.add(marker.attribution);
      } else {
        endingAttributions.add(marker.attribution);
      }
    }

    // Visit the final set of end markers.
    if (endingAttributions.isNotEmpty) {
      visitor.visitAttributions(this, currentIndex, startingAttributions, endingAttributions);
    }

    visitor.onVisitEnd();
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

/// Visits every [index] in the the given [AttributedText] which has at least
/// one start or end marker, passing the attributions that start or end at the [index].
///
/// Note: most range-based operations expect the
/// closing [index] to be exclusive, but that is not how this callback
/// works. Both the start and end [index]es are inclusive.
typedef VisitAttributionsCallback = void Function(
  AttributedText fullText,
  int index,
  Set<Attribution> startingAttributions,
  Set<Attribution> endingAttributions,
);

enum AttributionVisitEvent {
  start,
  end,
}

/// Visitor that visits every start and end attribution marker in an [AttributedText]
abstract class AttributionVisitor {
  /// Called before visiting attributions, so that implementers can perform any desired setup.
  void onVisitBegin() {}

  /// Visits all starting and ending attribution markers at the given [index] within [fullText].
  ///
  /// This method isn't called for indices that don't contain any attribution markers.
  void visitAttributions(
    AttributedText fullText,
    int index,
    Set<Attribution> startingAttributions,
    Set<Attribution> endingAttributions,
  );

  /// Called after all attribution markers have been visited by [visitAttributions].
  void onVisitEnd() {}
}

/// [AttributionVisitor] that delegates to given callbacks.
class CallbackAttributionVisitor implements AttributionVisitor {
  CallbackAttributionVisitor({
    VoidCallback? onVisitBegin,
    required VisitAttributionsCallback visitAttributions,
    VoidCallback? onVisitEnd,
  })  : _onVisitBegin = onVisitBegin,
        _onVisitAttributions = visitAttributions,
        _onVisitEnd = onVisitEnd;

  final VoidCallback? _onVisitBegin;
  final VisitAttributionsCallback _onVisitAttributions;
  final VoidCallback? _onVisitEnd;

  @override
  void onVisitBegin() {
    _onVisitBegin?.call();
  }

  @override
  void visitAttributions(AttributedText fullText, int index, Set<Attribution> startingAttributions, Set<Attribution> endingAttributions) {
    _onVisitAttributions(fullText, index, startingAttributions, endingAttributions);
  }

  @override
  void onVisitEnd() {
    _onVisitEnd?.call();
  }
}

/// A zero-parameter function that returns nothing.
///
/// This is the same as Flutter's `VoidCallback`. It's replicated in this
/// project to avoid depending on Flutter.
typedef VoidCallback = void Function();
