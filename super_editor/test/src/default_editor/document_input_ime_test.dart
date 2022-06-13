import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

import '../_document_test_tools.dart';
import '../../super_editor/test_documents.dart';

void main() {
  group('IME input', () {
    group('delta use-cases', () {
      test('can handle an auto-inserted period', () {
        // On iOS, adding 2 spaces causes the two spaces to be replaced by a
        // period and a space. This test applies the same type and order of deltas
        // that were observed on iOS.
        //
        // Previously, we had a bug where the period was appearing after the
        // 2nd space, instead of between the two spaces. This test prevents
        // that regression.
        final document = MutableDocument(nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText(text: "This is a sentence"),
          ),
        ]);
        final editor = DocumentEditor(document: document);
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 18),
            ),
          ),
        );
        final commonOps = CommonEditorOperations(
          editor: editor,
          composer: composer,
          documentLayoutResolver: () => FakeDocumentLayout(),
        );
        final softwareKeyboardHandler = SoftwareKeyboardHandler(
          editor: editor,
          composer: composer,
          commonOps: commonOps,
        );

        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaInsertion(
            textInserted: ' ',
            insertionOffset: 18,
            selection: TextSelection.collapsed(offset: 19),
            composing: TextRange(start: -1, end: -1),
            oldText: 'This is a sentence',
          ),
        ]);
        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'This is a sentence ',
            replacementText: '.',
            replacedRange: TextRange(start: 18, end: 19),
            selection: TextSelection.collapsed(offset: 19),
            composing: TextRange(start: -1, end: -1),
          ),
        ]);
        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaInsertion(
            textInserted: ' ',
            insertionOffset: 19,
            selection: TextSelection.collapsed(offset: 20),
            composing: TextRange(start: -1, end: -1),
            oldText: 'This is a sentence.',
          ),
        ]);

        expect((document.nodes.first as ParagraphNode).text.text, "This is a sentence. ");
      });

      testWidgets('can type compound character in an empty paragraph', (tester) async {
        // Inserting special characters, or compound characters, like ü, requires
        // multiple key presses, which are combined by the IME, based on the
        // composing region.
        //
        // A blank paragraph is serialized with a leading ". " to trick IMEs into
        // auto-capitalizing the first character the user types, while still reporting
        // a `backspace` operation, if the user presses backspace on a software keyboard.
        //
        // This test ensures that when we go from an empty paragraph with a hidden ". ", to
        // a character with a composing region, like "¨", we report the correct composing region.
        // For example, due to our hidden ". ", when the user enters a "¨", the IME thinks
        // the composing region is [2,3], like ". ¨", but the text is actually "¨", so we
        // need to adjust the composing region to [0,1].
        final editContext = createEditContext(
          // Use a two-paragraph document so that the selection in the 2nd
          // paragraph sends a hidden placeholder to the IME for backspace.
          document: twoParagraphEmptyDoc(),
          documentComposer: DocumentComposer(
            initialSelection: const DocumentSelection.collapsed(
              position: DocumentPosition(
                // Start the caret in the 2nd paragraph so that we send a
                // hidden placeholder to the IME to report backspaces.
                nodeId: "2",
                nodePosition: TextNodePosition(
                  offset: 0,
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: editContext.editor,
                composer: editContext.composer,
                inputSource: DocumentInputSource.ime,
                gestureMode: DocumentGestureMode.mouse,
                autofocus: true,
              ),
            ),
          ),
        );

        // Send the deltas that should produce a ü.
        //
        // We have to use implementation details to send the simulated IME deltas
        // because Flutter doesn't have any testing tools for IME deltas.
        final imeInteractor = find.byType(DocumentImeInteractor).evaluate().first;
        final deltaClient = (imeInteractor as StatefulElement).state as DeltaTextInputClient;

        // Ensure that the delta client starts with the expected invisible placeholder
        // characters.
        expect(deltaClient.currentTextEditingValue!.text, ". ");
        expect(deltaClient.currentTextEditingValue!.selection, const TextSelection.collapsed(offset: 2));
        expect(deltaClient.currentTextEditingValue!.composing, const TextRange(start: -1, end: -1));

        // Insert the "opt+u" character.
        deltaClient.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: ". ",
            textInserted: "¨",
            insertionOffset: 2,
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 2, end: 3),
          ),
        ]);

        // Ensure that the empty paragraph now reads "¨".
        expect((editContext.editor.document.nodes[1] as ParagraphNode).text.text, "¨");

        // Ensure that the reported composing region respects the removal of the
        // invisible placeholder characters. THIS IS WHERE THE ORIGINAL BUG HAPPENED.
        expect(deltaClient.currentTextEditingValue!.text, "¨");
        expect(deltaClient.currentTextEditingValue!.composing, const TextRange(start: 0, end: 1));

        // Insert the "u" character to create the compound character.
        deltaClient.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: "¨",
            replacementText: "ü",
            replacedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: -1, end: -1),
          ),
        ]);

        // Ensure that the empty paragraph now reads "ü".
        expect((editContext.editor.document.nodes[1] as ParagraphNode).text.text, "ü");
      });
    });

    group('text serialization and selected content', () {
      test('within a single node is reported as a TextEditingValue', () {
        const text = "This is a paragraph of text.";

        _expectTextEditingValue(
          actualTextEditingValue: DocumentImeSerializer(
            MutableDocument(nodes: [
              ParagraphNode(id: "1", text: AttributedText(text: text)),
            ]),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 10),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 19),
              ),
            ),
          ).toTextEditingValue(),
          expectedTextWithSelection: "This is a |paragraph| of text.",
        );
      });

      test('two text nodes is reported as a TextEditingValue', () {
        const text1 = "This is the first paragraph of text.";
        const text2 = "This is the second paragraph of text.";

        _expectTextEditingValue(
          actualTextEditingValue: DocumentImeSerializer(
            MutableDocument(nodes: [
              ParagraphNode(id: "1", text: AttributedText(text: text1)),
              ParagraphNode(id: "2", text: AttributedText(text: text2)),
            ]),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
              extent: DocumentPosition(
                nodeId: "2",
                nodePosition: TextNodePosition(offset: 28),
              ),
            ),
          ).toTextEditingValue(),
          expectedTextWithSelection: "This is the |first paragraph of text.\nThis is the second paragraph| of text.",
        );
      });

      test('text with internal non-text reported as a TextEditingValue', () {
        const text = "This is a paragraph of text.";

        _expectTextEditingValue(
          actualTextEditingValue: DocumentImeSerializer(
            MutableDocument(nodes: [
              ParagraphNode(id: "1", text: AttributedText(text: text)),
              HorizontalRuleNode(id: "2"),
              ParagraphNode(id: "3", text: AttributedText(text: text)),
            ]),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 10),
              ),
              extent: DocumentPosition(
                nodeId: "3",
                nodePosition: TextNodePosition(offset: 19),
              ),
            ),
          ).toTextEditingValue(),
          expectedTextWithSelection: "This is a |paragraph of text.\n~\nThis is a paragraph| of text.",
        );
      });

      test('text with non-text end-caps reported as a TextEditingValue', () {
        const text = "This is the first paragraph of text.";

        _expectTextEditingValue(
          actualTextEditingValue: DocumentImeSerializer(
            MutableDocument(nodes: [
              HorizontalRuleNode(id: "1"),
              ParagraphNode(id: "2", text: AttributedText(text: text)),
              HorizontalRuleNode(id: "3"),
            ]),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
              extent: DocumentPosition(
                nodeId: "3",
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
          ).toTextEditingValue(),
          expectedTextWithSelection: "|~\nThis is the first paragraph of text.\n~|",
        );
      });
    });
  });
}

