import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/document_interaction.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '../_document_test_tools.dart';
import '../_text_entry_test_tools.dart';

void main() {
  group('text.dart', () {
    group('ToggleTextAttributionsCommand', () {
      test('it toggles selected text and nothing more', () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'paragraph',
              text: AttributedText(text: ' make me bold '),
            )
          ],
        );
        final editor = DocumentEditor(document: document);

        final command = ToggleTextAttributionsCommand(
          documentSelection: DocumentSelection(
            base: DocumentPosition(
              nodeId: 'paragraph',
              nodePosition: TextPosition(offset: 1),
            ),
            extent: DocumentPosition(
              nodeId: 'paragraph',
              // IMPORTANT: we want to end the bold at the 'd' character but
              // the TextPosition indexes the ' ' after the 'd'. This is because
              // TextPosition references the character after the selection, not
              // the last character in the selection. See the TextPosition class
              // definition for more information.
              nodePosition: TextPosition(offset: 13),
            ),
          ),
          attributions: {boldAttribution},
        );

        editor.executeCommand(command);

        final boldedText = (document.nodes.first as ParagraphNode).text;
        expect(boldedText.getAllAttributionsAt(0), <dynamic>{});
        expect(boldedText.getAllAttributionsAt(1), {boldAttribution});
        expect(boldedText.getAllAttributionsAt(12), {boldAttribution});
        expect(boldedText.getAllAttributionsAt(13), <dynamic>{});
      });
    });

    group('TextComposable text entry', () {
      test('it does nothing when meta is pressed', () {
        final editContext = _createEditContext();

        // Press just the meta key.
        var result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.meta,
              physicalKey: PhysicalKeyboardKey.metaLeft,
              isMetaPressed: true,
              isModifierKeyPressed: false,
            ),
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);

        // Press "a" + meta key
        result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.keyA,
              physicalKey: PhysicalKeyboardKey.keyA,
              isMetaPressed: true,
              isModifierKeyPressed: false,
            ),
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);
      });

      test('it does nothing when nothing is selected', () {
        final editContext = _createEditContext();

        // Try to type a character.
        var result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.keyA,
              physicalKey: PhysicalKeyboardKey.keyA,
            ),
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);
      });

      test('it does nothing when the selection is not collapsed', () {
        final editContext = _createEditContext();

        // Add a paragraph to the document.
        (editContext.editor.document as MutableDocument).nodes.add(
              ParagraphNode(
                id: 'paragraph',
                text: AttributedText(text: 'This is some text'),
              ),
            );

        // Select multiple characters in the paragraph
        editContext.composer.selection = DocumentSelection(
          base: DocumentPosition(
            nodeId: 'paragraph',
            nodePosition: TextPosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: 'paragraph',
            nodePosition: TextPosition(offset: 1),
          ),
        );

        // Try to type a character.
        var result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.keyA,
              physicalKey: PhysicalKeyboardKey.keyA,
            ),
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);
      });

      test('it does nothing when a non-text node is selected', () {
        final editContext = _createEditContext();

        // Add a non-text node to the document.
        (editContext.editor.document as MutableDocument).nodes.add(
              HorizontalRuleNode(id: 'horizontal_rule'),
            );

        // Select the horizontal rule node.
        editContext.composer.selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'horizontal_rule',
            nodePosition: BinaryPosition.notIncluded(),
          ),
        );

        // Try to type a character.
        var result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.keyA,
              physicalKey: PhysicalKeyboardKey.keyA,
            ),
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);
      });

      test('it does nothing when the key doesn\'t have a character', () {
        final editContext = _createEditContext();

        // Add a paragraph to the document.
        (editContext.editor.document as MutableDocument).nodes.add(
              ParagraphNode(
                id: 'paragraph',
                text: AttributedText(text: 'This is some text'),
              ),
            );

        // Select multiple characters in the paragraph
        editContext.composer.selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'paragraph',
            nodePosition: TextPosition(offset: 0),
          ),
        );

        // Press the "alt" key
        var result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            character: null,
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.alt,
              physicalKey: PhysicalKeyboardKey.altLeft,
              isModifierKeyPressed: true,
            ),
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);

        // Press the "enter" key
        result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            character: '', // Empirically, pressing enter sends '' as the character instead of null
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.enter,
              physicalKey: PhysicalKeyboardKey.enter,
            ),
          ),
        );

        // The handler should pass on handling the key.
        expect(result, ExecutionInstruction.continueExecution);
      });

      test('it inserts an English character', () {
        final editContext = _createEditContext();

        // Add a paragraph to the document.
        (editContext.editor.document as MutableDocument).nodes.add(
              ParagraphNode(
                id: 'paragraph',
                text: AttributedText(text: 'This is some text'),
              ),
            );

        // Select multiple characters in the paragraph
        editContext.composer.selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'paragraph',
            nodePosition: TextPosition(offset: 0),
          ),
        );

        // Press the "a" key
        var result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            character: 'a',
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.keyA,
              physicalKey: PhysicalKeyboardKey.keyA,
            ),
          ),
        );

        // The handler should insert a character
        expect(result, ExecutionInstruction.haltExecution);
        expect(
          (editContext.editor.document.nodes.first as TextNode).text.text,
          'aThis is some text',
        );
      });

      test('it inserts a non-English character', () {
        final editContext = _createEditContext();

        // Add a paragraph to the document.
        (editContext.editor.document as MutableDocument).nodes.add(
              ParagraphNode(
                id: 'paragraph',
                text: AttributedText(text: 'This is some text'),
              ),
            );

        // Select multiple characters in the paragraph
        editContext.composer.selection = DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'paragraph',
            nodePosition: TextPosition(offset: 0),
          ),
        );

        // Type a non-English character
        var result = insertCharacterInTextComposable(
          editContext: editContext,
          keyEvent: FakeRawKeyEvent(
            character: 'ß',
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.keyA,
              physicalKey: PhysicalKeyboardKey.keyA,
            ),
          ),
        );

        // The handler should insert a character
        expect(result, ExecutionInstruction.haltExecution);
        expect(
          (editContext.editor.document.nodes.first as TextNode).text.text,
          'ßThis is some text',
        );
      });
    });
  });
}

EditContext _createEditContext() {
  final document = MutableDocument();
  final documentEditor = DocumentEditor(document: document);
  final fakeLayout = FakeDocumentLayout();
  final composer = DocumentComposer();
  return EditContext(
    editor: documentEditor,
    getDocumentLayout: () => fakeLayout,
    composer: composer,
    commonOps: CommonEditorOperations(
      editor: documentEditor,
      composer: composer,
      documentLayoutResolver: () => fakeLayout,
    ),
  );
}
