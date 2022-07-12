import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';
import 'supereditor_inspector.dart';

void main() {
  group('SuperEditor gestures', () {
    testWidgetsOnAllPlatforms('places the caret when tapping an empty document (top left)', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withEditorSize(const Size(300, 300))
          .pump();

      // Ensure editor is not focused
      expect(SuperEditorInspector.hasFocus(), isFalse);

      // Tap inside SuperEditor
      await tester.tapAt(tester.getTopLeft(find.byType(SuperEditor)) + const Offset(1, 1));
      await tester.pump(kTapMinTime);

      // Ensure editor is focused
      expect(SuperEditorInspector.hasFocus(), isTrue);

      // Ensure selection is at the beginning of the document
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: testContext.editContext.editor.document.nodes.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms('places the caret when tapping an empty document (top right)', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withEditorSize(const Size(300, 300))
          .pump();

      // Ensure editor is not focused
      expect(SuperEditorInspector.hasFocus(), isFalse);

      // Tap inside SuperEditor
      await tester.tapAt(tester.getTopRight(find.byType(SuperEditor)) + const Offset(-1, 1));
      await tester.pump(kTapMinTime);

      // Ensure editor is focused
      expect(SuperEditorInspector.hasFocus(), isTrue);

      // Ensure selection is at the beginning of the document
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: testContext.editContext.editor.document.nodes.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms('places the caret when tapping an empty document (bottom left)', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withEditorSize(const Size(300, 300))
          .pump();

      // Ensure editor is not focused
      expect(SuperEditorInspector.hasFocus(), isFalse);

      // Tap inside SuperEditor
      await tester.tapAt(tester.getBottomLeft(find.byType(SuperEditor)) + const Offset(1, -1));
      await tester.pump(kTapMinTime);

      // Ensure editor is focused
      expect(SuperEditorInspector.hasFocus(), isTrue);

      // Ensure selection is at the beginning of the document
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: testContext.editContext.editor.document.nodes.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms('places the caret when tapping an empty document (bottom right)', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withEditorSize(const Size(300, 300))
          .pump();

      // Ensure editor is not focused
      expect(SuperEditorInspector.hasFocus(), isFalse);

      // Tap inside SuperEditor
      await tester.tapAt(tester.getBottomRight(find.byType(SuperEditor)) - const Offset(1, 1));
      await tester.pump(kTapMinTime);

      // Ensure editor is focused
      expect(SuperEditorInspector.hasFocus(), isTrue);

      // Ensure selection is at the beginning of the document
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: testContext.editContext.editor.document.nodes.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms('places the caret when tapping an empty document (center)', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withEditorSize(const Size(300, 300))
          .pump();

      // Ensure editor is not focused
      expect(SuperEditorInspector.hasFocus(), isFalse);

      // Tap inside SuperEditor
      await tester.tapAt(tester.getCenter(find.byType(SuperEditor)));
      await tester.pump(kTapMinTime);

      // Ensure editor is focused
      expect(SuperEditorInspector.hasFocus(), isTrue);

      // Ensure selection is at the beginning of the document
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: testContext.editContext.editor.document.nodes.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });
  });
}
