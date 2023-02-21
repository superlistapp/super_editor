import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';

import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    group('inserts an image', () {
      testWidgetsOnAllPlatforms('when the selection sits at the beginning of a non-empty paragraph', (tester) async {
        // Pump a widget with an arbitrary size for the images.
        final context = await tester //
            .createDocument()
            .fromMarkdown("First paragraph")
            .withAddedComponents(
          [const FakeImageComponentBuilder(size: Size(100, 100))],
        ).pump();

        // Place caret at the beginning of the paragraph.
        await tester.placeCaretInParagraph(context.editContext.editor.document.nodes.first.id, 0);

        // Insert the image at the current selection.
        context.editContext.commonOps.insertImage('http://image.fake');
        await tester.pumpAndSettle();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that one node was inserted.
        expect(doc.nodes.length, 2);

        // Ensure that the image was added.
        expect(doc.nodes[0], isA<ImageNode>());

        // Ensure that the paragraph node content remains unchanged, but is moved down.
        expect(doc.nodes[1], isA<ParagraphNode>());
        expect((doc.nodes[1] as ParagraphNode).text.text, 'First paragraph');

        // Ensure the selection was placed at the beginning of the paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes[1].id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });
      testWidgetsOnAllPlatforms('when the selection sits at the middle of a paragraph', (tester) async {
        // Pump a widget with an arbitrary size for the images.
        final context = await tester //
            .createDocument()
            .fromMarkdown("Before the image after the image")
            .withAddedComponents(
          [const FakeImageComponentBuilder(size: Size(100, 100))],
        ).pump();

        // Place caret at "Before the image| after the image".
        await tester.placeCaretInParagraph(context.editContext.editor.document.nodes.first.id, 16);

        // Insert the image at the current selection.
        context.editContext.commonOps.insertImage('http://image.fake');
        await tester.pump();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that two nodes were inserted.
        expect(doc.nodes.length, 3);

        // Ensure that the first node has the text from before the caret.
        expect(doc.nodes[0], isA<ParagraphNode>());
        expect((doc.nodes[0] as ParagraphNode).text.text, 'Before the image');

        // Ensure that the image was added.
        expect(doc.nodes[1], isA<ImageNode>());

        // Ensure that the last node has the text from after the caret.
        expect(doc.nodes[2], isA<ParagraphNode>());
        expect((doc.nodes[2] as ParagraphNode).text.text, ' after the image');

        // Ensure the selection was placed at the beginning of the last paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms('when the selection sits at the end of a paragraph', (tester) async {
        // Pump a widget with an arbitrary size for the images.
        final context = await tester //
            .createDocument()
            .fromMarkdown("First paragraph")
            .withAddedComponents(
          [const FakeImageComponentBuilder(size: Size(100, 100))],
        ).pump();

        // Place caret at the end of the paragraph.
        await tester.placeCaretInParagraph(context.editContext.editor.document.nodes.first.id, 15);

        // Insert the image at the current selection.
        context.editContext.commonOps.insertImage('http://image.fake');
        await tester.pumpAndSettle();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that two nodes were inserted.
        expect(doc.nodes.length, 3);

        // Ensure that the first node remains unchanged.
        expect(doc.nodes[0], isA<ParagraphNode>());
        expect((doc.nodes[0] as ParagraphNode).text.text, 'First paragraph');

        // Ensure that the image was added.
        expect(doc.nodes[1], isA<ImageNode>());

        // Ensure that an empty node was added after the image.
        expect(doc.nodes[2], isA<ParagraphNode>());
        expect((doc.nodes[2] as ParagraphNode).text.text, '');

        // Ensure the selection was placed at the beginning of the last paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms('when the selection sits at an empty paragraph', (tester) async {
        // Pump a widget with an arbitrary size for the images.
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withAddedComponents(
          [const FakeImageComponentBuilder(size: Size(100, 100))],
        ).pump();

        // Place caret at the empty paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Insert the image at the current selection.
        context.editContext.commonOps.insertImage('http://image.fake');
        await tester.pumpAndSettle();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that one node was inserted.
        expect(doc.nodes.length, 2);

        // Ensure that the paragraph was converted to an image.
        expect(doc.nodes.first, isA<ImageNode>());

        // Ensure that an empty node was added after the image.
        expect(doc.nodes[1], isA<ParagraphNode>());
        expect((doc.nodes[1] as ParagraphNode).text.text, '');

        // Ensure the selection was placed at the empty paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes[1].id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });
    });

    group('inserts a horizontal rule', () {
      testWidgetsOnAllPlatforms('when the selection sits at the beginning of a non-empty paragraph', (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("First paragraph")
            .pump();

        // Place caret at the beginning of the paragraph.
        await tester.placeCaretInParagraph(context.editContext.editor.document.nodes.first.id, 0);

        // Insert the horizontal rule at the current selection.
        context.editContext.commonOps.insertHorizontalRule();
        await tester.pumpAndSettle();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that one node was inserted.
        expect(doc.nodes.length, 2);

        // Ensure that the horizontal rule was added.
        expect(doc.nodes[0], isA<HorizontalRuleNode>());

        // Ensure that the paragraph node content remains unchanged, but is moved down.
        expect(doc.nodes[1], isA<ParagraphNode>());
        expect((doc.nodes[1] as ParagraphNode).text.text, 'First paragraph');

        // Ensure the selection was placed at the beginning of the paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes[1].id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });
      testWidgetsOnAllPlatforms('when the selection sits at the middle of a paragraph', (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("Before the hr after the hr")
            .pump();

        // Place caret at "Before the hr| after the hr".
        await tester.placeCaretInParagraph(context.editContext.editor.document.nodes.first.id, 13);

        // Insert the horizontal rule at the current selection.
        context.editContext.commonOps.insertHorizontalRule();
        await tester.pumpAndSettle();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that two nodes were inserted.
        expect(doc.nodes.length, 3);

        // Ensure that the first node has the text from before the caret.
        expect(doc.nodes[0], isA<ParagraphNode>());
        expect((doc.nodes[0] as ParagraphNode).text.text, 'Before the hr');

        // Ensure that the horizontal rule was added.
        expect(doc.nodes[1], isA<HorizontalRuleNode>());

        // Ensure that the last node has the text from after the caret.
        expect(doc.nodes[2], isA<ParagraphNode>());
        expect((doc.nodes[2] as ParagraphNode).text.text, ' after the hr');

        // Ensure the selection was placed at the beginning of the last paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms('when the selection sits at the end of a paragraph', (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("First paragraph")
            .pump();

        // Place caret at the end of the paragraph.
        await tester.placeCaretInParagraph(context.editContext.editor.document.nodes.first.id, 15);

        // Insert the horizontal rule at the current selection.
        context.editContext.commonOps.insertHorizontalRule();
        await tester.pumpAndSettle();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that two nodes were inserted.
        expect(doc.nodes.length, 3);

        // Ensure that the first node remains unchanged.
        expect(doc.nodes[0], isA<ParagraphNode>());
        expect((doc.nodes[0] as ParagraphNode).text.text, 'First paragraph');

        // Ensure that the horizontal rule was added.
        expect(doc.nodes[1], isA<HorizontalRuleNode>());

        // Ensure that an empty node was added at the end.
        expect(doc.nodes[2], isA<ParagraphNode>());
        expect((doc.nodes[2] as ParagraphNode).text.text, '');

        // Ensure the selection was placed at the beginning of the last paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms('when the selection sits at an empty paragraph', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .pump();

        // Place caret at the empty paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Insert the horizontal rule at the current selection.
        context.editContext.commonOps.insertHorizontalRule();
        await tester.pumpAndSettle();

        final doc = SuperEditorInspector.findDocument()!;

        // Ensure that one node was inserted.
        expect(doc.nodes.length, 2);

        // Ensure the paragraph was converted to a horizontal rule.
        expect(doc.nodes.first, isA<HorizontalRuleNode>());

        // Ensure that an empty node was added after the horizontal rule.
        expect(doc.nodes[1], isA<ParagraphNode>());
        expect((doc.nodes[1] as ParagraphNode).text.text, '');

        // Ensure that the selection was placed at the empty paragraph.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: doc.nodes[1].id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });
    });
  });
}
