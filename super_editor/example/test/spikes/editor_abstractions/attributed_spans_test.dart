import 'package:example/spikes/editor_abstractions/core/attributed_spans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Spans', () {
    group('single attribution', () {
      test('applies attribution to full span', () {
        final spans = AttributedSpans(length: 17);

        spans.addAttribution(newAttribution: 'bold', start: 0, end: 16);

        expect(spans.attributions.length, 2);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start));
        expect(
            spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 16, markerType: SpanMarkerType.end));
      });

      test('applies attribution to beginning of span', () {
        final spans = AttributedSpans(length: 17);

        spans.addAttribution(newAttribution: 'bold', start: 0, end: 7);

        expect(spans.attributions.length, 2);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start));
        expect(spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end));
      });

      test('applies attribution to inner span', () {
        final spans = AttributedSpans(length: 17);

        spans.addAttribution(newAttribution: 'bold', start: 2, end: 7);

        expect(spans.attributions.length, 2);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start));
        expect(spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end));
      });

      test('applies attribution to end of span', () {
        final spans = AttributedSpans(length: 17);

        spans.addAttribution(newAttribution: 'bold', start: 7, end: 16);

        expect(spans.attributions.length, 2);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.start));
        expect(
            spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 16, markerType: SpanMarkerType.end));
      });

      test('applies exotic span', () {
        final spans = AttributedSpans(length: 17);

        final linkAttribution = {
          'url': 'https://youtube.com/c/superdeclarative',
        };

        spans.addAttribution(newAttribution: linkAttribution, start: 2, end: 7);

        expect(spans.attributions.length, 2);
        expect(spans.attributions[0],
            SpanMarker(attribution: linkAttribution, offset: 2, markerType: SpanMarkerType.start));
        expect(
            spans.attributions[1], SpanMarker(attribution: linkAttribution, offset: 7, markerType: SpanMarkerType.end));
        expect(spans.getAllAttributionsAt(4).first, equals(linkAttribution));
      });

      test('removes attribution from full span', () {
        final spans = AttributedSpans(
          length: 17,
          attributions: [
            const SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: 'bold', offset: 16, markerType: SpanMarkerType.end)
          ],
        );

        spans.removeAttribution(attributionToRemove: 'bold', start: 0, end: 16);

        expect(spans.attributions.length, 0);
      });

      test('removes attribution from inner text span', () {
        final spans = AttributedSpans(
          length: 17,
          attributions: [
            const SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end)
          ],
        );

        spans.removeAttribution(attributionToRemove: 'bold', start: 2, end: 7);

        expect(spans.attributions.length, 0);
      });

      test('removes attribution from partial beginning span', () {
        final spans = AttributedSpans(
          length: 17,
          attributions: [
            const SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end)
          ],
        );

        spans.removeAttribution(attributionToRemove: 'bold', start: 2, end: 4);

        expect(spans.attributions.length, 2);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 5, markerType: SpanMarkerType.start));
        expect(spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end));
      });

      test('removes attribution from partial inner span', () {
        final spans = AttributedSpans(
          length: 17,
          attributions: [
            const SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end)
          ],
        );

        spans.removeAttribution(attributionToRemove: 'bold', start: 4, end: 5);

        expect(spans.attributions.length, 4);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start));
        expect(spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 3, markerType: SpanMarkerType.end));
        expect(
            spans.attributions[2], const SpanMarker(attribution: 'bold', offset: 6, markerType: SpanMarkerType.start));
        expect(spans.attributions[3], const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end));
      });

      test('removes attribution from partial ending span', () {
        final spans = AttributedSpans(
          length: 17,
          attributions: [
            const SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: 'bold', offset: 7, markerType: SpanMarkerType.end)
          ],
        );

        spans.removeAttribution(attributionToRemove: 'bold', start: 5, end: 7);

        expect(spans.attributions.length, 2);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 2, markerType: SpanMarkerType.start));
        expect(spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 4, markerType: SpanMarkerType.end));
      });

      test('applies attribution when mixed span is toggled', () {
        final spans = AttributedSpans(
          length: 17,
          attributions: [
            const SpanMarker(attribution: 'bold', offset: 8, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: 'bold', offset: 16, markerType: SpanMarkerType.end)
          ],
        );

        spans.toggleAttribution(attribution: 'bold', start: 0, end: 16);

        expect(spans.attributions.length, 2);
        expect(
            spans.attributions[0], const SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start));
        expect(
            spans.attributions[1], const SpanMarker(attribution: 'bold', offset: 16, markerType: SpanMarkerType.end));
      });

      test('removes attribution when contiguous span is toggled', () {
        final spans = AttributedSpans(
          length: 17,
          attributions: [
            const SpanMarker(attribution: 'bold', offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: 'bold', offset: 16, markerType: SpanMarkerType.end)
          ],
        );

        spans.toggleAttribution(attribution: 'bold', start: 0, end: 16);

        expect(spans.attributions.length, 0);
      });
    });

    group('multiple attributions', () {
      test('full length overlap', () {
        final spans = AttributedSpans(
          length: 10,
        );
        spans.addAttribution(newAttribution: 'b', start: 0, end: 9);
        spans.addAttribution(newAttribution: 'i', start: 0, end: 9);
        final expectedAttributions1 = _ExpectedSpans([
          'bbbbbbbbbb',
          'iiiiiiiiii',
        ]);
        expectedAttributions1.expectSpans(spans);
      });

      test('half and half', () {
        final spans = AttributedSpans(
          length: 10,
        );
        spans.addAttribution(newAttribution: 'b', start: 5, end: 9);
        spans.addAttribution(newAttribution: 'i', start: 0, end: 4);
        final expectedAttributions2 = _ExpectedSpans([
          '_____bbbbb',
          'iiiii_____',
        ]);
        expectedAttributions2.expectSpans(spans);
      });

      test('two partial overlap', () {
        final spans = AttributedSpans(
          length: 10,
        );
        spans.addAttribution(newAttribution: 'b', start: 4, end: 8);
        spans.addAttribution(newAttribution: 'i', start: 1, end: 5);
        final expectedAttributions3 = _ExpectedSpans([
          '____bbbbb_',
          '_iiiii____',
        ]);
        expectedAttributions3.expectSpans(spans);
      });

      test('three partial overlap', () {
        final spans = AttributedSpans(
          length: 10,
        );
        spans.addAttribution(newAttribution: 'b', start: 4, end: 8);
        spans.addAttribution(newAttribution: 'i', start: 1, end: 5);
        spans.addAttribution(newAttribution: 's', start: 5, end: 9);
        final expectedAttributions4 = _ExpectedSpans([
          '____bbbbb_',
          '_iiiii____',
          '_____sssss',
        ]);
        expectedAttributions4.expectSpans(spans);
      });

      test('many small segments', () {
        final spans = AttributedSpans(
          length: 10,
        );
        spans.addAttribution(newAttribution: 'b', start: 0, end: 1);
        spans.addAttribution(newAttribution: 'i', start: 2, end: 3);
        spans.addAttribution(newAttribution: 's', start: 4, end: 5);
        spans.addAttribution(newAttribution: 'b', start: 6, end: 7);
        spans.addAttribution(newAttribution: 'i', start: 8, end: 9);
        final expectedAttributions5 = _ExpectedSpans([
          'bb____bb__',
          '__ii____ii',
          '____ss____',
        ]);
        expectedAttributions5.expectSpans(spans);
      });
    });

    group('collapse spans', () {
      // TODO: tests to collapse spans
    });
  });
}

