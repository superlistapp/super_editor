import 'package:attributed_text/attributed_text.dart';
import 'package:attributed_text/src/logging.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_tools.dart';

void main() {
  groupWithLogging('Spans', Level.OFF, {attributionsLog}, () {
    group('attribution queries', () {
      test('it expands a span from a given offset', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: ExpectedSpans.bold, start: 3, end: 16);
        final expandedSpan = spans.expandAttributionToSpan(attribution: ExpectedSpans.bold, offset: 6);

        expect(
          expandedSpan,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 3,
              end: 16,
            ),
          ),
        );
      });

      test('it returns spans that fit within a range', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 2)
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 5, end: 10);
        final attributionSpans = spans.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == ExpectedSpans.bold,
          start: 3,
          end: 15,
        );

        expect(attributionSpans.length, 1);
        expect(
          attributionSpans.first,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 5,
              end: 10,
            ),
          ),
        );
      });

      test('it returns spans that partially overlap range', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 3, end: 7)
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 10, end: 15);
        final attributionSpans = spans.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == ExpectedSpans.bold,
          start: 5,
          end: 12,
        );

        expect(attributionSpans.length, 2);
        expect(
          attributionSpans.first,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 3,
              end: 7,
            ),
          ),
        );
        expect(
          attributionSpans.last,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 10,
              end: 15,
            ),
          ),
        );
      });

      test('it returns spans that completely cover the range', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 10);
        final attributionSpans = spans.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == ExpectedSpans.bold,
          start: 3,
          end: 8,
        );

        expect(attributionSpans.length, 1);
        expect(
          attributionSpans.first,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 0,
              end: 10,
            ),
          ),
        );
      });

      test('it resizes spans that partially overlap range', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 3, end: 7)
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 10, end: 15);
        final attributionSpans = spans.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == ExpectedSpans.bold,
          start: 5,
          end: 12,
          resizeSpansToFitInRange: true,
        );

        expect(attributionSpans.length, 2);
        expect(
          attributionSpans.first,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 5,
              end: 7,
            ),
          ),
        );
        expect(
          attributionSpans.last,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 10,
              end: 12,
            ),
          ),
        );
      });

      test('it resizes spans that completely cover the range', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 10);
        final attributionSpans = spans.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == ExpectedSpans.bold,
          start: 3,
          end: 8,
          resizeSpansToFitInRange: true,
        );

        expect(attributionSpans.length, 1);
        expect(
          attributionSpans.first,
          equals(
            const AttributionSpan(
              attribution: ExpectedSpans.bold,
              start: 3,
              end: 8,
            ),
          ),
        );
      });

      test('hasAttributionsWithin can look for multiple attributions at the same time', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 8)
          ..addAttribution(newAttribution: ExpectedSpans.italics, start: 1, end: 5)
          ..addAttribution(newAttribution: ExpectedSpans.strikethrough, start: 5, end: 9);

        ExpectedSpans(
          [
            'bbbbbbbbb_',
            '_iiiii____',
            '_____sssss',
          ],
        ).expectSpans(spans);

        expect(
          spans.hasAttributionsWithin(attributions: {
            ExpectedSpans.bold,
            ExpectedSpans.italics,
            ExpectedSpans.strikethrough,
          }, start: 0, end: 9),
          true,
        );

        expect(
          spans.hasAttributionsWithin(attributions: {
            ExpectedSpans.bold,
            ExpectedSpans.italics,
          }, start: 0, end: 9),
          true,
        );

        expect(
            spans.hasAttributionsWithin(attributions: {
              ExpectedSpans.bold,
              ExpectedSpans.italics,
            }, start: 0, end: 4),
            true);

        expect(
          spans.hasAttributionsWithin(attributions: {
            ExpectedSpans.bold,
            ExpectedSpans.strikethrough,
          }, start: 0, end: 4),
          false,
        );
      });

      group('getAttributedRange', () {
        test('returns the range of a single attribution for an offset in the middle of a span', () {
          final spans = AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          );

          final range = spans.getAttributedRange({ExpectedSpans.bold}, 5);
          expect(range, const SpanRange(4, 9));
        });

        test('returns the range of a single attribution for an offset at the beginning of a span', () {
          final spans = AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          );

          final range = spans.getAttributedRange({ExpectedSpans.bold}, 4);
          expect(range, const SpanRange(4, 9));
        });

        test('returns the range of a single attribution for an offset at the end of a span', () {
          final spans = AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          );

          final range = spans.getAttributedRange({ExpectedSpans.bold}, 9);
          expect(range, const SpanRange(4, 9));
        });

        test('returns the range for multiple attributions for an offset in the middle of the overlapping range', () {
          final spans = AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 10, markerType: SpanMarkerType.end),
            ],
          );

          final range = spans.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 5);
          expect(range, const SpanRange(4, 7));
        });

        test('returns the range for multiple attributions for an offset at the beginning of the overlapping range', () {
          final spans = AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 10, markerType: SpanMarkerType.end),
            ],
          );

          final range = spans.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 4);
          expect(range, const SpanRange(4, 7));
        });

        test('returns the range for multiple attributions for an offset at the end of the overlapping range', () {
          final spans = AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 10, markerType: SpanMarkerType.end),
            ],
          );

          final range = spans.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 7);
          expect(range, const SpanRange(4, 7));
        });

        test('throws when given an empty attribution set', () {
          final spans = AttributedSpans();

          expect(() => spans.getAttributedRange({}, 0), throwsException);
        });

        test('throws when any attribution is not present at the given offset', () {
          final spans = AttributedSpans(
            attributions: [
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: ExpectedSpans.bold, offset: 10, markerType: SpanMarkerType.end),
            ],
          );

          expect(() => spans.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 7), throwsException);
        });
      });
    });

    group('single attribution', () {
      test('applies attribution to full span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 0, end: 16), true);
      });

      test('applies attribution to beginning of span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 0, end: 7), true);
      });

      test('applies attribution to inner span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: ExpectedSpans.bold, start: 2, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 2, end: 7), true);
      });

      test('applies attribution to end of span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: ExpectedSpans.bold, start: 7, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 7, end: 16), true);
      });

      test('applies exotic span', () {
        final linkAttribution = _LinkAttribution(
          url: 'https://youtube.com/c/superdeclarative',
        );
        final spans = AttributedSpans()..addAttribution(newAttribution: linkAttribution, start: 2, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {linkAttribution}, start: 2, end: 7), true);
      });

      test('removes attribution from full span', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 16, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 0, end: 16), false);
      });

      test('removes attribution from single unit', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end)
          ],
        );

        ExpectedSpans([
          '________b_______',
        ]).expectSpans(spans);

        spans.removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 8, end: 8);

        ExpectedSpans([
          '________________',
        ]).expectSpans(spans);
      });

      test('removes attribution from single unit at end of span', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end)
          ],
        );

        ExpectedSpans([
          'bbbbbbbb_______',
        ]).expectSpans(spans);

        spans.removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 8, end: 8);

        ExpectedSpans([
          'bbbbbbb_________',
        ]).expectSpans(spans);
      });

      test('removes attribution from all units except the last', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end)
          ],
        );

        ExpectedSpans([
          'bbbbbbbb_______',
        ]).expectSpans(spans);

        spans.removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 0, end: 7);

        ExpectedSpans([
          '________b________',
        ]).expectSpans(spans);
      });

      test('removes attribution from single unit at start of span', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end)
          ],
        );

        ExpectedSpans([
          'bbbbbbbb_______',
        ]).expectSpans(spans);

        spans.removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 0, end: 0);

        ExpectedSpans([
          '_bbbbbbb_______',
        ]).expectSpans(spans);
      });

      test('removes attribution from all units except the first', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end)
          ],
        );

        ExpectedSpans([
          'bbbbbbbb_______',
        ]).expectSpans(spans);

        spans.removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 1, end: 8);

        ExpectedSpans([
          'b________________',
        ]).expectSpans(spans);
      });

      test('removes attribution from inner text span', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 2, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 2, end: 7), false);
      });

      test('removes attribution from partial beginning span', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 2, end: 4);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 5, end: 7), true);
      });

      test('removes attribution from partial inner span', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 4, end: 5);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 2, end: 3), true);
        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 6, end: 7), true);
      });

      test('removes attribution from partial ending span', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: ExpectedSpans.bold, start: 5, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 2, end: 4), true);
      });

      test('applies attribution when mixed span is toggled', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 16, markerType: SpanMarkerType.end)
          ],
        )..toggleAttribution(attribution: ExpectedSpans.bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 0, end: 16), true);
      });

      test('removes attribution when contiguous span is toggled', () {
        final spans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 16, markerType: SpanMarkerType.end)
          ],
        )..toggleAttribution(attribution: ExpectedSpans.bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 0, end: 16), false);
      });
    });

    group('multiple attributions', () {
      test('full length overlap', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 9)
          ..addAttribution(newAttribution: ExpectedSpans.italics, start: 0, end: 9);

        ExpectedSpans([
          'bbbbbbbbbb',
          'iiiiiiiiii',
        ]).expectSpans(spans);
      });

      test('half and half', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 5, end: 9)
          ..addAttribution(newAttribution: ExpectedSpans.italics, start: 0, end: 4);

        ExpectedSpans([
          '_____bbbbb',
          'iiiii_____',
        ]).expectSpans(spans);
      });

      test('two partial overlap', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 4, end: 8)
          ..addAttribution(newAttribution: ExpectedSpans.italics, start: 1, end: 5);

        ExpectedSpans([
          '____bbbbb_',
          '_iiiii____',
        ]).expectSpans(spans);
      });

      test('three partial overlap', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 4, end: 8)
          ..addAttribution(newAttribution: ExpectedSpans.italics, start: 1, end: 5)
          ..addAttribution(newAttribution: ExpectedSpans.strikethrough, start: 5, end: 9);

        ExpectedSpans([
          '____bbbbb_',
          '_iiiii____',
          '_____sssss',
        ]).expectSpans(spans);
      });

      test('many small segments', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 0, end: 1)
          ..addAttribution(newAttribution: ExpectedSpans.italics, start: 2, end: 3)
          ..addAttribution(newAttribution: ExpectedSpans.strikethrough, start: 4, end: 5)
          ..addAttribution(newAttribution: ExpectedSpans.bold, start: 6, end: 7)
          ..addAttribution(newAttribution: ExpectedSpans.italics, start: 8, end: 9);

        ExpectedSpans([
          'bb____bb__',
          '__ii____ii',
          '____ss____',
        ]).expectSpans(spans);
      });

      test('incompatible attributions cannot overlap', () {
        final spans = AttributedSpans();

        // Add link at beginning
        spans.addAttribution(
          newAttribution: _LinkAttribution(url: 'https://flutter.dev'),
          start: 0,
          end: 6,
        );

        // Try to add a different link at the end but overlapping
        // the first link. Expect an exception.
        expect(() {
          spans.addAttribution(
            newAttribution: _LinkAttribution(url: 'https://pub.dev'),
            start: 4,
            end: 12,
            overwriteConflictingSpans: false,
          );
        }, throwsA(isA<IncompatibleOverlappingAttributionsException>()));
      });

      test('overwrites incompatible attributions at the beginning of the span', () {
        // Starting value:
        // |aaaaaaa|
        //
        // Ending value:
        // |-----aa|
        // |bbbbb--|

        final spans = AttributedSpans(
          attributions: _createSpanMarkersForAttribution(
            attribution: _LinkAttribution(url: 'https://flutter.dev'),
            startOffset: 0,
            endOffset: 6,
          ),
        );

        // Add an overlapping link at the beginning.
        spans.addAttribution(
          newAttribution: _LinkAttribution(url: 'https://pub.dev'),
          start: 0,
          end: 4,
        );

        expect(
          spans,
          AttributedSpans(
            attributions: [
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://pub.dev'),
                startOffset: 0,
                endOffset: 4,
              ),
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://flutter.dev'),
                startOffset: 5,
                endOffset: 6,
              ),
            ],
          ),
        );
      });

      test('splits incompatible attributions at the middle of the text', () {
        // Starting value:
        // |aaaaaaa----------|
        // |----------bbbbbbb|
        //
        // Ending value:
        // |aaaa-------------|
        // |-------------bbbb|
        // |----ccccccccc----|

        final spans = AttributedSpans(attributions: [
          ..._createSpanMarkersForAttribution(
            attribution: _LinkAttribution(url: 'https://flutter.dev'),
            startOffset: 0,
            endOffset: 6,
          ),
          ..._createSpanMarkersForAttribution(
            attribution: _LinkAttribution(url: 'https://pub.dev'),
            startOffset: 10,
            endOffset: 16,
          ),
        ]);

        // Add an overlapping at the middle.
        spans.addAttribution(
          newAttribution: _LinkAttribution(url: 'https://google.com'),
          start: 4,
          end: 12,
        );

        expect(
          spans,
          AttributedSpans(
            attributions: [
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://flutter.dev'),
                startOffset: 0,
                endOffset: 3,
              ),
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://google.com'),
                startOffset: 4,
                endOffset: 12,
              ),
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://pub.dev'),
                startOffset: 13,
                endOffset: 16,
              ),
            ],
          ),
        );
      });

      test('overwrites incompatible attributions at the end of the span', () {
        // Starting value:
        // |aaaaaaa------|
        //
        // Ending value:
        // |aaaa---------|
        // |----bbbbbbbbb|

        final spans = AttributedSpans(
          attributions: _createSpanMarkersForAttribution(
            attribution: _LinkAttribution(url: 'https://flutter.dev'),
            startOffset: 0,
            endOffset: 6,
          ),
        );

        // Add an overlapping link at the end.
        spans.addAttribution(
          newAttribution: _LinkAttribution(url: 'https://pub.dev'),
          start: 4,
          end: 12,
        );

        expect(
          spans,
          AttributedSpans(
            attributions: [
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://flutter.dev'),
                startOffset: 0,
                endOffset: 3,
              ),
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://pub.dev'),
                startOffset: 4,
                endOffset: 12,
              ),
            ],
          ),
        );
      });

      test('overwrites multiple incompatible attributions at the midle of the text', () {
        // Starting value:
        // |aaaaaa--------------------|
        // |----------bbbbbb----------|
        // |--------------------cccccc|
        //
        // Ending value:
        // |aaaa----------------------|
        // |-----------------------ccc|
        // |----ddddddddddddddddddd---|

        final spans = AttributedSpans(
          attributions: [
            ..._createSpanMarkersForAttribution(
              attribution: _LinkAttribution(url: 'https://flutter.dev'),
              startOffset: 0,
              endOffset: 5,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: _LinkAttribution(url: 'https://pub.dev'),
              startOffset: 10,
              endOffset: 15,
            ),
            ..._createSpanMarkersForAttribution(
              attribution: _LinkAttribution(url: 'https://google.com'),
              startOffset: 20,
              endOffset: 25,
            ),
          ],
        );

        // Add a link overlapping with all existing spans.
        spans.addAttribution(
          newAttribution: _LinkAttribution(url: 'https://youtube.com'),
          start: 4,
          end: 22,
        );

        expect(
          spans,
          AttributedSpans(
            attributions: [
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://flutter.dev'),
                startOffset: 0,
                endOffset: 3,
              ),
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://youtube.com'),
                startOffset: 4,
                endOffset: 22,
              ),
              ..._createSpanMarkersForAttribution(
                attribution: _LinkAttribution(url: 'https://google.com'),
                startOffset: 23,
                endOffset: 25,
              )
            ],
          ),
        );
      });

      test('compatible attributions are merged', () {
        final spans = AttributedSpans();

        // Add ExpectedSpans.bold at beginning
        spans.addAttribution(
          newAttribution: ExpectedSpans.bold,
          start: 0,
          end: 6,
        );

        // Add ExpectedSpans.bold at end but overlapping earlier ExpectedSpans.bold
        spans.addAttribution(
          newAttribution: ExpectedSpans.bold,
          start: 4,
          end: 12,
        );

        expect(spans.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, start: 0, end: 12), true);
      });
    });

    group('collapse spans', () {
      test('empty spans', () {
        // Make sure no exceptions are thrown when collapsing
        // spans on an empty AttributedSpans.
        AttributedSpans().collapseSpans(contentLength: 0);
      });

      test('non-empty span with no attributions', () {
        final collapsedSpans = AttributedSpans().collapseSpans(contentLength: 10);
        expect(collapsedSpans, hasLength(1));
        expect(collapsedSpans.first.start, 0);
        expect(collapsedSpans.first.end, 9);
        expect(collapsedSpans.first.attributions, isEmpty);
      });

      test('single continuous attribution', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 16, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 1);
        expect(collapsedSpans.first.start, 0);
        expect(collapsedSpans.first.end, 16);
        expect(collapsedSpans.first.attributions.length, 1);
        expect(collapsedSpans.first.attributions.first, ExpectedSpans.bold);
      });

      test('single fractured attribution', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 3, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 7, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 10, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 4);
        expect(collapsedSpans[0].start, 0);
        expect(collapsedSpans[0].end, 3);
        expect(collapsedSpans[0].attributions.length, 1);
        expect(collapsedSpans[0].attributions.first, ExpectedSpans.bold);
        expect(collapsedSpans[1].start, 4);
        expect(collapsedSpans[1].end, 6);
        expect(collapsedSpans[1].attributions.length, 0);
        expect(collapsedSpans[2].start, 7);
        expect(collapsedSpans[2].end, 10);
        expect(collapsedSpans[2].attributions.length, 1);
        expect(collapsedSpans[2].attributions.first, ExpectedSpans.bold);
        expect(collapsedSpans[3].start, 11);
        expect(collapsedSpans[3].end, 16);
        expect(collapsedSpans[3].attributions.length, 0);
      });

      test('adjacent non-overlapping attributions', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: ExpectedSpans.italics, offset: 5, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.italics, offset: 9, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 10);

        expect(collapsedSpans, hasLength(2));
        expect(collapsedSpans.first.start, 0);
        expect(collapsedSpans.first.end, 4);
        expect(collapsedSpans.last.start, 5);
        expect(collapsedSpans.last.end, 9);
      });

      test('multiple non-overlapping attributions', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 3, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 4);
        expect(collapsedSpans[0].start, 0);
        expect(collapsedSpans[0].end, 3);
        expect(collapsedSpans[0].attributions.length, 1);
        expect(collapsedSpans[0].attributions.first, ExpectedSpans.bold);
        expect(collapsedSpans[1].start, 4);
        expect(collapsedSpans[1].end, 6);
        expect(collapsedSpans[1].attributions.length, 0);
        expect(collapsedSpans[2].start, 7);
        expect(collapsedSpans[2].end, 10);
        expect(collapsedSpans[2].attributions.length, 1);
        expect(collapsedSpans[2].attributions.first, ExpectedSpans.italics);
        expect(collapsedSpans[3].start, 11);
        expect(collapsedSpans[3].end, 16);
        expect(collapsedSpans[3].attributions.length, 0);
      });

      test('multiple overlapping attributions', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: ExpectedSpans.italics, offset: 6, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.italics, offset: 16, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 3);
        expect(collapsedSpans[0].start, 0);
        expect(collapsedSpans[0].end, 5);
        expect(collapsedSpans[0].attributions.length, 1);
        expect(collapsedSpans[0].attributions.first, ExpectedSpans.bold);
        expect(collapsedSpans[1].start, 6);
        expect(collapsedSpans[1].end, 8);
        expect(collapsedSpans[1].attributions.length, 2);
        expect(collapsedSpans[1].attributions, equals({ExpectedSpans.bold, ExpectedSpans.italics}));
        expect(collapsedSpans[2].start, 9);
        expect(collapsedSpans[2].end, 16);
        expect(collapsedSpans[2].attributions.length, 1);
        expect(collapsedSpans[2].attributions.first, ExpectedSpans.italics);
      });
    });

    group('equality', () {
      const boldStart = SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start);
      final boldEnd = boldStart.copyWith(markerType: SpanMarkerType.end, offset: 1);

      const italicStart = SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start);
      final italicEnd = italicStart.copyWith(markerType: SpanMarkerType.end, offset: 1);

      test('it is equal to another AttributedSpans with equivalent markers that are stored in the same order', () {
        final span1 = AttributedSpans(attributions: [boldStart, italicStart, boldEnd, italicEnd]);
        final span2 = AttributedSpans(attributions: [boldStart, italicStart, boldEnd, italicEnd]);

        expect(span1 == span2, isTrue);
      });

      test('it is equal to another AttributedSpans with equivalent markers that are stored in a different order', () {
        final boldBeforeitalicspan = AttributedSpans(attributions: [boldStart, italicStart, boldEnd, italicEnd]);
        final italicsBeforeBoldSpan = AttributedSpans(attributions: [italicStart, boldStart, italicEnd, boldEnd]);

        expect(boldBeforeitalicspan == italicsBeforeBoldSpan, isTrue);
      });

      test('it is equal to another AttributedSpans with empty markers', () {
        final span1 = AttributedSpans(attributions: []);
        final span2 = AttributedSpans(attributions: []);

        expect(span1 == span2, isTrue);
      });

      test('it is NOT equal to another AttributedSpans with different markers', () {
        final span1 = AttributedSpans(attributions: [boldStart, boldEnd]);
        final span2 = AttributedSpans(attributions: [italicStart, italicEnd]);

        expect(span1 == span2, isFalse);
      });
    });
  });
}

class _LinkAttribution implements Attribution {
  _LinkAttribution({
    required this.url,
  });

  @override
  String get id => 'link';

  final String url;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _LinkAttribution && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Creates start and end markers for the [attribution], starting at [startOffset]
/// and ending at [endOffset].
List<SpanMarker> _createSpanMarkersForAttribution({
  required Attribution attribution,
  required int startOffset,
  required int endOffset,
}) {
  return [
    SpanMarker(
      attribution: attribution,
      offset: startOffset,
      markerType: SpanMarkerType.start,
    ),
    SpanMarker(
      attribution: attribution,
      offset: endOffset,
      markerType: SpanMarkerType.end,
    ),
  ];
}
