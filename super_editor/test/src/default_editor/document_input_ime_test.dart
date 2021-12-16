import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/document_input_ime.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

void main() {
  group('IME input', () {
    group('selected content', () {
      test('within a single node is reported as a TextEditingValue', () {
        const text = "This is a paragraph of text.";

        expect(
          selectedContentToTextEditingValue(
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
          ),
          const TextEditingValue(
            text: text,
            selection: TextSelection(baseOffset: 10, extentOffset: 19),
          ),
        );
      });

      test('two text nodes is reported as a TextEditingValue', () {
        const text1 = "This is the first paragraph of text.";
        const text2 = "This is the second paragraph of text.";

        expect(
          selectedContentToTextEditingValue(
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
          ),
          const TextEditingValue(
            text: text1 + '\n' + text2,
            selection: TextSelection(baseOffset: 12, extentOffset: 65),
          ),
        );
      });

      test('text and non-text reported as a TextEditingValue', () {
        const text = "This is the first paragraph of text.";

        expect(
          selectedContentToTextEditingValue(
            MutableDocument(nodes: [
              HorizontalRuleNode(id: "1"),
              ParagraphNode(id: "2", text: AttributedText(text: text)),
              HorizontalRuleNode(id: "3"),
            ]),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: BinaryNodePosition.included(),
              ),
              extent: DocumentPosition(
                nodeId: "3",
                nodePosition: BinaryNodePosition.included(),
              ),
            ),
          ),
          const TextEditingValue(
            text: text,
            selection: TextSelection(baseOffset: 0, extentOffset: 36),
          ),
        );
      });
    });
  });
}
