import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../super_editor/supereditor_test_tools.dart';
import '../../super_editor/test_documents.dart';

void main() {
  group("Clones > Slack > tags >", () {
    initLoggers(Level.ALL, {editorSlackTagsLog});

    group("composing >", () {
      testWidgetsOnAllPlatforms("can start at the beginning of a paragraph", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );

        await tester.placeCaretInParagraph("1", 0);

        // Compose a slack tag.
        await tester.typeImeText("@john");

        // Ensure that the tag has a composing attribution.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "@john");

        final composingTag = tagIndex.composingSlackTag.value;
        expect(composingTag, isNotNull);
        expect(
          composingTag!.contentBounds,
          const DocumentRange(
            start: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
            end: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 4),
            ),
          ),
        );
        expect(
          composingTag.token,
          "john",
        );
      });

      testWidgetsOnAllPlatforms("can start between words", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
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

        // Compose a slack tag.
        await tester.typeImeText("@john");

        // Ensure that the tag has a composing attribution.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "before @john after");

        final composingTag = tagIndex.composingSlackTag.value;
        expect(composingTag, isNotNull);
        expect(
          composingTag!.contentBounds,
          const DocumentRange(
            start: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
            end: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
        expect(
          composingTag.token,
          "john",
        );
      });

      testWidgetsOnAllPlatforms("continues after a space", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
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

        // Compose a slack tag.
        await tester.typeImeText("@john after");

        final composingTag = tagIndex.composingSlackTag.value;
        expect(composingTag, isNotNull);
        expect(
          composingTag!.contentBounds,
          const DocumentRange(
            start: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
            end: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 17),
            ),
          ),
        );
        expect(
          composingTag.token,
          "john after",
        );
      });

      testWidgetsOnAllPlatforms("stops after typing beyond max tag length", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
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

        // Type max allowable characters of a tag token.
        await tester.typeImeText("@abc efg ijklm o");

        final composingTag = tagIndex.composingSlackTag.value;
        expect(composingTag, isNotNull);
        expect(
          composingTag!.token,
          "abc efg ijklm o",
        );

        // Type one more character than the max range allows
        await tester.typeImeText("p");
        expect(tagIndex.composingSlackTag.value, isNull);

        // Backspace back into allowable range.
        await tester.pressBackspace();

        // Ensure that we're composing again.
        expect(tagIndex.composingSlackTag.value, isNotNull);
        expect(
          tagIndex.composingSlackTag.value!.token,
          "abc efg ijklm o",
        );
      });

      testWidgetsOnAllPlatforms("starts and stops composing when moving character in and out of max range",
          (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
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

        // Type max allowable characters of a tag token.
        await tester.typeImeText("@abc efg ijklm o");

        // Ensure we're composing.
        final composingTag = tagIndex.composingSlackTag.value;
        expect(composingTag, isNotNull);

        // Type one more character than the max range allows and ensure composing stopped.
        await tester.typeImeText("p");
        expect(tagIndex.composingSlackTag.value, isNull);

        // Place the caret back at the beginning of the tag.
        await tester.placeCaretInParagraph("1", 8);

        // Ensure we're composing again.
        expect(tagIndex.composingSlackTag.value, isNotNull);
        expect(
          tagIndex.composingSlackTag.value!.token,
          "",
        );

        // Place the caret in the middle of the tag.
        await tester.placeCaretInParagraph("1", 12);

        // Ensure we're still composing, with an expanded token.
        expect(tagIndex.composingSlackTag.value, isNotNull);
        expect(
          tagIndex.composingSlackTag.value!.token,
          "abc ",
        );

        // Place the caret at the max allowable range.
        await tester.placeCaretInParagraph("1", 23);

        // Ensure we're still composing, with an expanded token.
        expect(tagIndex.composingSlackTag.value, isNotNull);
        expect(
          tagIndex.composingSlackTag.value!.token,
          "abc efg ijklm o",
        );

        // Place the caret beyond the max allowable range.
        await tester.placeCaretInParagraph("1", 24);
        expect(tagIndex.composingSlackTag.value, isNull);
      });

      testWidgetsOnAllPlatforms("stops when user expands the selection upstream", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
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

        // Compose a slack tag.
        await tester.typeImeText("@john");

        // Expand the selection upstream to "before @joh|n|"
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

        // Ensure the tag composition has ended.
        final composingTag = tagIndex.composingSlackTag.value;
        expect(composingTag, isNull);
      });

      testWidgetsOnAllPlatforms("stops when user expands the selection downstream", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
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

        // Compose a slack tag.
        await tester.typeImeText("@john");

        // Expand upstream to "before @john| |".
        await tester.pressShiftRightArrow();

        // Ensure the tag composition has ended.
        final composingTag = tagIndex.composingSlackTag.value;
        expect(composingTag, isNull);
      });

      testWidgetsOnAllPlatforms("cancels composing when the user presses ESC", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
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

        // Start composing a slack tag.
        await tester.typeImeText("@");

        // Ensure that we're composing.
        expect(tagIndex.composingSlackTag.value, isNotNull);

        // Cancel composing.
        await tester.pressEscape();

        // Ensure that the composing was cancelled.
        expect(tagIndex.composingSlackTag.value, isNull);

        // Start typing again.
        await tester.typeImeText("j");

        // Ensure that we didn't start composing again.
        expect(tagIndex.composingSlackTag.value, isNull);
      });

      testWidgetsOnAllPlatforms("notifies tag index listeners when tag changes", (tester) async {
        final (_, tagIndex) = await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );
        await tester.placeCaretInParagraph("1", 0);

        // Listen for tag notifications.
        int tagNotificationCount = 0;
        tagIndex.composingSlackTag.addListener(() {
          tagNotificationCount += 1;
        });

        // Type some non tag text.
        await tester.typeImeText("hello ");

        // Ensure that no tag notifications were sent, because the typed text
        // has no tag artifacts.
        expect(tagNotificationCount, 0);

        // Start a tag.
        await tester.typeImeText("@");

        // Ensure that the first notification was sent, because a tag was started.
        expect(tagNotificationCount, 1);

        // Add to the tag.
        await tester.typeImeText("world ");

        // Ensure that we received a notification for each character.
        expect(tagNotificationCount, 7);

        // Backspace over a character.
        await tester.pressBackspace();

        // Ensure that we received a notification for the character deletion.
        expect(tagNotificationCount, 8);
      });
    });

    group("commits >", () {
      testWidgetsOnAllPlatforms("when instructed to commit", (tester) async {
        final (testContext, tagIndex) = await _pumpTestEditor(
          tester,
          singleParagraphEmptyDoc(),
        );

        // Type a search term when trying to tag "John Smith".
        await tester.placeCaretInParagraph("1", 0);
        await tester.typeImeText("hello @jo sm");

        // Ensure that we're composing a tag.
        expect(tagIndex.isComposing, isTrue);

        // Simulate the submission of the selected user. This would happen within
        // the popover search results UI.
        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();

        // Ensure that the text was updated to the provided value.
        final text = SuperEditorInspector.findTextInComponent("1");
        expect(text.text, "hello @John Smith ");

        // Ensure that the text is attributed as a committed tag.
        expect(
          text.getAttributedRange({const CommittedSlackTagAttribution("John Smith")}, 6),
          const SpanRange(6, 16),
        );
      });
    });

    group("committed >", () {
      testWidgetsOnAllPlatforms("prevents user tapping to place caret in tag", (tester) async {
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

        // Tap near the end of the tag.
        await tester.placeCaretInParagraph("1", 15);

        // Ensure that the caret was pushed beyond the end of the tag.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 18),
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
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

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
              nodePosition: TextNodePosition(offset: 18),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes caret downstream around the tag", (tester) async {
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

        // Type more content after tag.
        await tester.typeImeText("after");

        // Place the caret at "befor|e @John Smith after"
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
              nodePosition: TextNodePosition(offset: 18),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes caret upstream around the tag", (tester) async {
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

        // Type more content after tag.
        await tester.typeImeText("after");

        // Place the caret at "before @John Smith a|fter"
        await tester.placeCaretInParagraph("1", 20);

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
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

        // Type more content after tag.
        await tester.typeImeText("after");

        // Place the caret at "befor|e @John Smith after"
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
              nodePosition: TextNodePosition(offset: 18),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("pushes expanding upstream selection around the tag", (tester) async {
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

        // Type more content after tag.
        await tester.typeImeText("after");

        // Place the caret at "before @John Smith a|fter"
        await tester.placeCaretInParagraph("1", 20);

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
              nodePosition: TextNodePosition(offset: 20),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("deletes entire tag when deleting a character upstream", (tester) async {
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

        // Type more content after tag.
        await tester.typeImeText("after");

        // Place the caret at "before @John Smith| after"
        await tester.placeCaretInParagraph("1", 18);

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
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose and submit a slack tag.
        await tester.typeImeText("@john");

        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "before @John Smith ");

        // Type more content after tag.
        await tester.typeImeText("after");

        // Place the caret at "before |@John Smith after"
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
        final (testContext, _) = await _pumpTestEditor(
          tester,
          MutableDocument.empty("1"),
        );

        await tester.placeCaretInParagraph("1", 0);

        // Compose two tags within text.
        await tester.typeImeText("one @john");
        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith ");

        // Type and commit a second tag.
        await tester.typeImeText("two @sally");
        testContext.editor.execute([const FillInComposingSlackTagRequest("Sally Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith two @Sally Smith ");

        // Type after the second tag.
        await tester.typeImeText("three");
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith two @Sally Smith three");

        // Place the caret at "one @John Smith two @Sally Smith| three"
        await tester.placeCaretInParagraph("1", 32);

        // Delete the 2nd tag.
        await tester.pressBackspace();

        // Ensure the 2nd tag was deleted, and the 1st tag remains.
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith two  three");
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 20),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("deletes multiple tags when partially selected in the same node", (tester) async {
        final (testContext, _) = await _pumpTestEditor(
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

        // Compose two tags within text.
        await tester.typeImeText("@john");
        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith ");

        // Type and commit a second tag.
        await tester.typeImeText("two @sally");
        testContext.editor.execute([const FillInComposingSlackTagRequest("Sally Smith")]);
        await tester.pump();
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith two @Sally Smith ");

        // Type after the second tag.
        await tester.typeImeText("three");
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith two @Sally Smith three");

        // Expand the selection "one @Jo|hn Smith two @Sa|lly Smith three"
        (testContext.findEditContext().composer as MutableDocumentComposer).setSelectionWithReason(
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 7),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 23),
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
        final (testContext, _) = await _pumpTestEditor(
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
        await tester.typeImeText("one @john");
        testContext.editor.execute([const FillInComposingSlackTagRequest("John Smith")]);
        await tester.pump();
        await tester.typeImeText("two");
        expect(SuperEditorInspector.findTextInComponent("1").text, "one @John Smith two");

        // Move the caret to the second paragraph and insert a second user tag.
        await tester.placeCaretInParagraph("2", 0);
        await tester.typeImeText("three @sally");
        testContext.editor.execute([const FillInComposingSlackTagRequest("Sally Smith")]);
        await tester.pump();
        await tester.typeImeText("four");
        expect(SuperEditorInspector.findTextInComponent("2").text, "three @Sally Smith four");

        // Expand the selection to "one @Jo|hn Smith two\nthree @Sa|lly Smith three"
        (testContext.findEditContext().composer as MutableDocumentComposer).setSelectionWithReason(
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

    group("unbound >", () {
      // TODO:
    });

    group("cancelled >", () {
      // TODO:
    });
  });
}

Future<(TestDocumentContext, SlackTagIndex)> _pumpTestEditor(
  WidgetTester tester,
  MutableDocument document,
) async {
  final testContext = await tester //
      .createDocument()
      .withCustomContent(document)
      .withPlugin(SlackTagPlugin())
      .pump();

  return (testContext, testContext.editor.context.find<SlackTagIndex>(SlackTagPlugin.slackTagIndexKey));
}
