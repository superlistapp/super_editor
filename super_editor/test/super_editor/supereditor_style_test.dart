import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnArbitraryDesktop('changes visual text style when attributions change', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleParagraph()
          .pump();

      // Double tap to select the first word.
      await tester.doubleTapInParagraph('1', 0);

      // Apply italic to the word.
      testContext.editContext.commonOps.toggleAttributionsOnSelection({italicsAttribution});
      await tester.pump();

      // Ensure italic was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontStyle,
        FontStyle.italic,
      );
    });

    testWidgetsOnArbitraryDesktop('changes visual text style when style rule changes', (tester) async {
      final testContext = await tester //
          .createDocument()
          .withTwoEmptyParagraphs()
          .useStylesheet(_stylesheet)
          .pump();

      final doc = testContext.editContext.document;

      final firstParagraphId = doc.nodes[0].id;
      final secondParagraphId = doc.nodes[1].id;

      // Ensure the rule for paragraph is applied.
      expect(SuperEditorInspector.findParagraphStyle(firstParagraphId)!.color, Colors.red);

      // Remove the second paragraph.
      testContext.editContext.editor.execute([
        DeleteNodeRequest(nodeId: secondParagraphId),
      ]);
      await tester.pump();

      // The first paragraph is now the only paragraph in the document.
      // Therefore, the rule for "last paragraph" should be applied.
      expect(SuperEditorInspector.findParagraphStyle(firstParagraphId)!.color, Colors.blue);
    });

    testWidgetsOnArbitraryDesktop('retains visual text style when combining a list item with a paragraph',
        (tester) async {
      await tester //
          .createDocument()
          .fromMarkdown("""
* 1
* 2

A paragraph
          """)
          .useStylesheet(Stylesheet(
            inlineTextStyler: inlineTextStyler,
            rules: [
              StyleRule(
                const BlockSelector("listItem"),
                (doc, docNode) {
                  return {
                    "textStyle": const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  };
                },
              ),
              StyleRule(
                const BlockSelector("paragraph"),
                (doc, docNode) {
                  return {
                    "textStyle": const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  };
                },
              ),
            ],
          ))
          .pump();

      // Ensure the correct style was applied to the list item.
      expect(
        SuperEditorInspector.findParagraphStyle(SuperEditorInspector.getNodeAt(1).id)!.color,
        Colors.blue,
      );

      // Ensure the correct style was applied to the paragraph.
      expect(
        SuperEditorInspector.findParagraphStyle(SuperEditorInspector.getNodeAt(2).id)!.color,
        Colors.red,
      );

      // Place the caret at the end of the second list item.
      final secondListItem = SuperEditorInspector.getNodeAt<ListItemNode>(1);
      await tester.placeCaretInParagraph(secondListItem.id, 1);

      // Press backspace to delete the list item text. The content will be empty.
      await tester.pressBackspace();

      // Place the caret at the beginning of the paragraph.
      final paragraph = SuperEditorInspector.getNodeAt<ParagraphNode>(2);
      await tester.placeCaretInParagraph(paragraph.id, 0);

      // Press backspace to combine the list item and the paragraph.
      await tester.pressBackspace();

      // Ensure the list item retained the correct style.
      expect(
        SuperEditorInspector.findParagraphStyle(SuperEditorInspector.getNodeAt(1).id)!.color,
        Colors.blue,
      );
    });

    testWidgetsOnArbitraryDesktop('rebuilds only changed nodes', (tester) async {
      int componentChangedCount = 0;

      await tester
          .createDocument() //
          .withLongTextContent()
          .pump();

      await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.nodes.last.id, 0);

      final presenter = tester.state<SuperEditorState>(find.byType(SuperEditor)).presenter;
      presenter.addChangeListener(SingleColumnLayoutPresenterChangeListener(
        onViewModelChange: ({required addedComponents, required changedComponents, required removedComponents}) {
          if (componentChangedCount != 0) {
            // The listener is called two times. The first one for the text change, which is the one
            // we care about, and the second one for the selection change.
            // Return early to avoid overriding the value.
            return;
          }
          componentChangedCount = changedComponents.length;
        },
      ));

      // Type text, changing only one node.
      await tester.typeKeyboardText('a');

      // Ensure only the changed component was marked as dirty.
      expect(componentChangedCount, 1);
    });
  });
}

InlineSpan _findSpanAtOffset(
  WidgetTester tester, {
  required int offset,
}) {
  final superTextWithSelection = tester.widget<SuperTextWithSelection>(find.byType(SuperTextWithSelection));
  return superTextWithSelection.richText.getSpanForPosition(TextPosition(offset: offset))!;
}

final _stylesheet = Stylesheet(
  inlineTextStyler: inlineTextStyler,
  rules: [
    StyleRule(
      const BlockSelector("paragraph"),
      (doc, docNode) {
        return {
          "textStyle": const TextStyle(
            color: Colors.red,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").last(),
      (doc, docNode) {
        return {
          "textStyle": const TextStyle(
            color: Colors.blue,
          )
        };
      },
    ),
  ],
);
TextStyle inlineTextStyler(Set<Attribution> attributions, TextStyle base) {
  return base;
}
