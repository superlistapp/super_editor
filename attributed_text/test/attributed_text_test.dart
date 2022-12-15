import 'package:attributed_text/attributed_text.dart';
import 'package:test/test.dart';

void main() {
  group('Attributed Text', () {
    test('Bug 145 - insert character at beginning of styled text', () {
      final initialText = AttributedText(
        text: 'abcdefghij',
        spans: AttributedSpans(
          attributions: [
            AttributionSpan(attribution: ExpectedSpans.bold, start: 0, end: 9),
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
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 0, end: 5));
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 4, end: 9));

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

      test('combines overlapping spans when adding from right to left', () {
        final text = AttributedText(text: '01234567');
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 4, end: 9));
        text.addAttribution(ExpectedSpans.bold, SpanRange(start: 0, end: 5));

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
        text.addAttribution(ExpectedSpans.bold, const SpanRange(start: 0, end: 2));
        text.addAttribution(ExpectedSpans.bold, const SpanRange(start: 2, end: 4));

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
                AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 5),
                AttributionSpan(attribution: ExpectedSpans.italics, start: 4, end: 7),
              ],
            ),
          ),
          equals(
            AttributedText(
              text: 'abcdefghij',
              spans: AttributedSpans(
                attributions: [
                  AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 5),
                  AttributionSpan(attribution: ExpectedSpans.italics, start: 4, end: 7),
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
                    AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 5),
                    AttributionSpan(attribution: ExpectedSpans.italics, start: 4, end: 7),
                  ],
                ),
              ) ==
              AttributedText(
                text: 'abcdefghij',
                spans: AttributedSpans(
                  attributions: [
                    AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 5),
                    AttributionSpan(attribution: ExpectedSpans.italics, start: 4, end: 7),
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
                    AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 5),
                    AttributionSpan(attribution: ExpectedSpans.italics, start: 4, end: 7),
                  ],
                ),
              ) ==
              AttributedText(
                text: 'abcdefghij',
                spans: AttributedSpans(
                  attributions: [
                    AttributionSpan(attribution: ExpectedSpans.bold, start: 2, end: 5),
                  ],
                ),
              ),
          isFalse,
        );
      });
    });

    group('attribution queries', () {
      test('finds all bold text around a character', () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              AttributionSpan(
                attribution: ExpectedSpans.bold,
                start: 4,
                end: 9,
              ),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold}, 5);
        expect(range, SpanRange(start: 4, end: 9));
      });

      test('finds all bold and italics text around a character', () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              AttributionSpan(
                attribution: ExpectedSpans.bold,
                start: 4,
                end: 9,
              ),
              AttributionSpan(
                attribution: ExpectedSpans.italics,
                start: 0,
                end: 7,
              ),
              AttributionSpan(
                attribution: ExpectedSpans.strikethrough,
                start: 0,
                end: 10,
              ),
            ],
          ),
        );

        final range = attributedText.getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics}, 5);
        expect(range, SpanRange(start: 4, end: 7));
      });

      test(
          'finds all bold, italic and strikethrough text within a word that also includes a span with only bold and italics',
          () {
        final attributedText = AttributedText(
          text: 'Hello world',
          spans: AttributedSpans(
            attributions: [
              AttributionSpan(
                attribution: ExpectedSpans.bold,
                start: 0,
                end: 4,
              ),
              AttributionSpan(
                attribution: ExpectedSpans.italics,
                start: 0,
                end: 4,
              ),
              AttributionSpan(
                attribution: ExpectedSpans.strikethrough,
                start: 1,
                end: 3,
              ),
            ],
          ),
        );

        final range = attributedText
            .getAttributedRange({ExpectedSpans.bold, ExpectedSpans.italics, ExpectedSpans.strikethrough}, 2);
        expect(range, SpanRange(start: 1, end: 3));
      });
    });
  });
}
