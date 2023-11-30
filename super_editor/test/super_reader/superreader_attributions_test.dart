import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'reader_test_tools.dart';

void main() {
  group("SuperReader", () {
    group("applies color attributions", () {
      testWidgetsOnAllPlatforms("to full text", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText(
                      'abcdefghij',
                      AttributedSpans(
                        attributions: [
                          const SpanMarker(
                            attribution: ColorAttribution(Colors.orange),
                            offset: 0,
                            markerType: SpanMarkerType.start,
                          ),
                          const SpanMarker(
                            attribution: ColorAttribution(Colors.orange),
                            offset: 9,
                            markerType: SpanMarkerType.end,
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            )
            .pump();

        final superText = tester.widget<SuperText>(find.byType(SuperText));

        // Ensure the text is colored orange.
        expect(
          superText.richText.style!.color,
          Colors.orange,
        );
      });

      testWidgetsOnAllPlatforms("to partial text", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ParagraphNode(
                    id: '1',
                    text: AttributedText(
                      'abcdefghij',
                      AttributedSpans(
                        attributions: [
                          const SpanMarker(
                            attribution: ColorAttribution(Colors.orange),
                            offset: 5,
                            markerType: SpanMarkerType.start,
                          ),
                          const SpanMarker(
                            attribution: ColorAttribution(Colors.orange),
                            offset: 9,
                            markerType: SpanMarkerType.end,
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            )
            .pump();

        final superText = tester.widget<SuperText>(find.byType(SuperText));

        // Ensure the first span is colored black.
        expect(
          superText.richText.getSpanForPosition(const TextPosition(offset: 0))!.style!.color,
          Colors.black,
        );

        // Ensure the second span is colored orange.
        expect(
          superText.richText.getSpanForPosition(const TextPosition(offset: 5))!.style!.color,
          Colors.orange,
        );
      });
    });
  });
}
