import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/document_to_markdown_serializer.dart';

void main() {
  group("AttributedText markdown serializes", () {
    test("un-styled text", () {
      expect(
        AttributedText(text: "This is unstyled text.").toMarkdown(),
        "This is unstyled text.",
      );
    });

    test("single character styles", () {
      expect(
        AttributedText(
          text: "This is single character styles.",
          spans: AttributedSpans(
            attributions: [
              AttributionSpan(attribution: boldAttribution, start: 8, end: 9),
              AttributionSpan(attribution: italicsAttribution, start: 23, end: 24),
            ],
          ),
        ).toMarkdown(),
        "This is **s**ingle characte*r* styles.",
      );
    });

    test("bold text", () {
      expect(
        AttributedText(
          text: "This is bold text.",
          spans: AttributedSpans(
            attributions: [
              AttributionSpan(attribution: boldAttribution, start: 8, end: 12),
            ],
          ),
        ).toMarkdown(),
        "This is **bold** text.",
      );
    });

    test("italics text", () {
      expect(
        AttributedText(
          text: "This is italics text.",
          spans: AttributedSpans(
            attributions: [
              AttributionSpan(attribution: italicsAttribution, start: 8, end: 15),
            ],
          ),
        ).toMarkdown(),
        "This is *italics* text.",
      );
    });

    test("multiple styles across the same span", () {
      expect(
        AttributedText(
          text: "This is multiple styled text.",
          spans: AttributedSpans(
            attributions: [
              AttributionSpan(attribution: boldAttribution, start: 8, end: 23),
              AttributionSpan(attribution: italicsAttribution, start: 8, end: 23),
            ],
          ),
        ).toMarkdown(),
        "This is ***multiple styled*** text.",
      );
    });

    test("partially overlapping styles", () {
      expect(
        AttributedText(
          text: "This is overlapping styles.",
          spans: AttributedSpans(
            attributions: const [
              AttributionSpan(attribution: boldAttribution, start: 8, end: 14),
              AttributionSpan(attribution: italicsAttribution, start: 11, end: 19),
            ],
          ),
        ).toMarkdown(),
        "This is **ove*rla**pping* styles.",
      );
    });
  });
}
