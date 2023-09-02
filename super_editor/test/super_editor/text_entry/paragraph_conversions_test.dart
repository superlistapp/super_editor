import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor content conversion >", () {
    group("paragraph to headers >", () {
      testWidgetsOnAllPlatforms(
        "with '#'",
        (tester) async {
          final headerVariant = _headerVariant.currentValue!;

          final context = await tester //
              .createDocument()
              .withSingleEmptyParagraph()
              .withInputSource(TextInputSource.ime)
              .autoFocus(true)
              .pump();

          // Type the token that should cause an auto-conversion.
          await tester.typeImeText(headerVariant.$1);

          // Ensure that the paragraph is now a header, and it's content is empty.
          final document = context.findEditContext().document;
          final paragraph = document.nodes.first as ParagraphNode;

          expect(paragraph.metadata['blockType'], headerVariant.$2);
          expect(paragraph.text.text.isEmpty, isTrue);
        },
        variant: _headerVariant,
      );

      testWidgetsOnAllPlatforms("does not convert with 7 or more #", (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        // Type a header token that's longer than the smallest supported header
        await tester.typeImeText("####### ");

        // Ensure that the paragraph hasn't changed.
        final document = context.findEditContext().document;
        final paragraph = document.nodes.first as ParagraphNode;

        expect(paragraph.metadata['blockType'], paragraphAttribution);
        expect(paragraph.text.text, "####### ");
      });
    });

    group("paragraph to unordered list >", () {
      testWidgetsOnAllPlatforms('with', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final unorderedListItemPattern = _unorderedListVariant.currentValue!;
        await tester.typeImeText(unorderedListItemPattern);

        final listItemNode = context.findEditContext().document.nodes.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).type, ListItemType.unordered);
        expect(listItemNode.text.text.isEmpty, isTrue);
      }, variant: _unorderedListVariant);

      testWidgetsOnAllPlatforms('does not convert "1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText("1 ");

        final paragraphNode = context.findEditContext().document.nodes.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.text, "1 ");
      });

      testWidgetsOnAllPlatforms('does not convert " 1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText(" 1 ");

        final paragraphNode = context.findEditContext().document.nodes.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.text, " 1 ");
      });
    });

    group("paragraph to ordered list >", () {
      testWidgetsOnAllPlatforms('with', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final orderedListItemPattern = _orderedListVariant.currentValue!;
        await tester.typeImeText(orderedListItemPattern);

        final listItemNode = context.findEditContext().document.nodes.first;
        expect(listItemNode, isA<ListItemNode>());
        expect((listItemNode as ListItemNode).type, ListItemType.ordered);
        expect(listItemNode.text.text.isEmpty, isTrue);
      }, variant: _orderedListVariant);

      testWidgetsOnAllPlatforms('does not convert "1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText("1 ");

        final paragraphNode = context.findEditContext().document.nodes.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.text, "1 ");
      });

      testWidgetsOnAllPlatforms('does not convert " 1 "', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText(" 1 ");

        final paragraphNode = context.findEditContext().document.nodes.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.text, " 1 ");
      });
    });

    group("paragraph to horizontal rule >", () {
      testWidgetsOnAllPlatforms("with ---", (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText("--- ");

        // Ensure that we now have two nodes, and the first one is an HR.
        final document = context.findEditContext().document;
        expect(document.nodes.length, 2);

        expect(document.nodes.first, isA<HorizontalRuleNode>());
        expect(document.nodes.last, isA<ParagraphNode>());
        expect((document.nodes.last as ParagraphNode).text.text.isEmpty, isTrue);
      });

      testWidgetsOnAllPlatforms('does not convert non-HR dashes', (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        final nonHrInput = _nonHrVariant.currentValue!;
        await tester.typeImeText(nonHrInput);

        final paragraphNode = context.findEditContext().document.nodes.first;
        expect(paragraphNode, isA<ParagraphNode>());
        expect((paragraphNode as ParagraphNode).text.text, nonHrInput);
      }, variant: _nonHrVariant);
    });

    group("paragraph to blockquote >", () {
      testWidgetsOnAllPlatforms("with '> '", (tester) async {
        final context = await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .autoFocus(true)
            .pump();

        await tester.typeImeText("> ");

        // Ensure that the paragraph is now a blockquote, and it's content is empty.
        final document = context.findEditContext().document;
        final paragraph = document.nodes.first as ParagraphNode;

        expect(paragraph.metadata['blockType'], blockquoteAttribution);
        expect(paragraph.text.text.isEmpty, isTrue);
      });
    });

    group("converts to paragraph when backspace is pressed >", () {
      testWidgetsOnAllPlatforms("headers", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("# My Header")
            .withInputSource(TextInputSource.ime)
            .pump();
        final headerNode = context.findEditContext().document.nodes.first;

        await tester.placeCaretInParagraph(headerNode.id, 0);

        // Ensure that we're starting with a header.
        expect(headerNode.metadata["blockType"], header1Attribution);

        // Simulate a backspace deletion delta.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: ". My Header",
              selection: TextSelection(baseOffset: 1, extentOffset: 2),
              composing: TextRange.empty,
            ),
            const TextEditingDeltaDeletion(
              oldText: ". My Header",
              selection: TextSelection.collapsed(offset: 1),
              deletedRange: TextRange(start: 1, end: 2),
              composing: TextRange.empty,
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure that the header became a paragraph.
        expect(headerNode.metadata["blockType"], paragraphAttribution);
        expect(SuperEditorInspector.findTextInParagraph(headerNode.id).text, "My Header");
      });

      testWidgetsOnAllPlatforms("blockquotes", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("> My Blockquote")
            .withInputSource(TextInputSource.ime)
            .pump();
        final blockquoteNode = context.findEditContext().document.nodes.first;

        await tester.placeCaretInParagraph(blockquoteNode.id, 0);

        // Ensure that we're starting with a blockquote.
        expect(blockquoteNode.metadata["blockType"], blockquoteAttribution);

        // Simulate a backspace deletion delta.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: ". My Blockquote",
              selection: TextSelection(baseOffset: 1, extentOffset: 2),
              composing: TextRange.empty,
            ),
            const TextEditingDeltaDeletion(
              oldText: ". My Blockquote",
              selection: TextSelection.collapsed(offset: 1),
              deletedRange: TextRange(start: 1, end: 2),
              composing: TextRange.empty,
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure that the blockquote became a paragraph.
        expect(blockquoteNode.metadata["blockType"], paragraphAttribution);
        expect(SuperEditorInspector.findTextInParagraph(blockquoteNode.id).text, "My Blockquote");
      });

      testWidgetsOnAllPlatforms("ordered list items", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("1. My list item")
            .withInputSource(TextInputSource.ime)
            .pump();
        final listItemNode = context.findEditContext().document.nodes.first;

        await tester.placeCaretInParagraph(listItemNode.id, 0);

        // Ensure that we're starting with list item.
        expect(listItemNode, isA<ListItemNode>());

        // Simulate a backspace deletion delta.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: ". My list item",
              selection: TextSelection(baseOffset: 1, extentOffset: 2),
              composing: TextRange.empty,
            ),
            const TextEditingDeltaDeletion(
              oldText: ". My list item",
              selection: TextSelection.collapsed(offset: 1),
              deletedRange: TextRange(start: 1, end: 2),
              composing: TextRange.empty,
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure that the list item became a paragraph.
        final newNode = context.findEditContext().document.nodes.first;
        expect(newNode, isA<ParagraphNode>());
        expect(newNode.metadata["blockType"], paragraphAttribution);
        expect(SuperEditorInspector.findTextInParagraph(listItemNode.id).text, "My list item");
      });
    });
  });
}

final _headerVariant = ValueVariant({
  ("# ", header1Attribution),
  ("## ", header2Attribution),
  ("### ", header3Attribution),
  ("#### ", header4Attribution),
  ("##### ", header5Attribution),
  ("###### ", header6Attribution),
});

final _unorderedListVariant = ValueVariant({
  "* ",
  " * ",
  "- ",
  " - ",
});

final _orderedListVariant = ValueVariant({
  "1. ",
  " 1. ",
  "1) ",
  " 1) ",
});

final _nonHrVariant = ValueVariant({
  // We ignore " - " because that is a conversion for unordered list items
  "-- ",
  "---- ",
  " --- ",
});
