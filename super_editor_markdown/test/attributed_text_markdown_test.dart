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
              SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
              SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.end),
              SpanMarker(attribution: italicsAttribution, offset: 23, markerType: SpanMarkerType.start),
              SpanMarker(attribution: italicsAttribution, offset: 23, markerType: SpanMarkerType.end),
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
              SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
              SpanMarker(attribution: boldAttribution, offset: 11, markerType: SpanMarkerType.end),
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
              SpanMarker(attribution: italicsAttribution, offset: 8, markerType: SpanMarkerType.start),
              SpanMarker(attribution: italicsAttribution, offset: 14, markerType: SpanMarkerType.end),
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
              SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
              SpanMarker(attribution: boldAttribution, offset: 22, markerType: SpanMarkerType.end),
              SpanMarker(attribution: italicsAttribution, offset: 8, markerType: SpanMarkerType.start),
              SpanMarker(attribution: italicsAttribution, offset: 22, markerType: SpanMarkerType.end),
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
            attributions: [
              SpanMarker(attribution: boldAttribution, offset: 8, markerType: SpanMarkerType.start),
              SpanMarker(attribution: boldAttribution, offset: 13, markerType: SpanMarkerType.end),
              SpanMarker(attribution: italicsAttribution, offset: 11, markerType: SpanMarkerType.start),
              SpanMarker(attribution: italicsAttribution, offset: 18, markerType: SpanMarkerType.end),
            ],
          ),
        ).toMarkdown(),
        "This is **ove*rla**pping* styles.",
      );
    });
  });
}