class _ExpectedSpans {
  _ExpectedSpans(
    List<String> spanTemplates,
  ) {
    final templateLength = spanTemplates.first.length;
    for (final template in spanTemplates) {
      assert(template.length == templateLength);
    }

    // Collapse spanTemplates down into a single
    // list of character collections representing the
    // set of attributions at a given index.
    _combinedSpans = List.filled(templateLength, '');
    for (int i = 0; i < templateLength; ++i) {
      for (final template in spanTemplates) {
        if (_combinedSpans[i].isEmpty) {
          _combinedSpans[i] = template[i];
        } else if (_combinedSpans[i] == '_' && template[i] != '_') {
          _combinedSpans[i] = template[i];
        } else if (_combinedSpans[i] != '_' && template[i] != '_') {
          _combinedSpans[i] += template[i];
        }
      }
    }
  }

  late List<String> _combinedSpans;

  void expectSpans(AttributedSpans spans) {
    for (int characterIndex = 0; characterIndex < _combinedSpans.length; ++characterIndex) {
      for (int attributionIndex = 0; attributionIndex < _combinedSpans[characterIndex].length; ++attributionIndex) {
        print('Checking character $characterIndex');
        // The attribution name is just a letter, like 'b', 'i', or 's'.
        final attributionName = _combinedSpans[characterIndex][attributionIndex];
        print(' - looking for attribution: "$attributionName"');
        if (attributionName == '_') {
          print(' - skipping empty template character');
          continue;
        }

        expect(spans.hasAttributionAt(characterIndex, attribution: attributionName), true);
      }
    }
  }
}
