import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

import 'supereditor_test_tools.dart';

void main() {
  group("Super Editor > undo redo >", () {
    testWidgets("insert a word", (widgetTester) async {
      final document = deserializeMarkdownToDocument("Hello  world");
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);
      final paragraphId = document.nodes.first.id;

      editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: paragraphId,
              nodePosition: const TextNodePosition(offset: 6),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        )
      ]);

      editor.execute([
        InsertTextRequest(
          documentPosition: DocumentPosition(
            nodeId: paragraphId,
            nodePosition: const TextNodePosition(offset: 6),
          ),
          textToInsert: "another",
          attributions: {},
        ),
      ]);

      expect(serializeDocumentToMarkdown(document), "Hello another world");
      expect(
        composer.selection,
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraphId,
            nodePosition: const TextNodePosition(offset: 13),
          ),
        ),
      );

      // Undo the event.
      editor.undo();

      expect(serializeDocumentToMarkdown(document), "Hello  world");
      expect(
        composer.selection,
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraphId,
            nodePosition: const TextNodePosition(offset: 6),
          ),
        ),
      );

      // Redo the event.
      editor.redo();

      expect(serializeDocumentToMarkdown(document), "Hello another world");
      expect(
        composer.selection,
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraphId,
            nodePosition: const TextNodePosition(offset: 13),
          ),
        ),
      );
    });

    testWidgetsOnMac("type by character", (widgetTester) async {
      final editContext = await widgetTester //
          .createDocument()
          .withSingleEmptyParagraph()
          .pump();
      final editor = editContext.editor;

      await widgetTester.placeCaretInParagraph("1", 0);

      // Type characters.
      editor.execute([
        InsertTextRequest(
          documentPosition: const DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 0),
          ),
          textToInsert: "H",
          attributions: {},
        ),
      ]);
      await widgetTester.pump();

      editor.execute([
        InsertTextRequest(
          documentPosition: const DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 1),
          ),
          textToInsert: "e",
          attributions: {},
        ),
      ]);
      await widgetTester.pump();

      editor.execute([
        InsertTextRequest(
          documentPosition: const DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 2),
          ),
          textToInsert: "l",
          attributions: {},
        ),
      ]);
      await widgetTester.pump();

      editor.execute([
        InsertTextRequest(
          documentPosition: const DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 3),
          ),
          textToInsert: "l",
          attributions: {},
        ),
      ]);
      await widgetTester.pump();

      editor.execute([
        InsertTextRequest(
          documentPosition: const DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 4),
          ),
          textToInsert: "o",
          attributions: {},
        ),
      ]);
      await widgetTester.pump();

      expect(SuperEditorInspector.findTextInComponent("1").text, "Hello");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 5),
          ),
        ),
      );

      // Undo the event.
      await widgetTester.pressCmdZ();

      expect(SuperEditorInspector.findTextInComponent("1").text, "Hell");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 4),
          ),
        ),
      );

      await widgetTester.pressCmdZ();
      expect(SuperEditorInspector.findTextInComponent("1").text, "Hel");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 3),
          ),
        ),
      );

      await widgetTester.pressCmdZ();
      expect(SuperEditorInspector.findTextInComponent("1").text, "He");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 2),
          ),
        ),
      );

      await widgetTester.pressCmdZ();
      expect(SuperEditorInspector.findTextInComponent("1").text, "H");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 1),
          ),
        ),
      );

      await widgetTester.pressCmdZ();
      expect(SuperEditorInspector.findTextInComponent("1").text, "");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      print("---------- STARTING REDOS -----------");

      await widgetTester.pressCmdShiftZ();
      _expectDocumentWithCaret("H", "1", 1);

      await widgetTester.pressCmdShiftZ();
      _expectDocumentWithCaret("He", "1", 2);

      await widgetTester.pressCmdShiftZ();
      _expectDocumentWithCaret("Hel", "1", 3);

      await widgetTester.pressCmdShiftZ();
      _expectDocumentWithCaret("Hell", "1", 4);

      await widgetTester.pressCmdShiftZ();
      _expectDocumentWithCaret("Hello", "1", 5);
    });
  });
}

void _expectDocumentWithCaret(String documentContent, String caretNodeId, int caretOffset) {
  expect(serializeDocumentToMarkdown(SuperEditorInspector.findDocument()!), documentContent);
  expect(
    SuperEditorInspector.findDocumentSelection(),
    DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: caretNodeId,
        nodePosition: TextNodePosition(offset: caretOffset),
      ),
    ),
  );
}

extension on WidgetTester {
  Future<void> pressCmdZ() async {
    await sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await sendKeyEvent(LogicalKeyboardKey.keyZ);
    await sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    await pump();
  }

  Future<void> pressCmdShiftZ() async {
    await sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);

    await sendKeyEvent(LogicalKeyboardKey.keyZ);

    await sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    await pump();
  }

  Future<void> pressCtrlZ() async {
    await sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await sendKeyEvent(LogicalKeyboardKey.keyZ);
    await sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    await pump();
  }

  Future<void> pressCtrlShiftZ() async {
    await sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);

    await sendKeyEvent(LogicalKeyboardKey.keyZ);

    await sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    await pump();
  }
}
