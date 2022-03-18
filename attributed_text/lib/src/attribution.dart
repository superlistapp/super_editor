/// An attribution that can be associated with a span within
/// an [AttributedSpan].
///
/// To attribute a span with a name, consider using a
/// [NamedAttribution].
abstract class Attribution {
  /// Attributions with different IDs can overlap each
  /// other, but attributions with the same ID cannot
  /// overlap.
  ///
  /// For example, consider the use of attributions within
  /// [AttributedText]. One attribution might have an ID
  /// of "bold" and another might have an of "italics". Those
  /// attributions can overlap at the same location. However,
  /// two attributions both with the ID of "bold" cannot overlap.
  /// The matching attributions can only be combined into a new,
  /// larger attributed span.
  String get id;

  /// Returns [true] if this [Attribution] can be combined with
  /// the [other] [Attribution], replacing both smaller attributions
  /// with one larger attribution.
  bool canMergeWith(Attribution other);
}

/// [Attribution] that is defined by a given [String].
///
/// Any two [NamedAttribution]s with the same [id]/[name] are
/// considered equivalent and merge-able.
class NamedAttribution implements Attribution {
  const NamedAttribution(this.id);

  @override
  final String id;

  String get name => id;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  String toString() {
    return '[NamedAttribution]: $name';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NamedAttribution && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
