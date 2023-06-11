import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';

void main() {
  group("SuperEditor user tags >", () {
    group("composing >", () {
      initLoggers(Level.INFO, {editorUserTags});

      testWidgetsOnAllPlatforms("can start at the beginning of a paragraph", (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withAddedReactions([
              TagUserReaction(),
            ])
            .autoFocus(true)
            .pump();

        // Compose a user token.
        await tester.typeImeText("@john");

        // Ensure that the token has a composing attribution.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "@john");
        expect(
          text.getAttributedRange({userTagComposingAttribution}, 0),
          const SpanRange(start: 0, end: 4),
        );
      });

      testWidgetsOnAllPlatforms("can start between words", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(
                  id: "1",
                  text: AttributedText(text: "before  after"),
                ),
              ],
            ))
            .withAddedReactions([
          TagUserReaction(),
        ]).pump();

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a user token.
        await tester.typeImeText("@john");

        // Ensure that the token has a composing attribution.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributedRange({userTagComposingAttribution}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });

      testWidgetsOnAllPlatforms("does not continue after a space", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(
                  id: "1",
                  text: AttributedText(text: "before "),
                ),
              ],
            ))
            .withAddedReactions([
          TagUserReaction(),
        ]).pump();

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a user token.
        await tester.typeImeText("@john after");

        // Ensure that there's no more composing attribution because the token
        // should have been committed.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == userTagComposingAttribution,
            range: const SpanRange(start: 0, end: 18),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("continues when user expands the selection upstream", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
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
            ))
            .withAddedReactions([
          TagUserReaction(),
        ]).pump();

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a user token.
        await tester.typeImeText("@john");

        // Expand the selection to "before @joh|n|"
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
          text.getAttributedRange({userTagComposingAttribution}, 7),
          const SpanRange(start: 7, end: 11),
        );

        // Expand the selection to "before |@john|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still composing
        text = SuperEditorInspector.findTextInParagraph("1");
        expect(
          text.getAttributedRange({userTagComposingAttribution}, 7),
          const SpanRange(start: 7, end: 11),
        );

        // Expand the selection to "befor|e @john|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still composing
        text = SuperEditorInspector.findTextInParagraph("1");
        expect(
          text.getAttributedRange({userTagComposingAttribution}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });
    });

    group("commits >", () {
      testWidgetsOnAllPlatforms("at the beginning of a paragraph", (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withAddedReactions([
          TagUserReaction(),
        ]).pump();

        // Place the caret in the empty paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Compose a user token.
        await tester.typeImeText("@john after");

        // Ensure that only the user token is attributed as a token.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "@john after");
        expect(
          text.getAttributedRange({const UserTagAttribution("john")}, 0),
          const SpanRange(start: 0, end: 4),
        );
      });

      testWidgetsOnAllPlatforms("after existing text", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
              nodes: [
                ParagraphNode(
                  id: "1",
                  text: AttributedText(text: "before "),
                ),
              ],
            ))
            .withAddedReactions([
          TagUserReaction(),
        ]).pump();

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a user token.
        await tester.typeImeText("@john after");

        // Ensure that only the user token is attributed as a token.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributedRange({const UserTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });

      testWidgetsOnAllPlatforms("at end of text when user moves the caret", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(MutableDocument(
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
            ))
            .withAddedReactions([
          TagUserReaction(),
        ]).pump();

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a user token.
        await tester.typeImeText("@john");

        // Move the selection somewhere else.
        await tester.placeCaretInParagraph("2", 0);
        expect(
          SuperEditorInspector.findDocumentSelection()!.extent,
          const DocumentPosition(
            nodeId: "2",
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        // Ensure that the token was submitted.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "before @john");
        expect(
          text.getAttributedRange({const UserTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });
    });
  });
}
