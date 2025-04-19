import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'supereditor_test_tools.dart';

void main() {
  group("SuperEditor > ", () {
    testWidgetsOnAllPlatforms("inserts placeholder at the end of the attributed text", (tester) async {
      final context = await tester //
          .createDocument()
          .withCustomContent(MutableDocument(nodes: [
            ParagraphNode(
                id: "1",
                text: AttributedText(
                  "Hello",
                  AttributedSpans(
                    attributions: const [
                      SpanMarker(
                        attribution: NamedAttribution("bold"),
                        offset: 0,
                        markerType: SpanMarkerType.start,
                      ),
                      SpanMarker(
                        attribution: NamedAttribution("bold"),
                        offset: 4,
                        markerType: SpanMarkerType.end,
                      ),
                    ],
                  ),
                ))
          ]))
          .withInputSource(TextInputSource.ime)
          .useStylesheet(defaultStylesheet.copyWith(
            inlineWidgetBuilders: [_inlineWidgetBuilder],
          ))
          .pump();

      Document doc = SuperEditorInspector.findDocument()!;
      final Editor editor = context.editor;

      // Place the caret at "Hello|".
      await tester.placeCaretInParagraph(doc.first.id, 5);

      await tester.pump();

      // Insert the placeholder at the current caret offset.
      editor.execute([const InsertInlinePlaceholderAtCaretRequest(_ExamplePlaceholder())]);

      await tester.pump();

      // Ensure the placeholder is inserted at expected offset while maintaining the text attributions.
      expect(
        (doc.getNodeById("1") as ParagraphNode).text,
        AttributedText(
            "Hello",
            AttributedSpans(
              attributions: const [
                SpanMarker(
                  attribution: NamedAttribution("bold"),
                  offset: 0,
                  markerType: SpanMarkerType.start,
                ),
                SpanMarker(
                  attribution: NamedAttribution("bold"),
                  offset: 4,
                  markerType: SpanMarkerType.end,
                ),
              ],
            ),
            {
              5: const _ExamplePlaceholder(),
            }),
      );
    });
  });
}

Widget? _inlineWidgetBuilder(BuildContext context, TextStyle textStyle, Object placeholder) {
  if (placeholder is! _ExamplePlaceholder) {
    return null;
  }

  return LineHeight(
      style: textStyle,
      child: Container(
          color: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'placeholder',
            style: textStyle,
          )));
}

class _ExamplePlaceholder {
  const _ExamplePlaceholder();
}
