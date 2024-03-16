import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_markdown/src/markdown_style_reaction.dart';
import 'package:super_editor_markdown/src/markdown_to_document_parsing.dart';

void main() {
  group("Super Editor Markdown style reaction >", () {
    testWidgets("bold", (tester) async {
      final document = deserializeMarkdownToDocument("Hello **bold");
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              document: document,
              composer: composer,
              plugins: {
                MarkdownInlineStylePlugin(),
              },
            ),
          ),
        ),
      );

      final nodeId = document.nodes.first.id;
      await tester.placeCaretInParagraph(nodeId, 12);

      await tester.typeImeText("**");
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello bold");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: boldAttribution, offset: 9, markerType: SpanMarkerType.end),
      ]);
    });

    testWidgets("italics", (tester) async {
      final document = deserializeMarkdownToDocument("Hello *italics");
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              document: document,
              composer: composer,
              plugins: {
                MarkdownInlineStylePlugin(),
              },
            ),
          ),
        ),
      );

      final nodeId = document.nodes.first.id;
      await tester.placeCaretInParagraph(nodeId, 14);

      await tester.typeImeText("*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello italics");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
      ]);
    });

    testWidgets("strikethrough", (tester) async {
      final document = deserializeMarkdownToDocument("Hello ~strikethrough");
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              document: document,
              composer: composer,
              plugins: {
                MarkdownInlineStylePlugin(),
              },
            ),
          ),
        ),
      );

      final nodeId = document.nodes.first.id;
      await tester.placeCaretInParagraph(nodeId, 20);

      await tester.typeImeText("~");
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello strikethrough");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: strikethroughAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: strikethroughAttribution, offset: 18, markerType: SpanMarkerType.end),
      ]);
    });

    testWidgets("links", (tester) async {
      final document = deserializeMarkdownToDocument("Hello [my link](http://google.com");
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              document: document,
              composer: composer,
              plugins: {
                MarkdownInlineStylePlugin(),
              },
            ),
          ),
        ),
      );

      final nodeId = document.nodes.first.id;
      await tester.placeCaretInParagraph(nodeId, 33);

      await tester.typeImeText(")");

      final linkAttribution = LinkAttribution(url: Uri.parse("http://google.com"));
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello my link");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        SpanMarker(attribution: linkAttribution, offset: 6, markerType: SpanMarkerType.start),
        SpanMarker(attribution: linkAttribution, offset: 12, markerType: SpanMarkerType.end),
      ]);
    });

    testWidgets("multiple styles", (tester) async {
      final document = deserializeMarkdownToDocument("Hello");
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              document: document,
              composer: composer,
              plugins: {
                MarkdownInlineStylePlugin(),
              },
            ),
          ),
        ),
      );

      final nodeId = document.nodes.first.id;
      await tester.placeCaretInParagraph(nodeId, 5);

      // Italics
      await tester.typeImeText(" *italics*");

      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello italics");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
      ]);

      // Bold
      await tester.typeImeText(" and **bold**");
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello italics and bold");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: boldAttribution, offset: 18, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
      ]);

      // Strikethrough
      await tester.typeImeText(" and ~strikethrough~");
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello italics and bold and strikethrough");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: boldAttribution, offset: 18, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: strikethroughAttribution, offset: 27, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: strikethroughAttribution, offset: 39, markerType: SpanMarkerType.end),
      ]);

      // Link
      await tester.typeImeText(" and [links](http://google.com)");
      final linkAttribution = LinkAttribution(url: Uri.parse("http://google.com"));
      expect(
        SuperEditorInspector.findTextInComponent(nodeId).text,
        "Hello italics and bold and strikethrough and links",
      );
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: boldAttribution, offset: 18, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: strikethroughAttribution, offset: 27, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: strikethroughAttribution, offset: 39, markerType: SpanMarkerType.end),
        SpanMarker(attribution: linkAttribution, offset: 45, markerType: SpanMarkerType.start),
        SpanMarker(attribution: linkAttribution, offset: 49, markerType: SpanMarkerType.end),
      ]);
    });
  });
}
