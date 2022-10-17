import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

import 'custom_parsers/callout_block.dart';
import 'custom_parsers/upsell_block.dart';

void main() {
  group("Markdown serialization", () {
    test("handles custom placeholder block node", () {
      final markdown = serializeDocumentToMarkdown(
        MutableDocument(
          nodes: [
            ParagraphNode(id: DocumentEditor.createNodeId(), text: AttributedText(text: "Paragraph 1")),
            UpsellNode(DocumentEditor.createNodeId()),
            ParagraphNode(id: DocumentEditor.createNodeId(), text: AttributedText(text: "Paragraph 2")),
          ],
        ),
        customNodeSerializers: [UpsellSerializer()],
      );

      expect(
        markdown,
        '''Paragraph 1

@@@ upsell

Paragraph 2''',
      );
    });

    test("handles custom text node", () {
      final markdown = serializeDocumentToMarkdown(
        MutableDocument(
          nodes: [
            ParagraphNode(id: DocumentEditor.createNodeId(), text: AttributedText(text: "Paragraph 1")),
            ParagraphNode(
              id: DocumentEditor.createNodeId(),
              text: AttributedText(
                text: "This is a callout!",
                spans: AttributedSpans(
                  attributions: [
                    SpanMarker(attribution: boldAttribution, offset: 10, markerType: SpanMarkerType.start),
                    SpanMarker(attribution: boldAttribution, offset: 17, markerType: SpanMarkerType.end),
                  ],
                ),
              ),
              metadata: {"blockType": const NamedAttribution("callout")},
            ),
            ParagraphNode(id: DocumentEditor.createNodeId(), text: AttributedText(text: "Paragraph 2")),
          ],
        ),
        customNodeSerializers: [CalloutSerializer()],
      );

      expect(
        markdown,
        '''Paragraph 1

@@@ callout
This is a **callout!**
@@@

Paragraph 2''',
      );
    });
  });
}
