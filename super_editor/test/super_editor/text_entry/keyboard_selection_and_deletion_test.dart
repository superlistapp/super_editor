import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';

void main() {
  group("SuperEditor keyboard movement >", () {
    group("Mac >", () {
      testWidgetsOnMac("option + backspace: deletes a word upstream", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press option + backspace
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem  dolor sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 6),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnMac("option + backspace: deletes a word upstream (after a space)", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum |dolor sit amet...
        await tester.placeCaretInParagraph("1", 12);

        // Press option + backspace
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem dolor sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 6),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnMac("option + delete: deletes a word downstream", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum |dolor sit amet...
        await tester.placeCaretInParagraph("1", 12);

        // Press option + delete
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text, startsWith("Lorem ipsum  sit amet"));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnMac("option + delete: deletes a word downstream (before a space)", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press option + delete
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem ipsum sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnMac("control + backspace: deletes a single upstream character", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press control + backspace
        await tester.pressCtlBackspace();

        // Ensure that a character was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem ipsu dolor sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 10),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnMac("control + delete: deletes a single downstream character", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press control + delete
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

        // Ensure that a character was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem ipsumdolor sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      }, variant: _inputSourceVariant);
    });

    group("Windows and Linux >", () {
      testWidgetsOnWindowsAndLinux("control + backspace: deletes a word upstream", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press control + backspace
        await tester.pressCtlBackspace();

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem  dolor sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 6),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnWindowsAndLinux("control + backspace: deletes a word upstream (after a space)", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum |dolor sit amet...
        await tester.placeCaretInParagraph("1", 12);

        // Press control + backspace
        await tester.pressCtlBackspace();

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem dolor sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 6),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnWindowsAndLinux("control + delete: deletes a word downstream", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum |dolor sit amet...
        await tester.placeCaretInParagraph("1", 12);

        // Press control + delete
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text, startsWith("Lorem ipsum  sit amet"));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnWindowsAndLinux("control + backspace: deletes a word downstream (before a space)", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press control + delete
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

        // Ensure that the whole word was deleted.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text.startsWith("Lorem ipsum sit amet"), isTrue);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnWindowsAndLinux("alt + backspace: deletes upstream character", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press alt + backspace
        await tester.pressAltBackspace();

        // Ensure that nothing changed.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text, startsWith("Lorem ipsu dolor sit amet"));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 10),
            ),
          ),
        );
      }, variant: _inputSourceVariant);

      testWidgetsOnWindowsAndLinux("alt + delete: deletes downstream character", (tester) async {
        final testContext = await tester
            .createDocument() //
            .withSingleParagraph()
            .withInputSource(_inputSourceVariant.currentValue!)
            .pump();

        // Lorem ipsum| dolor sit amet...
        await tester.placeCaretInParagraph("1", 11);

        // Press alt + delete
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

        // Ensure that nothing changed.
        final paragraphNode = testContext.editContext.document.nodes.first as ParagraphNode;
        expect(paragraphNode.text.text, startsWith("Lorem ipsumdolor sit amet"));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 11),
            ),
          ),
        );
      }, variant: _inputSourceVariant);
    });
  });
}

final _inputSourceVariant = ValueVariant({
  TextInputSource.keyboard,
  TextInputSource.ime,
});
