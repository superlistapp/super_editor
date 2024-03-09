import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../supereditor_test_tools.dart';
import '../../test_documents.dart';

void main() {
  group("SuperEditor stable tags >", () {
    group("composing >", () {
      testWidgetsOnAllPlatforms("can start at the beginning of a paragraph", (tester) async {
        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );
        await tester.placeCaretInParagraph("1", 0);

        // Compose a stable tag.
        await tester.typeImeText("@john");

        // Ensure that the tag has a composing attribution.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "@john");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 0),
          const SpanRange(0, 4),
        );
      });

      testWidgetsOnAllPlatforms("can start between words", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
        await tester.typeImeText("@john");

        // Ensure that the tag has a composing attribution.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 11),
        );
      });

      testWidgetsOnAllPlatforms("by default does not continue after a space", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
        await tester.typeImeText("@john after");

        // Ensure that there's no more composing attribution because the tag
        // should have been committed.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == stableTagComposingAttribution,
            range: const SpanRange(0, 18),
          ),
          isEmpty,
        );
      });

      testWidgetsOnAllPlatforms("can be configured to continue after a space", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
          plugin: StableTagPlugin(
            tagRule: const TagRule(trigger: '@'),
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
        await tester.typeImeText("@john");

        // Ensure that we started composing a tag before adding a space.
        var text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 11),
        );

        await tester.typeImeText(" after");

        // Ensure that the composing attribution continues after the space.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 17),
        );
      });

      testWidgetsOnAllPlatforms("continues when user expands the selection upstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
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
        AttributedText text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 11),
        );

        // Expand the selection to "before |@john|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still composing
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 11),
        );

        // Expand the selection to "befor|e @john|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure we're still composing
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 11),
        );
      });

      testWidgetsOnAllPlatforms("continues when user expands the selection downstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
        await tester.typeImeText("@john");

        // Move the caret to "before @|john".
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();

        // Expand the selection to "before @|john a|fter"
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
        AttributedText text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 11),
        );
      });

      testWidgetsOnAllPlatforms("cancels composing when the user presses ESC", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Start composing a stable tag.
        await tester.typeImeText("@");

        // Ensure that we're composing.
        var text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributedRange({stableTagComposingAttribution}, 7),
          const SpanRange(7, 7),
        );

        // Cancel composing.
        await tester.pressEscape();

        // Ensure that the composing was cancelled.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == stableTagComposingAttribution,
            range: const SpanRange(0, 7),
          ),
          isEmpty,
        );
        expect(
          text.getAttributedRange({stableTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );

        // Start typing again.
        await tester.typeImeText("j");

        // Ensure that we didn't start composing again.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @j");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == stableTagComposingAttribution,
            range: const SpanRange(0, 8),
          ),
          isEmpty,
        );
        expect(
          text.getAttributedRange({stableTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );

        // Add a space, cause the tag to end.
        await tester.typeImeText(" ");

        // Ensure that the cancelled tag wasn't committed, and didn't start composing again.
        text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @j ");
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution == stableTagComposingAttribution,
            range: const SpanRange(0, 9),
          ),
          isEmpty,
        );
        expect(
          text.getAttributionSpansInRange(
            attributionFilter: (attribution) => attribution is CommittedStableTagAttribution,
            range: const SpanRange(0, 9),
          ),
          isEmpty,
        );
        expect(
          text.getAttributedRange({stableTagCancelledAttribution}, 7),
          const SpanRange(7, 7),
        );
      });

      testWidgetsOnAllPlatforms("only notifies tag index listeners when tags change", (tester) async {
        final testContext = await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );
        await tester.placeCaretInParagraph("1", 0);

        // Listen for tag notifications.
        int tagNotificationCount = 0;
        testContext.editor.context.stableTagIndex.addListener(() {
          tagNotificationCount += 1;
        });

        // Type some non tag text.
        await tester.typeImeText("hello ");

        // Ensure that no tag notifications were sent, because the typed text
        // has no tag artifacts.
        expect(tagNotificationCount, 0);

        // Start a tag.
        await tester.typeImeText("@");

        // Ensure that no tag notifications were sent, because we haven't completed
        // a tag.
        expect(tagNotificationCount, 0);

        // Create and update a tag.
        await tester.typeImeText("world ");

        // Ensure that we received a notification when the tag was committed.
        expect(tagNotificationCount, 1);

        // Delete the committed tag.
        await tester.pressBackspace();
        await tester.pressBackspace();

        // Ensure that we received a notification when the tag was deleted.
        expect(tagNotificationCount, 2);

        // Create a tag and then cancel it.
        await tester.typeImeText("@cancelled");
        await tester.pressEscape();

        // Ensure that we received a notification when the tag was cancelled.
        expect(tagNotificationCount, 3);
      });

      testWidgetsOnAllPlatforms("support emojis", (tester) async {
        // Ensure we can type an emoji as first character
        // https://github.com/superlistapp/super_editor/issues/1863 is fixed
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(""),
              ),
            ],
          ),
        );

        // Place the caret at the beginning of the paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Type an emoji as first charactet 💙
        await tester.typeImeText("💙");

        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 2),
            ),
          ),
        );

        //Place the caret before the emoji
        await tester.pressLeftArrow();

        // Type @, the TagRule trigger
        // Ensure TagFinder.findTagArounPosition doesn't lead to a cropped emoji
        // This would make Flutter ParagraphBuilder raise
        // "Invalid argument(s): string is not well-formed UTF-16" on Flutter
        await tester.typeImeText("@");

        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "@💙");
      });

      testWidgetsOnAllPlatforms("composing tag with consecutive trigger characters", (tester) async {
        final plugin = StableTagPlugin();
        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
          plugin: plugin,
        );
        await tester.placeCaretInParagraph("1", 0);

        // Type two consecutive trigger characters.
        await tester.typeImeText("@@");

        final composingStableTag = plugin.tagIndex.composingStableTag.value!;

        // Ensure the composing tag is correct is placed on the second @, with empty token.
        expect(
          composingStableTag,
          const ComposingStableTag(
              DocumentRange(
                start: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 2),
                ),
                end: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 2),
                ),
              ),
              ''),
        );

        final commitedTags = plugin.tagIndex.getCommittedTagsInTextNode('1');

        expect(commitedTags.length, 1);

        final commitTag = commitedTags.first;

        // Ensure the committed tag is correct is the first @
        expect(commitTag, const IndexedTag(Tag('@', ''), '1', 0));
      });
    });

    group("commits >", () {
      testWidgetsOnAllPlatforms("at the beginning of a paragraph", (tester) async {
        await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );

        // Place the caret in the empty paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Compose a stable tag.
        await tester.typeImeText("@john after");

        // Ensure that only the stable tag is attributed as a stable tag.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "@john after");
        expect(
          text.getAttributedRange({const CommittedStableTagAttribution("john")}, 0),
          const SpanRange(0, 4),
        );
      });

      testWidgetsOnAllPlatforms("after existing text", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
        await tester.typeImeText("@john after");

        // Ensure that only the stable tag is attributed as a stable tag.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributedRange({const CommittedStableTagAttribution("john")}, 7),
          const SpanRange(7, 11),
        );
      });

      testWidgetsOnAllPlatforms("at end of text when user moves the caret", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
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

        // Ensure that the tag was submitted.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john");
        expect(
          text.getAttributedRange({const CommittedStableTagAttribution("john")}, 7),
          const SpanRange(7, 11),
        );
      });

      testWidgetsOnAllPlatforms("when upstream selection collapses outside of tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
        await tester.typeImeText("@john");

        // Expand the selection to "befor|e @john|"
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Collapse the selection to the upstream position.
        await tester.pressLeftArrow();

        // Ensure that the stable tag was submitted.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john");
        expect(
          text.getAttributedRange({const CommittedStableTagAttribution("john")}, 7),
          const SpanRange(7, 11),
        );
      });

      testWidgetsOnAllPlatforms("when downstream selection collapses outside of tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before  after"),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret at "before | after"
        await tester.placeCaretInParagraph("1", 7);

        // Compose a stable tag.
        await tester.typeImeText("@john");

        // Move caret to "before @|john after"
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();

        // Expand the selection to "before @|john a|fter"
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();

        // Collapse the selection to the downstream position.
        await tester.pressRightArrow();

        // Ensure that the stable tag was submitted.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john after");
        expect(
          text.getAttributedRange({const CommittedStableTagAttribution("john")}, 7),
          const SpanRange(7, 11),
        );
      });
    });

    group("committed >", () {
      testWidgetsOnAllPlatforms("prevents user tapping to place caret in tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Tap near the end of the tag.
        await tester.placeCaretInParagraph("1", 10);

        // Ensure that the caret was pushed beyond the end of the tag.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );

        // Tap near the beginning of the tag.
        await tester.placeCaretInParagraph("1", 8);

        // Ensure that the caret was pushed beyond the beginning of the tag.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("selects entire tag when double tapped", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Double tap on "john"
        await tester.doubleTapInParagraph("1", 10);

        // Ensure that the selection surrounds the full tag, including the "@"
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes caret downstream around the tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Place the caret at "befor|e @john after"
        await tester.placeCaretInParagraph("1", 5);

        // Push the caret downstream until we push one character into the tag.
        await tester.pressRightArrow();
        await tester.pressRightArrow();
        await tester.pressRightArrow();

        // Ensure that the caret was pushed beyond the end of the tag.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes caret upstream around the tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Place the caret at "before @john a|fter"
        await tester.placeCaretInParagraph("1", 14);

        // Push the caret upstream until we push one character into the tag.
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();
        await tester.pressLeftArrow();

        // Ensure that the caret pushed beyond the beginning of the tag.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes expanding downstream selection around the tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Place the caret at "befor|e @john after"
        await tester.placeCaretInParagraph("1", 5);

        // Expand downstream until we push one character into the tag.
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();
        await tester.pressShiftRightArrow();

        // Ensure that the extent was pushed beyond the end of the tag.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 5),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes expanding upstream selection around the tag", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Place the caret at "before @john a|fter"
        await tester.placeCaretInParagraph("1", 14);

        // Expand upstream until we push one character into the tag.
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();
        await tester.pressShiftLeftArrow();

        // Ensure that the extent was pushed beyond the beginning of the tag.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 14),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("deletes entire tag when deleting a character upstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Place the caret at "before @john| after"
        await tester.placeCaretInParagraph("1", 12);

        // Press BACKSPACE to delete a character upstream.
        await tester.pressBackspace();

        // Ensure that the entire user tag was deleted.
        expect(SuperEditorInspector.findTextInComponent("1").text, "before  after");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("deletes entire tag when deleting a character downstream", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("before "),
              ),
            ],
          ),
        );

        // Place the caret at "before |"
        await tester.placeCaretInParagraph("1", 7);

        // Compose and submit a stable tag.
        await tester.typeImeText("@john after");

        // Place the caret at "before |@john after"
        await tester.placeCaretInParagraph("1", 7);

        // Press DELETE to delete a character downstream.
        await tester.pressDelete();

        // Ensure that the entire user tag was deleted.
        expect(SuperEditorInspector.findTextInComponent("1").text, "before  after");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("deletes second tag and leaves first tag alone", (tester) async {
        await _pumpTestEditor(
          tester,
          MutableDocument.empty("1"),
        );

        await tester.placeCaretInParagraph("1", 0);

        // Compose two tags within text
        await tester.typeImeText("one @john two @sally three");

        // Place the caret at "one @john two @sally| three"
        await tester.placeCaretInParagraph("1", 20);

        // Delete the 2nd tag.
        await tester.pressBackspace();

        // Ensure the 2nd tag was deleted, and the 1st tag remains.
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @john two  three");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 14),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("deletes multiple tags when partially selected in the same node", (tester) async {
        final context = await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText("one "),
              ),
            ],
          ),
        );

        // Place the caret at "one |"
        await tester.placeCaretInParagraph("1", 4);

        // Compose and submit two stable tags.
        await tester.typeImeText("@john two @sally three");

        // Expand the selection "one @jo|hn two @sa|lly three"
        (context.findEditContext().composer as MutableDocumentComposer).setSelectionWithReason(
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 17),
            ),
          ),
          SelectionReason.userInteraction,
        );

        // Delete the selected content, which will leave two partial user tags.
        await tester.pressBackspace();

        // Ensure that both user tags were completely deleted.
        expect(SuperEditorInspector.findTextInComponent("1").text, "one  three");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 4),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("deletes multiple tags when partially selected across multiple nodes", (tester) async {
        final context = await _pumpTestEditor(
          tester,
          MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(),
              ),
            ],
          ),
        );

        // Place the caret in the first paragraph and insert a user tag.
        await tester.placeCaretInParagraph("1", 0);
        await tester.typeImeText("one @john two");

        // Move the caret to the second paragraph and insert a second user tag.
        await tester.placeCaretInParagraph("2", 0);
        await tester.typeImeText("three @sally four");

        // Expand the selection to "one @jo|hn two\nthree @sa|lly three"
        (context.findEditContext().composer as MutableDocumentComposer).setSelectionWithReason(
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
            extent: DocumentPosition(
              nodeId: "2",
              nodePosition: TextNodePosition(offset: 9),
            ),
          ),
          SelectionReason.userInteraction,
        );

        // Delete the selected content, which will leave two partial user tags.
        await tester.pressBackspace();

        // Ensure that both user tags were completely deleted.
        expect(SuperEditorInspector.findTextInComponent("1").text, "one  four");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 4),
            ),
          ),
        );
      });
    });
  });
}

Future<TestDocumentContext> _pumpTestEditor(
  WidgetTester tester,
  MutableDocument document, {
  SuperEditorPlugin? plugin,
}) async {
  return await tester
      .createDocument()
      .withCustomContent(document)
      .withPlugin(plugin ??
          StableTagPlugin(
            tagRule: userTagRule,
          ))
      .pump();
}
