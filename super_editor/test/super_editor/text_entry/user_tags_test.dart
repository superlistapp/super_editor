import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';

void main() {
  group("SuperEditor user tags >", () {
    group("composing >", () {
      // initLoggers(Level.ALL, {editorUserTags});

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

        // Place the caret at "before | after"
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

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a user token.
        await tester.typeImeText("@john after");

        // Ensure that only the user token is attributed as a token.
        final text = SuperEditorInspector.findTextInParagraph("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == userTagComposingAttribution,
            range: const SpanRange(start: 0, end: 18),
          ),
          isEmpty,
        );
        expect(
          text.getAttributedRange({const UserTagAttribution("john")}, 7),
          const SpanRange(start: 7, end: 11),
        );
      });
    });
  });
}
