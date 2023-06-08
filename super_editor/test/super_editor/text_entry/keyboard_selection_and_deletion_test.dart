import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    testWidgetsOnMac("deletes a word upstream with option + backspace", (tester) async {
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

    testWidgetsOnMac("deletes a word upstream (after a space) with option + backspace", (tester) async {
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

    testWidgetsOnMac("deletes a word downstream with option + delete", (tester) async {
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

    testWidgetsOnMac("deletes a word downstream (before a space) with option + backspace", (tester) async {
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
  });
}

final _inputSourceVariant = ValueVariant({
  TextInputSource.keyboard,
  TextInputSource.ime,
});
