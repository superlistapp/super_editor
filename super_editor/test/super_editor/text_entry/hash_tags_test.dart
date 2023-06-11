import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';
import '../test_documents.dart';

void main() {
  group("SuperEditor hash tags >", () {
    group("composing >", () {
      // initLoggers(Level.ALL, {editorHashTagsLog});

      testWidgetsOnAllPlatforms("can start at the beginning of a paragraph", (tester) async {
        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );
        await tester.placeCaretInParagraph("1", 0);

        // Compose a user token.
        await tester.typeImeText("#john");

        // Ensure that the token has a composing attribution.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "#john");
        expect(
          text.getAttributedRange({const HashTagAttribution("john")}, 0),
          const SpanRange(start: 0, end: 4),
        );
      });

      testWidgetsOnAllPlatforms("can start between words", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(text: "before  after"),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a user token.
        await tester.typeImeText("#john");

        // Ensure that the token has a composing attribution.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "before #john after");
        expect(
          text.getAttributedRange({const HashTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });

      testWidgetsOnAllPlatforms("does not continue after a space", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(text: "before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a hash tag.
        await tester.typeImeText("#john after");

        // Ensure that there's no more composing attribution because the token
        // should have been committed.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "before #john after");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution is HashTagAttribution,
            range: const SpanRange(start: 0, end: 18),
          ),
          {
            const AttributionSpan(
              attribution: HashTagAttribution("john"),
              start: 7,
              end: 11,
            ),
          },
        );
      });

      testWidgetsOnAllPlatforms("continues when user expands the selection upstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(text: "before "),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(text: ""),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a hash tag.
        await tester.typeImeText("#john");

        // Expand the selection to "before #joh|n|"
        await tester.pressShiftLeftArrow();
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );

        // Ensure we're still composing
        AttributedText text = SuperEditorInspector.findTextInParagraph("1");
        expect(
          text.getAttributedRange({const HashTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );

        // Expand the selection to "before |#john|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still composing
        text = SuperEditorInspector.findTextInParagraph("1");
        expect(
          text.getAttributedRange({const HashTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );

        // Expand the selection to "befor|e #john|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still composing
        text = SuperEditorInspector.findTextInParagraph("1");
        expect(
          text.getAttributedRange({const HashTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });

      testWidgetsOnAllPlatforms("continues when user expands the selection downstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(text: "before  after"),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(text: ""),
              ),
            ],
          ),
        );

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a hash tag.
        await tester.typeImeText("#john");

        // Move the caret to "before #|john".
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();

        // Expand the selection to "before #|john a|fter"
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 14),
            ),
          ),
        );

        // Ensure we're still composing
        AttributedText text = SuperEditorInspector.findTextInParagraph("1");
        expect(
          text.getAttributedRange({const HashTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });
    });

    group("caret placement >", () {
      testWidgetsOnAllPlatforms("doesn't prevent user from tapping to place caret in token", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(text: "before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a hash tag.
        await tester.typeImeText("#john after");

        // Tap near the end of the token.
        await tester.placeCaretInParagraph("1", 10);

        // Ensure that the caret was placed where tapped.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 10),
            ),
          ),
        );

        // Tap near the beginning of the token.
        await tester.placeCaretInParagraph("1", 8);

        // Ensure that the caret was placed where tapped.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes expanding downstream selection into the tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(text: "before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a hash tag.
        await tester.typeImeText("#john after");

        // Place the caret at "befor|e #john after"
        await tester.placeCaretInParagraph("1", 5);

        // Expand downstream until we push one character into the token.
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();

        // Ensure that the extent pushed into the token.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 5),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 8),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes expanding upstream selection around into the tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(text: "before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a hash tag.
        await tester.typeImeText("#john after");

        // Place the caret at "before #john a|fter"
        await tester.placeCaretInParagraph("1", 14);

        // Expand upstream until we push one character into the token.
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure that the extent was pushed into the token.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 14),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      });
    });
  });
}

Future<TestDocumentContext> _pumpTestEditor(WidgetTester tester, MutableDocument document) async {
  return await tester //
      .createDocument()
      .withCustomContent(document)
      .withAddedReactions(
    [
      const KeepCaretOutOfTagReaction(),
      TagUserReaction(),
      HashTagReaction(),
    ],
  ).pump();
}
