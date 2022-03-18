/// A range of characters in a string of text, based on Flutter's `TextRange`.
///
/// This was copied from Flutter so that attributed_text could be distributed
/// as a Dart package, instead of a Flutter package.
class SpanRange {
  /// Creates a text range.
  ///
  /// The [start] and [end] arguments must not be null. Both the [start] and
  /// [end] must either be greater than or equal to zero or both exactly -1.
  ///
  /// The text included in the range includes the character at [start], but not
  /// the one at [end].
  ///
  /// Instead of creating an empty text range, consider using the [empty]
  /// constant.
  const SpanRange({
    required this.start,
    required this.end,
  })  : assert(start >= -1),
        assert(end >= -1);

  /// A text range that starts and ends at offset.
  ///
  /// The [offset] argument must be non-null and greater than or equal to -1.
  const SpanRange.collapsed(int offset)
      : assert(offset >= -1),
        start = offset,
        end = offset;

  /// A text range that contains nothing and is not in the text.
  static const SpanRange empty = SpanRange(start: -1, end: -1);

  /// The index of the first character in the range.
  ///
  /// If [start] and [end] are both -1, the text range is empty.
  final int start;

  /// The next index after the characters in this range.
  ///
  /// If [start] and [end] are both -1, the text range is empty.
  final int end;

  /// Whether this range represents a valid position in the text.
  bool get isValid => start >= 0 && end >= 0;

  /// Whether this range is empty (but still potentially placed inside the text).
  bool get isCollapsed => start == end;

  /// Whether the start of this range precedes the end.
  bool get isNormalized => end >= start;

  /// The text before this range.
  String textBefore(String text) {
    assert(isNormalized);
    return text.substring(0, start);
  }

  /// The text after this range.
  String textAfter(String text) {
    assert(isNormalized);
    return text.substring(end);
  }

  /// The text inside this range.
  String textInside(String text) {
    assert(isNormalized);
    return text.substring(start, end);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpanRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  String toString() => 'TextRange(start: $start, end: $end)';
}
