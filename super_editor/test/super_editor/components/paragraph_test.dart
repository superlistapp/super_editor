import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor > Paragraph Component >", () {
    testWidgetsOnAllPlatforms("visually updates alignment immediately after it is changed", (tester) async {
      final editorContext = await tester //
          .createDocument()
          .withSingleParagraph()
          .pump();

      // Place the caret at the beginning of the paragraph.
      await tester.placeCaretInParagraph("1", 0);

      // Note the visual offset of the caret when left-aligned.
      final leftAlignedCaretOffset = SuperEditorInspector.findCaretOffsetInDocument();

      // Ensure that we begin with a visually left-aligned paragraph widget.
      var paragraphComponent = find.byType(TextComponent).evaluate().first.widget as TextComponent;
      expect(paragraphComponent.textAlign, TextAlign.left);

      // Change the paragraph to right-alignment.
      editorContext.editor.execute([
        ChangeParagraphAlignmentRequest(nodeId: "1", alignment: TextAlign.right),
      ]);
      await tester.pump();

      // Ensure that the paragraph's associated widget is now right-aligned.
      //
      // This is as close as we can get to verifying visual text alignment without either
      // inspecting the render object, or generating a golden file.
      paragraphComponent = find.byType(TextComponent).evaluate().first.widget as TextComponent;
      expect(paragraphComponent.textAlign, TextAlign.right);

      // Ensure that the caret didn't stay in the same location after changing the
      // alignment of the paragraph. This check ensures that the caret overlay updated
      // itself in response to the paragraph layout changing.
      expect(SuperEditorInspector.findCaretOffsetInDocument() == leftAlignedCaretOffset, isFalse);
    });

    group("indentation >", () {
      testWidgetsOnDesktop("indents with Tab and un-indents with Shift+Tab", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        // Place the caret in the child task.
        await tester.placeCaretInParagraph("1", 0);

        // Ensure the paragraph isn't indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 0);

        // Press Tab to indent the paragraph.
        await tester.pressTab();

        // Ensure the paragraph is indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 1);

        // Press Tab to indent a second time.
        await tester.pressTab();

        // Ensure the paragraph is indented at level 2.
        expect(SuperEditorInspector.findParagraphIndent("1"), 2);

        // Press Shift+Tab to unindent.
        // TODO: add pressShiftTab to flutter_test_robots - https://github.com/Flutter-Bounty-Hunters/flutter_test_robots/issues/30
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();

        // Ensure the paragraph was un-indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 1);

        // Press Shift+Tab to unindent.
        // TODO: add pressShiftTab to flutter_test_robots
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();

        // Ensure the paragraph was un-indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 0);

        // Press Shift+Tab to unindent (should have no effect).
        // TODO: add pressShiftTab to flutter_test_robots
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();

        // Ensure the indentation didn't change because it was already at zero.
        expect(SuperEditorInspector.findParagraphIndent("1"), 0);
      });

      testWidgetsOnDesktop("indents with Tab when caret is in middle of text", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        // Place the caret in the middle of the text.
        await tester.placeCaretInParagraph("1", 2);

        // Ensure the paragraph isn't indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 0);

        // Press Tab to indent the paragraph.
        await tester.pressTab();

        // Ensure the paragraph is indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 1);

        // Press Shift+Tab to unindent.
        // TODO: add pressShiftTab to flutter_test_robots
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();

        // Ensure the paragraph was un-indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 0);
      });

      testWidgetsOnDesktop("next paragraph preserves indent, pressing Enter removes inherited indent", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        // Place caret at the end of the paragraph.
        await tester.placeCaretInParagraph("1", SuperEditorInspector.findTextInComponent("1").length);

        // Indent the paragraph.
        await tester.pressTab();

        // Insert a new paragraph.
        await tester.pressEnter();

        // Ensure the new paragraph is indented.
        var newParagraph = SuperEditorInspector.findDocument()!.getNodeAt(1) as ParagraphNode;
        expect(newParagraph.indent, 1);

        // Press Enter again to reset the indent.
        await tester.pressEnter();

        // Ensure the new paragraph is no longer indented.
        newParagraph = SuperEditorInspector.findDocument()!.getNodeAt(1) as ParagraphNode;
        expect(newParagraph.indent, 0);
      });

      testWidgetsOnDesktop("Backspace at start of text un-indents paragraph", (tester) async {
        await tester //
            .createDocument()
            .withSingleParagraph()
            .pump();

        await tester.placeCaretInParagraph("1", 0);

        // Indent the paragraph.
        await tester.pressTab();

        // Ensure the second task is indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 1);

        // Place the caret in the middle of the text
        await tester.placeCaretInParagraph("1", 3);

        // Press Backspace to delete one character.
        await tester.pressBackspace();

        // Ensure that the Backspace didn't un-indent the paragraph.
        expect(SuperEditorInspector.findParagraphIndent("1"), 1);

        // Place caret at start of the paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Press Backspace to un-indent the task.
        await tester.pressBackspace();

        // Ensure the paragraph was un-indented.
        expect(SuperEditorInspector.findParagraphIndent("1"), 0);
      });
    });
  });
}
