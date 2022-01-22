import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';
import 'package:super_editor/super_editor.dart';

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
