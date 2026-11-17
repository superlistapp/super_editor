import 'package:attributed_text/attributed_text.dart';
import 'package:test/test.dart';

void main() {
  group('Spans queries', () {
    late _CountingAttribution counting;
    late AttributedSpans spans;

    setUp(() {
      counting = _CountingAttribution();
      spans = AttributedSpans(
        attributions: [
          for (var i = 0; i < 20; i++) ...[
            SpanMarker(attribution: counting, offset: i * 25, markerType: SpanMarkerType.start),
            SpanMarker(attribution: counting, offset: i * 25 + 10, markerType: SpanMarkerType.end),
          ],
        ],
      );
      _CountingAttribution.comparisons = 0;
    });

    test('getAttributionSpansInRange does not compare attributions per character', () {
      final result = spans.getAttributionSpansInRange(
        attributionFilter: (attribution) => attribution == counting,
        start: 0,
        end: 499,
      );

      expect(result, hasLength(20));
      expect(_CountingAttribution.comparisons, lessThanOrEqualTo(spans.markers.length));
    });

    test('getAttributionSpansInRange skips text without matching attributions', () {
      final result = spans.getAttributionSpansInRange(
        attributionFilter: (attribution) => false,
        start: 0,
        end: 499,
      );

      expect(result, isEmpty);
      expect(_CountingAttribution.comparisons, 0);
    });

    test('getMatchingAttributionsWithin does not compare attributions per character', () {
      final result = spans.getMatchingAttributionsWithin(attributions: {counting}, start: 0, end: 499);

      expect(result, {counting});
      expect(_CountingAttribution.comparisons, lessThanOrEqualTo(spans.markers.length));
    });
  });
}

class _CountingAttribution implements Attribution {
  static int comparisons = 0;

  @override
  String get id => 'counting';

  @override
  bool canMergeWith(Attribution other) => identical(this, other);

  @override
  bool operator ==(Object other) {
    comparisons++;
    return identical(this, other);
  }

  @override
  int get hashCode => 0;
}
