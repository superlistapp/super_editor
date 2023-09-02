import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../supereditor_test_tools.dart';

void main() {
  group('List items', () {
    group('node conversion', () {
      testWidgetsOnArbitraryDesktop("applies styles when unordered list item is converted to and from a paragraph",
          (WidgetTester tester) async {
        final testContext = await _pumpUnorderedList(
          tester,
          styleSheet: _styleSheet,
        );
        final doc = SuperEditorInspector.findDocument()!;

        LayoutAwareRichText richText;

        // Ensure that the textStyle for a list item was applied.
        expect(find.byType(LayoutAwareRichText), findsWidgets);
        richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText.text.style!.color, Colors.blue);

        // Tap to place caret.
        await tester.placeCaretInParagraph(doc.nodes.first.id, 0);

        // Convert the list item to a paragraph.
        testContext.findEditContext().commonOps.convertToParagraph(
          newMetadata: {
            'blockType': const NamedAttribution("paragraph"),
          },
        );
        await tester.pumpAndSettle();

        // Ensure that the textStyle for a paragraph was applied.
        expect(find.byType(LayoutAwareRichText), findsWidgets);
        richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText.text.style!.color, Colors.red);

        // Convert the paragraph back to an unordered list item.
        testContext.findEditContext().commonOps.convertToListItem(
              ListItemType.unordered,
              (doc.nodes.first as ParagraphNode).text,
            );
        await tester.pumpAndSettle();

        // Ensure that the textStyle for a list item was applied.
        expect(find.byType(LayoutAwareRichText), findsWidgets);
        richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText.text.style!.color, Colors.blue);
      });

      testWidgetsOnArbitraryDesktop("applies styles when ordered list item is converted to and from a paragraph",
          (WidgetTester tester) async {
        final testContext = await _pumpOrderedList(
          tester,
          styleSheet: _styleSheet,
        );
        final doc = SuperEditorInspector.findDocument()!;

        LayoutAwareRichText richText;

        // Ensure that the textStyle for a list item was applied.
        expect(find.byType(LayoutAwareRichText), findsWidgets);
        richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText.text.style!.color, Colors.blue);

        // Tap to place caret.
        await tester.placeCaretInParagraph(doc.nodes.first.id, 0);

        // Convert the list item to a paragraph.
        testContext.findEditContext().commonOps.convertToParagraph(
          newMetadata: {
            'blockType': const NamedAttribution("paragraph"),
          },
        );
        await tester.pumpAndSettle();

        // Ensure that the textStyle for a paragraph was applied.
        expect(find.byType(LayoutAwareRichText), findsWidgets);
        richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText.text.style!.color, Colors.red);

        // Convert the paragraph back to an ordered list item.
        testContext.findEditContext().commonOps.convertToListItem(
              ListItemType.ordered,
              (doc.nodes.first as ParagraphNode).text,
            );
        await tester.pumpAndSettle();

        // Ensure that the textStyle for a list item was applied.
        expect(find.byType(LayoutAwareRichText), findsWidgets);
        richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;
        expect(richText.text.style!.color, Colors.blue);
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

      testWidgetsOnAllPlatforms("inserts new item on ENTER at end of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* Item 1')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at the end of the list item.
        await tester.placeCaretInParagraph(document.nodes.first.id, 6);

        // Press enter to create a new list item.
        await tester.pressEnter();

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 1");

        // Ensure the new item has the correct list item type and indentation.
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "");
        expect((document.nodes.last as ListItemNode).type, ListItemType.unordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAndroid("inserts new item upon new line insertion at end of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* Item 1')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at the end of the list item.
        await tester.placeCaretInParagraph(document.nodes.first.id, 6);

        // On Android, pressing ENTER generates a "\n" insertion.
        await tester.typeImeText("\n");

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 1");

        // Ensure the new item has the correct list item type and indentation.
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "");
        expect((document.nodes.last as ListItemNode).type, ListItemType.unordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnMobile("inserts new item upon new line input action at end of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* Item 1')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at the end of the list item.
        await tester.placeCaretInParagraph(document.nodes.first.id, 6);

        // On iOS, pressing ENTER generates a newline action.
        await tester.testTextInput.receiveAction(TextInputAction.newline);

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 1");

        // Ensure the new item has the correct list item type and indentation.
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "");
        expect((document.nodes.last as ListItemNode).type, ListItemType.unordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("splits list item into two on ENTER in middle of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* List Item')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at "List |Item"
        await tester.placeCaretInParagraph(document.nodes.first.id, 5);

        // Press enter to split the existing item into two.
        await tester.pressEnter();

        // Ensure that a new item was created with part of the previous item.
        expect(document.nodes.length, 2);
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "List ");
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "Item");
        expect((document.nodes.last as ListItemNode).type, ListItemType.unordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAndroid("splits list item into two upon new line insertion in middle of existing item",
          (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* List Item')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at "List |Item"
        await tester.placeCaretInParagraph(document.nodes.first.id, 5);

        // On Android, pressing ENTER generates a "\n" insertion.
        await tester.typeImeText("\n");

        // Ensure that a new item was created with part of the previous item.
        expect(document.nodes.length, 2);
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "List ");
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "Item");
        expect((document.nodes.last as ListItemNode).type, ListItemType.unordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnMobile("splits list item into two upon new line input action in middle of existing item",
          (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* List Item')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at "List |Item"
        await tester.placeCaretInParagraph(document.nodes.first.id, 5);

        // On iOS, pressing ENTER generates a newline action.
        await tester.testTextInput.receiveAction(TextInputAction.newline);

        // Ensure that a new item was created with part of the previous item.
        expect(document.nodes.length, 2);
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "List ");
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "Item");
        expect((document.nodes.last as ListItemNode).type, ListItemType.unordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
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

      testWidgetsOnAllPlatforms("inserts new item on ENTER at end of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('1. Item 1')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at the end of the list item.
        await tester.placeCaretInParagraph(document.nodes.first.id, 6);

        // Press enter to create a new list item.
        await tester.pressEnter();

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 1");

        // Ensure the new item has the correct list item type and indentation.
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "");
        expect((document.nodes.last as ListItemNode).type, ListItemType.ordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAndroid("inserts new item upon new line insertion at end of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('1. Item 1')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at the end of the list item.
        await tester.placeCaretInParagraph(document.nodes.first.id, 6);

        // On Android, pressing ENTER generates a "\n" insertion.
        await tester.typeImeText("\n");

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 1");

        // Ensure the new item has the correct list item type and indentation.
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "");
        expect((document.nodes.last as ListItemNode).type, ListItemType.ordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnMobile("inserts new item upon new line input action at end of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('1. Item 1')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at the end of the list item.
        await tester.placeCaretInParagraph(document.nodes.first.id, 6);

        // On iOS, pressing ENTER generates a newline action.
        await tester.testTextInput.receiveAction(TextInputAction.newline);

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 1");

        // Ensure the new item has the correct list item type and indentation.
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "");
        expect((document.nodes.last as ListItemNode).type, ListItemType.ordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAllPlatforms("splits list item into two on ENTER in middle of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('1. List Item')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at "List |Item"
        await tester.placeCaretInParagraph(document.nodes.first.id, 5);

        // Press enter to split the existing item into two.
        await tester.pressEnter();

        // Ensure that a new item was created with part of the previous item.
        expect(document.nodes.length, 2);
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "List ");
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "Item");
        expect((document.nodes.last as ListItemNode).type, ListItemType.ordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnAndroid("splits list item into two upon new line insertion in middle of existing item",
          (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('1. List Item')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at "List |Item"
        await tester.placeCaretInParagraph(document.nodes.first.id, 5);

        // On Android, pressing ENTER generates a "\n" insertion.
        await tester.typeImeText("\n");

        // Ensure that a new item was created with part of the previous item.
        expect(document.nodes.length, 2);
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "List ");
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "Item");
        expect((document.nodes.last as ListItemNode).type, ListItemType.ordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });

      testWidgetsOnMobile("splits list item into two upon new line input action in middle of existing item",
          (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('1. List Item')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at "List |Item"
        await tester.placeCaretInParagraph(document.nodes.first.id, 5);

        // On iOS, pressing ENTER generates a newline action.
        await tester.testTextInput.receiveAction(TextInputAction.newline);

        // Ensure that a new item was created with part of the previous item.
        expect(document.nodes.length, 2);
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "List ");
        expect(document.nodes.last, isA<ListItemNode>());
        expect((document.nodes.last as ListItemNode).text.text, "Item");
        expect((document.nodes.last as ListItemNode).type, ListItemType.ordered);
        expect((document.nodes.last as ListItemNode).indent, 0);
        expect(
          SuperEditorInspector.findDocumentSelection(),
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: document.nodes.last.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
        );
      });
    });
  });
}

/// Pumps a [SuperEditor] containing 3 unordered list items.
///
/// The first two items have one level of indentation.
///
/// The last two items have two levels of indentation.
Future<TestDocumentContext> _pumpUnorderedList(
  WidgetTester tester, {
  Stylesheet? styleSheet,
}) async {
  const markdown = '''
 * list item 1
 * list item 2
   * list item 2.1
   * list item 2.2''';

  return await tester //
      .createDocument()
      .fromMarkdown(markdown)
      .useStylesheet(styleSheet)
      .pump();
}

/// Pumps a [SuperEditor] containing 4 ordered list items.
///
/// The first two items have one level of indentation.
///
/// The last two items have two levels of indentation.
Future<TestDocumentContext> _pumpOrderedList(
  WidgetTester tester, {
  Stylesheet? styleSheet,
}) async {
  const markdown = '''
 1. list item 1
 1. list item 2
    1. list item 2.1
    1. list item 2.2''';

  return await tester //
      .createDocument()
      .fromMarkdown(markdown)
      .useStylesheet(styleSheet)
      .pump();
}

TextStyle _inlineTextStyler(Set<Attribution> attributions, TextStyle base) => base;

final _styleSheet = Stylesheet(
  inlineTextStyler: _inlineTextStyler,
  rules: [
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
  ],
);
