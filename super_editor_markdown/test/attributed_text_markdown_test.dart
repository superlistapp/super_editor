import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/document_to_markdown_serializer.dart';

void main() {
  group("AttributedText markdown serializes", () {
    test("un-styled text", () {
      expect(
        AttributedText("This is unstyled text.").toMarkdown(),
        "This is unstyled text.",
      );
    });

    test("single character styles", () {
      expect(
        AttributedText(
          "This is single character styles.",
          AttributedSpans(
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
          "This is bold text.",
          AttributedSpans(
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
          "This is italics text.",
          AttributedSpans(
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
          "This is multiple styled text.",
          AttributedSpans(
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
          "This is overlapping styles.",
          AttributedSpans(
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
