import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../_document_test_tools.dart';

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
