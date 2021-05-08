import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:flutter_test/flutter_test.dart';

// Attributions used throughout this test suite.
final bold = NamedAttribution('bold');
final italics = NamedAttribution('italics');
final strikethrough = NamedAttribution('strikethrough');

void main() {
  group('Spans', () {
    group('single attribution', () {
      test('applies attribution to full span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 0, end: 16), true);
      });

      test('applies attribution to beginning of span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: bold, start: 0, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 0, end: 7), true);
      });

      test('applies attribution to inner span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: bold, start: 2, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 2, end: 7), true);
      });

      test('applies attribution to end of span', () {
        final spans = AttributedSpans()..addAttribution(newAttribution: bold, start: 7, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 7, end: 16), true);
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
            SpanMarker(attribution: bold, offset: 0, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 16, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 0, end: 16), false);
      });

      test('removes attribution from inner text span', () {
        final spans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 2, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: bold, start: 2, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 2, end: 7), false);
      });

      test('removes attribution from partial beginning span', () {
        final spans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 2, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: bold, start: 2, end: 4);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 5, end: 7), true);
      });

      test('removes attribution from partial inner span', () {
        final spans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 2, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: bold, start: 4, end: 5);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 2, end: 3), true);
        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 6, end: 7), true);
      });

      test('removes attribution from partial ending span', () {
        final spans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 2, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 7, markerType: SpanMarkerType.end)
          ],
        )..removeAttribution(attributionToRemove: bold, start: 5, end: 7);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 2, end: 4), true);
      });

      test('applies attribution when mixed span is toggled', () {
        final spans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 8, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 16, markerType: SpanMarkerType.end)
          ],
        )..toggleAttribution(attribution: bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 0, end: 16), true);
      });

      test('removes attribution when contiguous span is toggled', () {
        final spans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 0, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 16, markerType: SpanMarkerType.end)
          ],
        )..toggleAttribution(attribution: bold, start: 0, end: 16);

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 0, end: 16), false);
      });
    });

    group('multiple attributions', () {
      test('full length overlap', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: bold, start: 0, end: 9)
          ..addAttribution(newAttribution: italics, start: 0, end: 9);

        _ExpectedSpans([
          'bbbbbbbbbb',
          'iiiiiiiiii',
        ]).expectSpans(spans);
      });

      test('half and half', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: bold, start: 5, end: 9)
          ..addAttribution(newAttribution: italics, start: 0, end: 4);

        _ExpectedSpans([
          '_____bbbbb',
          'iiiii_____',
        ]).expectSpans(spans);
      });

      test('two partial overlap', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: bold, start: 4, end: 8)
          ..addAttribution(newAttribution: italics, start: 1, end: 5);

        _ExpectedSpans([
          '____bbbbb_',
          '_iiiii____',
        ]).expectSpans(spans);
      });

      test('three partial overlap', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: bold, start: 4, end: 8)
          ..addAttribution(newAttribution: italics, start: 1, end: 5)
          ..addAttribution(newAttribution: strikethrough, start: 5, end: 9);

        _ExpectedSpans([
          '____bbbbb_',
          '_iiiii____',
          '_____sssss',
        ]).expectSpans(spans);
      });

      test('many small segments', () {
        final spans = AttributedSpans()
          ..addAttribution(newAttribution: bold, start: 0, end: 1)
          ..addAttribution(newAttribution: italics, start: 2, end: 3)
          ..addAttribution(newAttribution: strikethrough, start: 4, end: 5)
          ..addAttribution(newAttribution: bold, start: 6, end: 7)
          ..addAttribution(newAttribution: italics, start: 8, end: 9);

        _ExpectedSpans([
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
          );
        }, throwsA(isA<IncompatibleOverlappingAttributionsException>()));
      });

      test('compatible attributions are merged', () {
        final spans = AttributedSpans();

        // Add bold at beginning
        spans.addAttribution(
          newAttribution: bold,
          start: 0,
          end: 6,
        );

        // Add bold at end but overlapping earlier bold
        spans.addAttribution(
          newAttribution: bold,
          start: 4,
          end: 12,
        );

        expect(spans.hasAttributionsWithin(attributions: {bold}, start: 0, end: 12), true);
      });
    });

    group('collapse spans', () {
      test('empty spans', () {
        // Make sure no exceptions are thrown when collapsing
        // spans on an empty AttributedSpans.
        AttributedSpans().collapseSpans(contentLength: 0);
      });

      test('single continuous attribution', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 0, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 16, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 1);
        expect(collapsedSpans.first.start, 0);
        expect(collapsedSpans.first.end, 16);
        expect(collapsedSpans.first.attributions.length, 1);
        expect(collapsedSpans.first.attributions.first, bold);
      });

      test('single fractured attribution', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 0, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 3, markerType: SpanMarkerType.end),
            SpanMarker(attribution: bold, offset: 7, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 10, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 4);
        expect(collapsedSpans[0].start, 0);
        expect(collapsedSpans[0].end, 3);
        expect(collapsedSpans[0].attributions.length, 1);
        expect(collapsedSpans[0].attributions.first, bold);
        expect(collapsedSpans[1].start, 4);
        expect(collapsedSpans[1].end, 6);
        expect(collapsedSpans[1].attributions.length, 0);
        expect(collapsedSpans[2].start, 7);
        expect(collapsedSpans[2].end, 10);
        expect(collapsedSpans[2].attributions.length, 1);
        expect(collapsedSpans[2].attributions.first, bold);
        expect(collapsedSpans[3].start, 11);
        expect(collapsedSpans[3].end, 16);
        expect(collapsedSpans[3].attributions.length, 0);
      });

      test('multiple non-overlapping attributions', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 0, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 3, markerType: SpanMarkerType.end),
            SpanMarker(attribution: italics, offset: 7, markerType: SpanMarkerType.start),
            SpanMarker(attribution: italics, offset: 10, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 4);
        expect(collapsedSpans[0].start, 0);
        expect(collapsedSpans[0].end, 3);
        expect(collapsedSpans[0].attributions.length, 1);
        expect(collapsedSpans[0].attributions.first, bold);
        expect(collapsedSpans[1].start, 4);
        expect(collapsedSpans[1].end, 6);
        expect(collapsedSpans[1].attributions.length, 0);
        expect(collapsedSpans[2].start, 7);
        expect(collapsedSpans[2].end, 10);
        expect(collapsedSpans[2].attributions.length, 1);
        expect(collapsedSpans[2].attributions.first, italics);
        expect(collapsedSpans[3].start, 11);
        expect(collapsedSpans[3].end, 16);
        expect(collapsedSpans[3].attributions.length, 0);
      });

      test('multiple overlapping attributions', () {
        final collapsedSpans = AttributedSpans(
          attributions: [
            SpanMarker(attribution: bold, offset: 0, markerType: SpanMarkerType.start),
            SpanMarker(attribution: bold, offset: 8, markerType: SpanMarkerType.end),
            SpanMarker(attribution: italics, offset: 6, markerType: SpanMarkerType.start),
            SpanMarker(attribution: italics, offset: 16, markerType: SpanMarkerType.end),
          ],
        ).collapseSpans(contentLength: 17);

        expect(collapsedSpans.length, 3);
        expect(collapsedSpans[0].start, 0);
        expect(collapsedSpans[0].end, 5);
        expect(collapsedSpans[0].attributions.length, 1);
        expect(collapsedSpans[0].attributions.first, bold);
        expect(collapsedSpans[1].start, 6);
        expect(collapsedSpans[1].end, 8);
        expect(collapsedSpans[1].attributions.length, 2);
        expect(collapsedSpans[1].attributions, equals({bold, italics}));
        expect(collapsedSpans[2].start, 9);
        expect(collapsedSpans[2].end, 16);
        expect(collapsedSpans[2].attributions.length, 1);
        expect(collapsedSpans[2].attributions.first, italics);
      });
    });
  });
}

class _ExpectedSpans {
  _ExpectedSpans(
    List<String> spanTemplates,
  ) : _combinedSpans = [] {
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

  List<String> _combinedSpans;

  void expectSpans(AttributedSpans spans) {
    for (int characterIndex = 0; characterIndex < _combinedSpans.length; ++characterIndex) {
      for (int attributionIndex = 0; attributionIndex < _combinedSpans[characterIndex].length; ++attributionIndex) {
        // The attribution name is just a letter, like 'b', 'i', or 's'.
        final attributionName = _combinedSpans[characterIndex][attributionIndex];
        if (attributionName == '_') {
          continue;
        }

        Attribution namedAttribution;
        switch (attributionName) {
          case 'b':
            namedAttribution = bold;
            break;
          case 'i':
            namedAttribution = italics;
            break;
          case 's':
            namedAttribution = strikethrough;
            break;
          default:
            throw Exception('Unknown span template character: $attributionName');
        }

        expect(spans.hasAttributionAt(characterIndex, attribution: namedAttribution), true);
      }
    }
  }
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
