import 'package:attributed_text/attributed_text.dart';

/// An [Attribution] that logs the timestamp when a piece of content was created,
/// such as typing text, or inserting an image.
class CreatedAtAttribution implements Attribution {
  const CreatedAtAttribution({
    required this.start,
  });

  final DateTime start;

  @override
  String get id => 'created-at';

  @override
  bool canMergeWith(Attribution other) {
    if (other is! CreatedAtAttribution) {
      return false;
    }

    return start == other.start;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatedAtAttribution && runtimeType == other.runtimeType && start == other.start;

  @override
  int get hashCode => start.hashCode;
}
