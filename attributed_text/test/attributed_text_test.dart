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
  });
}
