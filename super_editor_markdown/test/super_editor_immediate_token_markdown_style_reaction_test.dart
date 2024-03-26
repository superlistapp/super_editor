import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_markdown/src/markdown_full_paragraph_style_reaction.dart';
import 'package:super_editor_markdown/src/markdown_immediate_token_style_reaction.dart';
import 'package:super_editor_markdown/src/markdown_to_document_parsing.dart';

void main() {
  group("Super Editor Markdown style reaction >", () {
    group("at beginning of paragraph >", () {
      testWidgets("bold", (tester) async {
        final document = deserializeMarkdownToDocument("");
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);
        await tester.typeImeText("**bold**");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "bold");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: boldAttribution, offset: 3, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("italics", (tester) async {
        final document = deserializeMarkdownToDocument("");
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);
        await tester.typeImeText("*italics*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "italics");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: italicsAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("strikethrough", (tester) async {
        final document = deserializeMarkdownToDocument("");
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 20);
        await tester.typeImeText("~strikethrough~");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "strikethrough");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: strikethroughAttribution, offset: 0, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: strikethroughAttribution, offset: 12, markerType: SpanMarkerType.end),
        ]);
      });

      group("unbalanced >", () {
        testWidgets("bold then italics", (tester) async {
          final document = deserializeMarkdownToDocument("");
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
                    MarkdownImmediateTokenInlineStylePlugin(),
                  },
                ),
              ),
            ),
          );

          final nodeId = document.nodes.first.id;
          await tester.placeCaretInParagraph(nodeId, 0);
          await tester.typeImeText("**token*");

          expect(SuperEditorInspector.findTextInComponent(nodeId).text, "**token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
        });

        testWidgets("italics then bold", (tester) async {
          final document = deserializeMarkdownToDocument("");
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
                    MarkdownImmediateTokenInlineStylePlugin(),
                  },
                ),
              ),
            ),
          );

          final nodeId = document.nodes.first.id;
          await tester.placeCaretInParagraph(nodeId, 0);
          await tester.typeImeText("*token**");

          expect(SuperEditorInspector.findTextInComponent(nodeId).text, "token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
            const SpanMarker(attribution: italicsAttribution, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: italicsAttribution, offset: 4, markerType: SpanMarkerType.end),
          ]);
        });
      });
    });

    group("in middle of paragraph >", () {
      testWidgets("bold", (tester) async {
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 5);

        await tester.typeImeText(" **bold**");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello bold");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: boldAttribution, offset: 9, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("italics", (tester) async {
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 5);

        await tester.typeImeText(" *italics*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello italics");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
        ]);
      });

      testWidgets("strikethrough", (tester) async {
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 5);

        await tester.typeImeText(" ~strikethrough~");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello strikethrough");
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
          const SpanMarker(attribution: strikethroughAttribution, offset: 6, markerType: SpanMarkerType.start),
          const SpanMarker(attribution: strikethroughAttribution, offset: 18, markerType: SpanMarkerType.end),
        ]);
      });

      group("unbalanced >", () {
        testWidgets("bold then italics", (tester) async {
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
                    MarkdownImmediateTokenInlineStylePlugin(),
                  },
                ),
              ),
            ),
          );

          final nodeId = document.nodes.first.id;
          await tester.placeCaretInParagraph(nodeId, 5);
          await tester.typeImeText(" **token*");

          expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello **token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers, isEmpty);
        });

        testWidgets("italics then bold", (tester) async {
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
                    MarkdownImmediateTokenInlineStylePlugin(),
                  },
                ),
              ),
            ),
          );

          final nodeId = document.nodes.first.id;
          await tester.placeCaretInParagraph(nodeId, 5);
          await tester.typeImeText(" *token**");

          expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello token*");
          expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
            const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: italicsAttribution, offset: 10, markerType: SpanMarkerType.end),
          ]);
        });
      });
    });

    group("prevented deserializations >", () {
      testWidgets("unbalanced italics", (tester) async {
        final document = deserializeMarkdownToDocument("");
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 0);

        await tester.typeImeText("**noitalics*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "**noitalics*");
        expect((document.nodes.first as ParagraphNode).text.spans.markers.isEmpty, isTrue);
      });
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
                MarkdownImmediateTokenInlineStylePlugin(),
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
    });

    testWidgets("preserves non-Markdown attributions", (tester) async {
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
                MarkdownImmediateTokenInlineStylePlugin(),
              },
            ),
          ),
        ),
      );

      final nodeId = document.nodes.first.id;

      // Add a non-Markdown attribution to the text.
      const colorAttribution = ColorAttribution(Color(0xFFFF0000));
      editor.execute([
        AddTextAttributionsRequest(
          // Attribution applied to: "He[llo *ital]ics", which is start: 2, end: 11,
          // because the end is exclusive.
          documentRange: DocumentRange(
            start: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 2),
            ),
            end: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 11),
            ),
          ),
          attributions: {
            colorAttribution,
          },
        ),
      ]);

      // Add a "*" to add italics attribution through Markdown.
      await tester.placeCaretInParagraph(nodeId, 14);
      await tester.typeImeText("*");
      expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello italics");
      expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), [
        const SpanMarker(attribution: colorAttribution, offset: 2, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: italicsAttribution, offset: 6, markerType: SpanMarkerType.start),
        const SpanMarker(attribution: colorAttribution, offset: 9, markerType: SpanMarkerType.end),
        const SpanMarker(attribution: italicsAttribution, offset: 12, markerType: SpanMarkerType.end),
      ]);
    });

    group("does not parse upstream syntax creation >", () {
      testWidgets("italics", (tester) async {
        final document = deserializeMarkdownToDocument("Hello italics*");
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 6);

        await tester.typeImeText("*");

        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello *italics*");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 7)),
          ),
        );
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);
      });

      testWidgets("bold", (tester) async {
        final document = deserializeMarkdownToDocument("Hello bold**");
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
                  MarkdownImmediateTokenInlineStylePlugin(),
                },
              ),
            ),
          ),
        );

        final nodeId = document.nodes.first.id;
        await tester.placeCaretInParagraph(nodeId, 6);

        await tester.typeImeText("*");
        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello *bold**");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 7)),
          ),
        );
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);

        await tester.typeImeText("*");
        expect(SuperEditorInspector.findTextInComponent(nodeId).text, "Hello **bold**");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 8)),
          ),
        );
        expect(SuperEditorInspector.findTextInComponent(nodeId).spans.markers.toList(), isEmpty);
      });
    });
  });
}
