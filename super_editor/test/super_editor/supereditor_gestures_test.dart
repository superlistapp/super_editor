import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

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

    testWidgetsOnAllPlatforms('places the caret at the end when tapping beyond the end of the document',
        (tester) async {
      final testContext = await tester
          .createDocument() //
          .fromMarkdown("This is a text")
          .withEditorSize(const Size(300, 300))
          .pump();

      // Tap beyond the end of document with a small margin.
      // As the document has only one line, this offset is after all the content.
      await tester.tapAt(tester.getBottomLeft(find.byType(SuperEditor)) - const Offset(0, 10));
      await tester.pump(kTapMinTime);

      // Ensure selection is at the end of the document.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: testContext.editContext.editor.document.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 14),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms('places the caret at the beginning when tapping above the start of the content',
        (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleParagraph()
          .withEditorSize(const Size(300, 300))
          .pump();

      // Tap above the start of the content a small margin.
      await tester.tapAt(tester.getTopRight(find.byType(SuperEditor)) - const Offset(10, 0));
      await tester.pump(kTapMinTime);

      // Ensure selection is at the beginning of the document.
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

    testWidgetsOnDesktop(
        "dragging a single component selection above a component selects to the beginning of the component",
        (tester) async {
      // For example, a user drags to select text in a paragraph. The user
      // is dragging the cursor up the center of the paragraph. When the cursor
      // moves above the paragraph, the selection extent should move to the
      // beginning of the paragraph, rather than get stuck in the middle of the
      // top line of text.

      await tester
          .createDocument()
          .fromMarkdown(
            '''
This is a paragraph of text that
spans multiple lines.''',
          )
          .forDesktop()
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final paragraphNode = document.nodes.first as ParagraphNode;

      await tester.dragSelectDocumentFromPositionByOffset(
        from: DocumentPosition(
          nodeId: paragraphNode.id,
          nodePosition: paragraphNode.endPosition,
        ),
        delta: const Offset(0, -300),
      );

      // Ensure that the entire paragraph is selected, after dragging
      // above it.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: paragraphNode.endPosition,
          ),
          extent: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: paragraphNode.beginningPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop("dragging a single component selection below a component selects to the end of the component",
        (tester) async {
      // For example, a user drags to select text in a paragraph. The user
      // is dragging the cursor down the center of the paragraph. When the cursor
      // moves below the paragraph, the selection extent should move to the
      // end of the paragraph, rather than get stuck in the middle of the
      // bottom line of text.

      await tester
          .createDocument()
          .fromMarkdown(
            '''
This is a paragraph of text that
spans multiple lines.''',
          )
          .forDesktop()
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final paragraphNode = document.nodes.first as ParagraphNode;

      await tester.dragSelectDocumentFromPositionByOffset(
        from: DocumentPosition(
          nodeId: paragraphNode.id,
          nodePosition: paragraphNode.beginningPosition,
        ),
        delta: const Offset(0, 300),
      );

      // Ensure that the entire paragraph is selected, after dragging
      // below it.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: paragraphNode.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: paragraphNode.endPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop(
        "dragging a multi-component selection above a component selects to the beginning of the top component",
        (tester) async {
      // For example, a user drags to select text in a paragraph. The user
      // is dragging the cursor up the center of the paragraph. When the cursor
      // moves above the paragraph, the selection extent should move to the
      // beginning of the paragraph, rather than get stuck in the middle of the
      // top line of text.

      await tester
          .createDocument()
          .fromMarkdown(
            '''
# This is a test
This is a paragraph of text that
spans multiple lines.''',
          )
          .forDesktop()
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final titleNode = document.nodes.first as ParagraphNode;
      final paragraphNode = document.nodes[1] as ParagraphNode;

      await tester.dragSelectDocumentFromPositionByOffset(
        from: DocumentPosition(
          nodeId: paragraphNode.id,
          nodePosition: paragraphNode.endPosition,
        ),
        delta: const Offset(0, -300),
      );

      // Ensure that the entire paragraph is selected, after dragging
      // above it.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: paragraphNode.endPosition,
          ),
          extent: DocumentPosition(
            nodeId: titleNode.id,
            nodePosition: titleNode.beginningPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop(
        "dragging a multi-component selection below a component selects to the end of the bottom component",
        (tester) async {
      // For example, a user drags to select text in a paragraph. The user
      // is dragging the cursor up the center of the paragraph. When the cursor
      // moves above the paragraph, the selection extent should move to the
      // beginning of the paragraph, rather than get stuck in the middle of the
      // top line of text.

      await tester
          .createDocument()
          .fromMarkdown(
            '''
# This is a test
This is a paragraph of text that
spans multiple lines.''',
          )
          .forDesktop()
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final titleNode = document.nodes.first as ParagraphNode;
      final paragraphNode = document.nodes[1] as ParagraphNode;

      await tester.dragSelectDocumentFromPositionByOffset(
        from: DocumentPosition(
          nodeId: titleNode.id,
          nodePosition: titleNode.beginningPosition,
        ),
        delta: const Offset(0, 300),
      );

      // Ensure that the entire paragraph is selected, after dragging
      // above it.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: titleNode.id,
            nodePosition: titleNode.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: paragraphNode.endPosition,
          ),
        ),
      );
    });
  });
}