/// Expects that the given [expectedTextWithSelection] corresponds to a
/// `TextEditingValue` that matches [actualTextEditingValue].
///
/// By combining the expected text with the expected selection into a formatted
/// `String`, this method provides a naturally readable expectation, as opposed
/// to a `TextSelection` with indices. For example, if the expected selection is
/// `TextSelection(base: 10, extent: 19)`, what segment of text does that include?
/// Instead, the caller provides a formatted `String`, like "Here is so|me text w|ith selection".
///
/// [expectedTextWithSelection] represents the expected text, and the expected
/// selection, all in one. The text within [expectedTextWithSelection] that
/// should be selected should be surrounded with "|" vertical bars.
///
/// Example:
///
///     This is expected text, and |this is the expected selection|.
///
/// This method doesn't work with text that actually contains "|" vertical bars.
void _expectTextEditingValue({
  required String expectedTextWithSelection,
  required TextEditingValue actualTextEditingValue,
}) {
  final selectionStartIndex = expectedTextWithSelection.indexOf("|");
  final selectionEndIndex =
      expectedTextWithSelection.indexOf("|", selectionStartIndex + 1) - 1; // -1 to account for the selection start "|"
  final expectedText = expectedTextWithSelection.replaceAll("|", "");
  final expectedSelection = TextSelection(baseOffset: selectionStartIndex, extentOffset: selectionEndIndex);

  expect(
    actualTextEditingValue,
    TextEditingValue(text: expectedText, selection: expectedSelection),
  );
}
