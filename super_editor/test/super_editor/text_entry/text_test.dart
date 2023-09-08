import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../test_tools_user_input.dart';
import '../supereditor_test_tools.dart';

void main() {
  group('text.dart', () {
    group('ToggleTextAttributionsCommand', () {
      test('it toggles selected text and nothing more', () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'paragraph',
              text: AttributedText(' make me bold '),
            )
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(document: document, composer: composer);

        final request = ToggleTextAttributionsRequest(
          documentRange: const DocumentSelection(
            base: DocumentPosition(
              nodeId: 'paragraph',
              nodePosition: TextNodePosition(offset: 1),
            ),
            extent: DocumentPosition(
              nodeId: 'paragraph',
              // IMPORTANT: we want to end the bold at the 'd' character but
              // the TextPosition indexes the ' ' after the 'd'. This is because
              // TextPosition references the character after the selection, not
              // the last character in the selection. See the TextPosition class
              // definition for more information.
              nodePosition: TextNodePosition(offset: 13),
            ),
          ),
          attributions: {boldAttribution},
        );

        editor.execute([request]);

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
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
        result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
        (editContext.document as MutableDocument).add(
          ParagraphNode(
            id: 'paragraph',
            text: AttributedText('This is some text'),
          ),
        );

        // Select multiple characters in the paragraph
        editContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'paragraph',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: 'paragraph',
                nodePosition: TextNodePosition(offset: 1),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          ),
        ]);

        // Try to type a character.
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
        (editContext.document as MutableDocument).add(
          HorizontalRuleNode(id: 'horizontal_rule'),
        );

        // Select the horizontal rule node.
        editContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: 'horizontal_rule',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Try to type a character.
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
        (editContext.document as MutableDocument).add(
          ParagraphNode(
            id: 'paragraph',
            text: AttributedText('This is some text'),
          ),
        );

        // Select multiple characters in the paragraph
        editContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: 'paragraph',
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Press the "alt" key
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
        result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
        (editContext.document as MutableDocument).add(
          ParagraphNode(
            id: 'paragraph',
            text: AttributedText('This is some text'),
          ),
        );

        // Select multiple characters in the paragraph
        editContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: 'paragraph',
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Press the "a" key
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
          (editContext.document.nodes.first as TextNode).text.text,
          'aThis is some text',
        );
      });

      test('it inserts a non-English character', () {
        final editContext = _createEditContext();

        // Add a paragraph to the document.
        (editContext.document as MutableDocument).add(
          ParagraphNode(
            id: 'paragraph',
            text: AttributedText('This is some text'),
          ),
        );

        // Select multiple characters in the paragraph
        editContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: 'paragraph',
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);

        // Type a non-English character
        var result = anyCharacterToInsertInTextContent(
          editContext: editContext,
          keyEvent: const FakeRawKeyDownEvent(
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
          (editContext.document.nodes.first as TextNode).text.text,
          'ßThis is some text',
        );
      });
    });

    group('TextNode', () {
      group('computeSelection', () {
        test('throws if passed other types of NodePosition', () {
          final node = TextNode(
            id: 'text node',
            text: AttributedText('text'),
          );
          expect(
            () => node.computeSelection(
              base: const UpstreamDownstreamNodePosition.upstream(),
              extent: const UpstreamDownstreamNodePosition.downstream(),
            ),
            throwsAssertionError,
          );
        });

        test('preserves the affinity of extent', () {
          final node = TextNode(
            id: 'text node',
            text: AttributedText('text'),
          );

          final selectionWithUpstream = node.computeSelection(
            base: const TextNodePosition(
              offset: 0,
              affinity: TextAffinity.downstream,
            ),
            extent: const TextNodePosition(
              offset: 3,
              affinity: TextAffinity.upstream,
            ),
          );
          expect(selectionWithUpstream.affinity, TextAffinity.upstream);

          final selectionWithDownstream = node.computeSelection(
            base: const TextNodePosition(
              offset: 0,
              affinity: TextAffinity.upstream,
            ),
            extent: const TextNodePosition(
              offset: 3,
              affinity: TextAffinity.downstream,
            ),
          );
          expect(selectionWithDownstream.affinity, TextAffinity.downstream);
        });
      });
    });

    group('TextNodeSelection', () {
      group('get base', () {
        test('preserves affinity', () {
          const selectionWithUpstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.upstream);
          expect(selectionWithUpstream.base.affinity, TextAffinity.upstream);

          const selectionWithDownstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.downstream);
          expect(selectionWithDownstream.base.affinity, TextAffinity.downstream);
        });
      });

      group('get extent', () {
        test('preserves affinity', () {
          const selectionWithUpstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.upstream);
          expect(selectionWithUpstream.extent.affinity, TextAffinity.upstream);

          const selectionWithDownstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.downstream);
          expect(selectionWithDownstream.extent.affinity, TextAffinity.downstream);
        });
      });
    });
  });
}

SuperEditorContext _createEditContext() {
  final document = MutableDocument();
  final composer = MutableDocumentComposer();
  final documentEditor = createDefaultDocumentEditor(document: document, composer: composer);
  final fakeLayout = FakeDocumentLayout();
  return SuperEditorContext(
    editor: documentEditor,
    document: document,
    getDocumentLayout: () => fakeLayout,
    composer: composer,
    scroller: FakeSuperEditorScroller(),
    hasPrimaryFocus: ValueNotifier(false),
    commonOps: CommonEditorOperations(
      editor: documentEditor,
      document: document,
      composer: composer,
      documentLayoutResolver: () => fakeLayout,
    ),
  );
}
