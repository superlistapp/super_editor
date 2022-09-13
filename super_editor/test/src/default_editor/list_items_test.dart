import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../super_editor/document_test_tools.dart';
import '../../test_tools.dart';
import '../_document_test_tools.dart';
import '../_text_entry_test_tools.dart';
import '../infrastructure/_platform_test_tools.dart';

void main() {
  group('List items', () {
    group('node conversion', () {
      test('converts paragraph with "1. " to ordered list item', () {
        Platform.setTestInstance(MacPlatform());

        final _editContext = _createEditContextWithParagraph();

        _typeKeys(_editContext, [
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.numpad1,
              physicalKey: PhysicalKeyboardKey.numpad1,
            ),
            character: '1',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.period,
              physicalKey: PhysicalKeyboardKey.period,
            ),
            character: '.',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
        ]);

        final listItemNode = _editContext.editor.document.nodes.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).text.text.isEmpty, isTrue);

        Platform.setTestInstance(null);
      });

      test('converts paragraph with " 1. " to ordered list item', () {
        Platform.setTestInstance(MacPlatform());

        final _editContext = _createEditContextWithParagraph();

        _typeKeys(_editContext, [
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.numpad1,
              physicalKey: PhysicalKeyboardKey.numpad1,
            ),
            character: '1',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.period,
              physicalKey: PhysicalKeyboardKey.period,
            ),
            character: '.',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
        ]);

        final listItemNode = _editContext.editor.document.nodes.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).text.text.isEmpty, isTrue);

        Platform.setTestInstance(null);
      });

      test('converts paragraph with "1) " to ordered list item', () {
        Platform.setTestInstance(MacPlatform());

        final _editContext = _createEditContextWithParagraph();

        _typeKeys(_editContext, [
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.numpad1,
              physicalKey: PhysicalKeyboardKey.numpad1,
            ),
            character: '1',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.parenthesisRight,
              physicalKey: PhysicalKeyboardKey.digit0,
            ),
            character: ')',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
        ]);

        final listItemNode = _editContext.editor.document.nodes.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).text.text.isEmpty, isTrue);

        Platform.setTestInstance(null);
      });

      test('converts paragraph with " 1) " to ordered list item', () {
        Platform.setTestInstance(MacPlatform());

        final _editContext = _createEditContextWithParagraph();

        _typeKeys(_editContext, [
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.numpad1,
              physicalKey: PhysicalKeyboardKey.numpad1,
            ),
            character: '1',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.parenthesisRight,
              physicalKey: PhysicalKeyboardKey.digit0,
            ),
            character: ')',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
        ]);

        final listItemNode = _editContext.editor.document.nodes.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).text.text.isEmpty, isTrue);

        Platform.setTestInstance(null);
      });

      test('does not convert paragraph with "1 " to ordered list item', () {
        Platform.setTestInstance(MacPlatform());

        final _editContext = _createEditContextWithParagraph();

        _typeKeys(_editContext, [
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.numpad1,
              physicalKey: PhysicalKeyboardKey.numpad1,
            ),
            character: '1',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
        ]);

        final paragraphNode = _editContext.editor.document.nodes.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.text, "1 ");

        Platform.setTestInstance(null);
      });

      test('does not convert paragraph with " 1 " to ordered list item', () {
        Platform.setTestInstance(MacPlatform());

        final _editContext = _createEditContextWithParagraph();

        _typeKeys(_editContext, [
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.numpad1,
              physicalKey: PhysicalKeyboardKey.numpad1,
            ),
            character: '1',
          ),
          const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.space,
              physicalKey: PhysicalKeyboardKey.space,
            ),
            character: ' ',
          ),
        ]);

        final paragraphNode = _editContext.editor.document.nodes.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.text, " 1 ");

        Platform.setTestInstance(null);
      });
    });

    group('unordered list', () {
      testWidgetsOnArbitraryDesktop('updates caret position when indenting', (tester) async {
        await _pumpUnorderedList(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemId = doc.nodes.first.id;

        // Place caret at the first list item, which has one level of indentation.
        await tester.placeCaretInParagraph(listItemId, 0);

        final caretOffsetBeforeIndent = SuperEditorInspector.findCaretOffsetInDocument();

        // Press tab to trigger the list indent command.
        await tester.pressTab();

        // Compute the offset at which the caret should be displayed.
        final computedOffsetAfterIndent = SuperEditorInspector.calculateOffsetForCaret(
          DocumentPosition(
            nodeId: listItemId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        );

        // Ensure the list indentation was actually performed.
        expect(computedOffsetAfterIndent.dx, greaterThan(caretOffsetBeforeIndent.dx));

        // Ensure the caret is being displayed at the correct position.
        expect(SuperEditorInspector.findCaretOffsetInDocument(), offsetMoreOrLessEquals(computedOffsetAfterIndent));
      });

      testWidgetsOnArbitraryDesktop('updates caret position when unindenting', (tester) async {
        await _pumpUnorderedList(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemId = doc.nodes.last.id;

        // Place caret at the last list item, which has two levels of indentation.
        // For some reason, taping at the first character isn't displaying any caret,
        // so we put the caret at the second character and then go back one position.
        await tester.placeCaretInParagraph(listItemId, 1);
        await tester.pressLeftArrow();

        final caretOffsetBeforeUnindent = SuperEditorInspector.findCaretOffsetInDocument();

        // Press backspace to trigger the list unindent command.
        await tester.pressBackspace();

        // Compute the offset at which the caret should be displayed.
        final computedOffsetAfterUnindent = SuperEditorInspector.calculateOffsetForCaret(
          DocumentPosition(
            nodeId: listItemId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        );

        // Ensure the list indentation was actually performed.
        expect(computedOffsetAfterUnindent.dx, lessThan(caretOffsetBeforeUnindent.dx));

        // Ensure the caret is being displayed at the correct position.
        expect(SuperEditorInspector.findCaretOffsetInDocument(), offsetMoreOrLessEquals(computedOffsetAfterUnindent));
      });
    });

    group('ordered list', () {
      testWidgetsOnArbitraryDesktop('updates caret position when indenting', (tester) async {
        await _pumpOrderedList(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemId = doc.nodes.first.id;

        // Place caret at the first list item, which has one level of indentation.
        await tester.placeCaretInParagraph(listItemId, 0);

        final caretOffsetBeforeIndent = SuperEditorInspector.findCaretOffsetInDocument();

        // Press tab to trigger the list indent command.
        await tester.pressTab();

        // Compute the offset at which the caret should be displayed.
        final computedOffsetAfterIndent = SuperEditorInspector.calculateOffsetForCaret(
          DocumentPosition(
            nodeId: listItemId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        );

        // Ensure the list indentation was actually performed.
        expect(computedOffsetAfterIndent.dx, greaterThan(caretOffsetBeforeIndent.dx));

        // Ensure the caret is being displayed at the correct position.
        expect(SuperEditorInspector.findCaretOffsetInDocument(), offsetMoreOrLessEquals(computedOffsetAfterIndent));
      });

      testWidgetsOnArbitraryDesktop('updates caret position when unindenting', (tester) async {
        await _pumpOrderedList(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemId = doc.nodes.last.id;

        // Place caret at the last list item, which has two levels of indentation.
        // For some reason, taping at the first character isn't displaying any caret,
        // so we put the caret at the second character and then go back one position.
        await tester.placeCaretInParagraph(listItemId, 1);
        await tester.pressLeftArrow();

        final caretOffsetBeforeUnindent = SuperEditorInspector.findCaretOffsetInDocument();

        // Press backspace to trigger the list unindent command.
        await tester.pressBackspace();

        // Compute the offset at which the caret should be displayed.
        final computedOffsetAfterUnindent = SuperEditorInspector.calculateOffsetForCaret(DocumentPosition(
          nodeId: listItemId,
          nodePosition: const TextNodePosition(offset: 0),
        ));

        // Ensure the list indentation was actually performed.
        expect(computedOffsetAfterUnindent.dx, lessThan(caretOffsetBeforeUnindent.dx));

        // Ensure the caret is being displayed at the correct position.
        expect(SuperEditorInspector.findCaretOffsetInDocument(), offsetMoreOrLessEquals(computedOffsetAfterUnindent));
      });
    });
  });
}

EditContext _createEditContextWithParagraph() {
  return createEditContext(
    document: MutableDocument(
      nodes: [
        ParagraphNode(
          id: 'paragraph',
          text: AttributedText(text: ''),
        ),
      ],
    ),
    documentComposer: DocumentComposer(
      initialSelection: const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: 'paragraph',
          nodePosition: TextNodePosition(offset: 0),
        ),
      ),
    ),
  );
}

void _typeKeys(EditContext editContext, List<FakeRawKeyEvent> keys) {
  for (final key in keys) {
    anyCharacterToInsertInParagraph(
      editContext: editContext,
      keyEvent: key,
    );
  }
}

/// Pumps a [SuperEditor] containing 3 unordered list items.
///
/// The first two items have one level of indentation.
///
/// The last two items have two levels of indentation.
Future<void> _pumpUnorderedList(WidgetTester tester) async {
  const markdown = '''
 * list item 1
 * list item 2
   * list item 2.1
   * list item 2.2''';

  await tester //
      .createDocument()
      .fromMarkdown(markdown)
      .pump();
}

/// Pumps a [SuperEditor] containing 4 ordered list items.
///
/// The first two items have one level of indentation.
///
/// The last two items have two levels of indentation.
Future<void> _pumpOrderedList(WidgetTester tester) async {
  const markdown = '''
 1. list item 1
 1. list item 2
    1. list item 2.1
    1. list item 2.2''';

  await tester //
      .createDocument()
      .fromMarkdown(markdown)
      .pump();
}
