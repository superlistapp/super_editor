import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      testWidgetsOnDesktop('updates caret position when indenting', (tester) async {
        await _pumpOrderedListWithTextField(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemNode = doc.nodes.first as ListItemNode;

        // Place caret at the first list item, which has one level of indentation.
        await tester.placeCaretInParagraph(listItemNode.id, 0);

        // Ensure the list item has first level of indentation.
        expect(listItemNode.indent, 0);

        // Ensure the caret is initially positioned near the upstream edge of the first
        // character of the list item.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetBeforeIndent = SuperEditorInspector.findCaretOffsetInDocument();
        final firstCharacterRectBeforeIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetBeforeIndent.dx, moreOrLessEquals(firstCharacterRectBeforeIndent.left, epsilon: 5));

        // Press tab to trigger the list indent command.
        await tester.pressTab();

        // Ensure the list item has second level of indentation.
        expect(listItemNode.indent, 1);

        // Ensure that the caret's current offset is downstream from the initial caret offset,
        // and also that the current caret offset is roughly positioned near the upstream edge
        // of the first list item character.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetAfterIndent = SuperEditorInspector.findCaretOffsetInDocument();
        expect(caretOffsetAfterIndent.dx, greaterThan(caretOffsetBeforeIndent.dx));
        final firstCharacterRectAfterIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetAfterIndent.dx, moreOrLessEquals(firstCharacterRectAfterIndent.left, epsilon: 5));
      });

      testWidgetsOnDesktop('updates caret position when unindenting', (tester) async {
        await _pumpUnorderedListWithTextField(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemNode = doc.nodes.last as ListItemNode;

        // Place caret at the last list item, which has two levels of indentation.
        // For some reason, taping at the first character isn't displaying any caret,
        // so we put the caret at the second character and then go back one position.
        await tester.placeCaretInParagraph(listItemNode.id, 1);
        await tester.pressLeftArrow();

        // Ensure the list item has second level of indentation.
        expect(listItemNode.indent, 1);

        // Ensure the caret is initially positioned near the upstream edge of the first
        // character of the list item.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetBeforeUnIndent = SuperEditorInspector.findCaretOffsetInDocument();
        final firstCharacterRectBeforeUnIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetBeforeUnIndent.dx, moreOrLessEquals(firstCharacterRectBeforeUnIndent.left, epsilon: 5));

        // Press backspace to trigger the list unindent command.
        await tester.pressBackspace();

        // Ensure the list item has first level of indentation.
        expect(listItemNode.indent, 0);

        // Ensure that the caret's current offset is upstream from the initial caret offset,
        // and also that the current caret offset is roughly positioned near the upstream edge
        // of the first list item character.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetAfterUnIndent = SuperEditorInspector.findCaretOffsetInDocument();
        expect(caretOffsetAfterUnIndent.dx, lessThan(caretOffsetBeforeUnIndent.dx));
        final firstCharacterRectAfterUnIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetAfterUnIndent.dx, moreOrLessEquals(firstCharacterRectAfterUnIndent.left, epsilon: 5));
      });

      testWidgetsOnDesktop('unindents with SHIFT + TAB', (tester) async {
        await _pumpUnorderedListWithTextField(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemNode = doc.nodes.last as ListItemNode;

        // Place caret at the last list item, which has two levels of indentation.
        // For some reason, taping at the first character isn't displaying any caret,
        // so we put the caret at the second character and then go back one position.
        await tester.placeCaretInParagraph(listItemNode.id, 1);
        await tester.pressLeftArrow();

        // Ensure the list item has second level of indentation.
        expect(listItemNode.indent, 1);

        // Press SHIFT + TAB to trigger the list unindent command.
        await _pressShiftTab(tester);

        // Ensure the list item has first level of indentation.
        expect(listItemNode.indent, 0);
      });

      testWidgetsOnAllPlatforms("inserts new item on ENTER at end of existing item", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown('* Item 1')
            .pump();

        final document = context.findEditContext().document;

        // Place the caret at the end of the list item.
        await tester.placeCaretInParagraph(document.nodes.last.id, 6);

        // Type at the end of the list item to generate a composing region,
        // simulating the Samsung keyboard.
        await tester.typeImeText('2');
        await tester.ime.sendDeltas(const [
          TextEditingDeltaNonTextUpdate(
            oldText: '. Item 12',
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange.collapsed(9),
          ),
        ], getter: imeClientGetter);

        // Press enter to create a new list item.
        await tester.pressEnter();

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 12");

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

        // Type at the end of the list item to generate a composing region,
        // simulating the Samsung keyboard.
        await tester.typeImeText('2');
        await tester.ime.sendDeltas(const [
          TextEditingDeltaNonTextUpdate(
            oldText: '. Item 12',
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange.collapsed(9),
          ),
        ], getter: imeClientGetter);

        // On Android, pressing ENTER generates a "\n" insertion.
        await tester.typeImeText("\n");

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 12");

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

        // Type at the end of the list item to generate a composing region,
        // simulating the Samsung keyboard.
        await tester.typeImeText('2');
        await tester.ime.sendDeltas(const [
          TextEditingDeltaNonTextUpdate(
            oldText: '. Item 12',
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange.collapsed(9),
          ),
        ], getter: imeClientGetter);

        // On iOS, pressing ENTER generates a newline action.
        await tester.testTextInput.receiveAction(TextInputAction.newline);

        // Ensure that a new, empty list item was created.
        expect(document.nodes.length, 2);

        // Ensure the existing item remains the same.
        expect(document.nodes.first, isA<ListItemNode>());
        expect((document.nodes.first as ListItemNode).text.text, "Item 12");

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
      testWidgetsOnArbitraryDesktop('keeps sequence for items split by unordered list', (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("""
1. First ordered item
   - First unordered item
   - Second unoredered item

2. Second ordered item
   - First unordered item
   - Second unoredered item""") //
            .pump();

        expect(context.document.nodes.length, 6);

        // Ensure the nodes have the correct type.
        expect(context.document.nodes[0], isA<ListItemNode>());
        expect((context.document.nodes[0] as ListItemNode).type, ListItemType.ordered);

        expect(context.document.nodes[1], isA<ListItemNode>());
        expect((context.document.nodes[1] as ListItemNode).type, ListItemType.unordered);

        expect(context.document.nodes[2], isA<ListItemNode>());
        expect((context.document.nodes[2] as ListItemNode).type, ListItemType.unordered);

        expect(context.document.nodes[3], isA<ListItemNode>());
        expect((context.document.nodes[3] as ListItemNode).type, ListItemType.ordered);

        expect(context.document.nodes[4], isA<ListItemNode>());
        expect((context.document.nodes[4] as ListItemNode).type, ListItemType.unordered);

        expect(context.document.nodes[5], isA<ListItemNode>());
        expect((context.document.nodes[5] as ListItemNode).type, ListItemType.unordered);

        // Ensure the sequence was kept.
        final firstOrderedItem = tester.widget<OrderedListItemComponent>(
          find.ancestor(
            of: find.byWidget(SuperEditorInspector.findWidgetForComponent(context.document.nodes[0].id)),
            matching: find.byType(OrderedListItemComponent),
          ),
        );
        expect(firstOrderedItem.listIndex, 1);

        final secondOrderedItem = tester.widget<OrderedListItemComponent>(
          find.ancestor(
            of: find.byWidget(SuperEditorInspector.findWidgetForComponent(context.document.nodes[3].id)),
            matching: find.byType(OrderedListItemComponent),
          ),
        );
        expect(secondOrderedItem.listIndex, 2);
      });

      testWidgetsOnArbitraryDesktop('does not keep sequence for items split by paragraphs', (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("""
1. First ordered item

A paragraph

2. Second ordered item""") //
            .pump();

        expect(context.document.nodes.length, 3);

        // Ensure the nodes have the correct type.
        expect(context.document.nodes[0], isA<ListItemNode>());
        expect((context.document.nodes[0] as ListItemNode).type, ListItemType.ordered);

        expect(context.document.nodes[1], isA<ParagraphNode>());

        expect(context.document.nodes[2], isA<ListItemNode>());
        expect((context.document.nodes[2] as ListItemNode).type, ListItemType.ordered);

        // Ensure the sequence reset when reaching the second list item.
        final firstOrderedItem = tester.widget<OrderedListItemComponent>(
          find.ancestor(
            of: find.byWidget(SuperEditorInspector.findWidgetForComponent(context.document.nodes[0].id)),
            matching: find.byType(OrderedListItemComponent),
          ),
        );
        expect(firstOrderedItem.listIndex, 1);

        final secondOrderedItem = tester.widget<OrderedListItemComponent>(
          find.ancestor(
            of: find.byWidget(SuperEditorInspector.findWidgetForComponent(context.document.nodes[2].id)),
            matching: find.byType(OrderedListItemComponent),
          ),
        );
        expect(secondOrderedItem.listIndex, 1);
      });

      testWidgetsOnArbitraryDesktop('updates caret position when indenting', (tester) async {
        await _pumpOrderedListWithTextField(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemNode = doc.nodes.first as ListItemNode;

        // Place caret at the first list item, which has one level of indentation.
        await tester.placeCaretInParagraph(listItemNode.id, 0);

        // Ensure the list item has first level of indentation.
        expect(listItemNode.indent, 0);

        // Ensure the caret is initially positioned near the upstream edge of the first
        // character of the list item.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetBeforeIndent = SuperEditorInspector.findCaretOffsetInDocument();
        final firstCharacterRectBeforeIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetBeforeIndent.dx, moreOrLessEquals(firstCharacterRectBeforeIndent.left, epsilon: 5));

        // Press tab to trigger the list indent command.
        await tester.pressTab();

        // Ensure the list item has second level of indentation.
        expect(listItemNode.indent, 1);

        // Ensure that the caret's current offset is downstream from the initial caret offset,
        // and also that the current caret offset is roughly positioned near the upstream edge
        // of the first list item character.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetAfterIndent = SuperEditorInspector.findCaretOffsetInDocument();
        expect(caretOffsetAfterIndent.dx, greaterThan(caretOffsetBeforeIndent.dx));
        final firstCharacterRectAfterIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetAfterIndent.dx, moreOrLessEquals(firstCharacterRectAfterIndent.left, epsilon: 5));
      });

      testWidgetsOnArbitraryDesktop('updates caret position when unindenting', (tester) async {
        await _pumpOrderedListWithTextField(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemNode = doc.nodes.last as ListItemNode;

        // Place caret at the last list item, which has two levels of indentation.
        // For some reason, taping at the first character isn't displaying any caret,
        // so we put the caret at the second character and then go back one position.
        await tester.placeCaretInParagraph(listItemNode.id, 1);
        await tester.pressLeftArrow();

        // Ensure the list item has second level of indentation.
        expect(listItemNode.indent, 1);

        // Ensure the caret is initially positioned near the upstream edge of the first
        // character of the list item.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetBeforeUnIndent = SuperEditorInspector.findCaretOffsetInDocument();
        final firstCharacterRectBeforeUnIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetBeforeUnIndent.dx, moreOrLessEquals(firstCharacterRectBeforeUnIndent.left, epsilon: 5));

        // Press backspace to trigger the list unindent command.
        await tester.pressBackspace();

        // Ensure the list item has first level of indentation.
        expect(listItemNode.indent, 0);

        // Ensure that the caret's current offset is upstream from the initial caret offset,
        // and also that the current caret offset is roughly positioned near the upstream edge
        // of the first list item character.
        //
        // We only care about a roughly accurate caret offset because the logic around
        // exact caret positioning might change and we don't want that to break this test.
        final caretOffsetAfterUnIndent = SuperEditorInspector.findCaretOffsetInDocument();
        expect(caretOffsetAfterUnIndent.dx, lessThan(caretOffsetBeforeUnIndent.dx));
        final firstCharacterRectAfterUnIndent = SuperEditorInspector.findDocumentLayout().getRectForPosition(
          DocumentPosition(nodeId: listItemNode.id, nodePosition: const TextNodePosition(offset: 0)),
        )!;
        expect(caretOffsetAfterUnIndent.dx, moreOrLessEquals(firstCharacterRectAfterUnIndent.left, epsilon: 5));
      });

      testWidgetsOnDesktop('unindents with SHIFT + TAB', (tester) async {
        await _pumpOrderedListWithTextField(tester);

        final doc = SuperEditorInspector.findDocument()!;
        final listItemNode = doc.nodes.last as ListItemNode;

        // Place caret at the last list item, which has two levels of indentation.
        // For some reason, taping at the first character isn't displaying any caret,
        // so we put the caret at the second character and then go back one position.
        await tester.placeCaretInParagraph(listItemNode.id, 1);
        await tester.pressLeftArrow();

        // Ensure the list item has second level of indentation.
        expect(listItemNode.indent, 1);

        // Press SHIFT + TAB to trigger the list unindent command.
        await _pressShiftTab(tester);

        // Ensure the list item has first level of indentation.
        expect(listItemNode.indent, 0);
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

/// Pumps a [SuperEditor] containing 4 unordered list items and a [TextField] below it.
///
/// The first two items have one level of indentation.
///
/// The last two items have two levels of indentation.
Future<TestDocumentContext> _pumpUnorderedListWithTextField(
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
      .withInputSource(TextInputSource.ime)
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TextField(),
                Expanded(child: superEditor),
                const TextField(),
              ],
            ),
          ),
        ),
      )
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

/// Pumps a [SuperEditor] containing 4 ordered list items and a [TextField] below it.
///
/// The first two items have one level of indentation.
///
/// The last two items have two levels of indentation.
Future<TestDocumentContext> _pumpOrderedListWithTextField(
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
      .withInputSource(TextInputSource.ime)
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: superEditor),
                const TextField(),
              ],
            ),
          ),
        ),
      )
      .pump();
}

Future<void> _pressShiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.pumpAndSettle();
}

TextStyle _inlineTextStyler(Set<Attribution> attributions, TextStyle base) => base;

final _styleSheet = Stylesheet(
  inlineTextStyler: _inlineTextStyler,
  rules: [
    StyleRule(
      const BlockSelector("paragraph"),
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
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
          Styles.textStyle: const TextStyle(
            color: Colors.blue,
            fontSize: 16,
          ),
        };
      },
    ),
  ],
);
