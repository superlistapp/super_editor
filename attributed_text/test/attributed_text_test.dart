import 'package:attributed_text/attributed_text.dart';
import 'package:test/test.dart';

void main() {
  group('Attributed Text', () {
    test('Bug 145 - insert character at beginning of styled text', () {
      final initialText = AttributedText(
        text: 'abcdefghij',
        spans: AttributedSpans(
          attributions: [
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
          ],
        ),
      );

      final newText = initialText.insertString(
        textToInsert: 'a',
        startOffset: 0,
        applyAttributions: {ExpectedSpans.bold},
      );

      expect(newText.text, 'aabcdefghij');
      expect(
        newText.hasAttributionsWithin(attributions: {ExpectedSpans.bold}, range: const SpanRange(start: 0, end: 10)),
        true,
      );
    });

    group('span manipulation', () {
      test('combines overlapping spans when adding from left to right', () {
        // Note: span overlaps at the boundary had a bug that was filed in #582.
        final text = AttributedText(text: '01234567');
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 0, end: 4));
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 4, end: 8));

        // Ensure that the spans were merged into a single span.
        expect(text.spans.markers.length, 2);
        expect(
          text.spans.markers.first,
          SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
        );
        expect(
          text.spans.markers.last,
          SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
        );
      });

      test('combines overlapping spans when adding from left to right', () {
        final text = AttributedText(text: '01234567');
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 4, end: 8));
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 0, end: 4));

        // Ensure that the spans were merged into a single span.
        expect(text.spans.markers.length, 2);
        expect(
          text.spans.markers.first,
          SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
        );
        expect(
          text.spans.markers.last,
          SpanMarker(attribution: ExpectedSpans.bold, offset: 8, markerType: SpanMarkerType.end),
        );
      });

      test('combines back-to-back spans after addition', () {
        final text = AttributedText(text: 'ABCD');
        text.addAttribution(ExpectedSpans.bold, const SpanRange(start: 0, end: 1));
        text.addAttribution(ExpectedSpans.bold, const SpanRange(start: 2, end: 3));

        // Ensure that we only have a single span
        expect(text.spans.markers.length, 2);
        expect(
          text.spans.markers.first,
          SpanMarker(attribution: ExpectedSpans.bold, offset: 0, markerType: SpanMarkerType.start),
        );
        expect(
          text.spans.markers.last,
          SpanMarker(attribution: ExpectedSpans.bold, offset: 3, markerType: SpanMarkerType.end),
        );
      });
    });

    test('notifies listeners when style changes', () {
      bool listenerCalled = false;

      final text = AttributedText(text: 'abcdefghij');
      text.addListener(() {
        listenerCalled = true;
      });

      text.addAttribution(ExpectedSpans.bold, const SpanRange(start: 1, end: 1));

      expect(listenerCalled, isTrue);
    });

    group("equality", () {
      test("equivalent AttributedText are equal", () {
        expect(
          AttributedText(
            text: 'abcdefghij',
            spans: AttributedSpans(
              attributions: [
                const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              ],
            ),
          ),
          equals(
            AttributedText(
              text: 'abcdefghij',
              spans: AttributedSpans(
                attributions: [
                  const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                  const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                  const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                ],
              ),
            ),
          ),
        );
      });

      test("different text are not equal", () {
        expect(
          AttributedText(
                text: 'jihgfedcba',
                spans: AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                  ],
                ),
              ) ==
              AttributedText(
                text: 'abcdefghij',
                spans: AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
          isFalse,
        );
      });

      test("different spans are not equal", () {
        expect(
          AttributedText(
                text: 'abcdefghij',
                spans: AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 4, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                    const SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
                  ],
                ),
              ) ==
              AttributedText(
                text: 'abcdefghij',
                spans: AttributedSpans(
                  attributions: [
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 2, markerType: SpanMarkerType.start),
                    const SpanMarker(attribution: ExpectedSpans.bold, offset: 5, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
          isFalse,
        );
      });
    });

    group('getAttributedRange', () {
      test('returns the range of a single attribution for an offset in the middle of a span', () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold}, 5);
        expect(range, SpanRange(start: 4, end: 9));
      });

      test('returns the range of a single attribution for an offset at the beginning of a span', () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold}, 4);
        expect(range, SpanRange(start: 4, end: 9));
      });

      test('returns the range of a single attribution for an offset at the end of a span', () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold}, 9);
        expect(range, SpanRange(start: 4, end: 9));
      });

      test('returns the range for multiple attributions', () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              SpanMarker(attribution: ExpectedSpans.bold, offset: 4, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.bold, offset: 9, markerType: SpanMarkerType.end),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.italics, offset: 7, markerType: SpanMarkerType.end),
              SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 0, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.strikethrough, offset: 10, markerType: SpanMarkerType.end),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 5);
        expect(range, SpanRange(start: 4, end: 7));
      });

      test('throws when given an empty attribution set', () {
        final attributedText = AttributedText(text: 'Hello world');

        expect(() => attributedText.getAttributedRange({}, 0), throwsException);
      });

      test('throws when any attribution is not present at the given offset', () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              SpanMarker(attribution: ExpectedSpans.bold, offset: 6, markerType: SpanMarkerType.start),
              SpanMarker(attribution: ExpectedSpans.bold, offset: 10, markerType: SpanMarkerType.end),
              
            ],
          ),
        );

        expect(() => attributedText.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 7), throwsException);
      });
    });
  });
}
