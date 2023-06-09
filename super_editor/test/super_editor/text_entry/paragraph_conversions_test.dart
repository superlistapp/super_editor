import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';

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
          final document = context.editContext.document;
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
        final document = context.editContext.document;
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

        final listItemNode = context.editContext.document.nodes.first;
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

        final paragraphNode = context.editContext.document.nodes.first;
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

        final paragraphNode = context.editContext.document.nodes.first;
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

        final listItemNode = context.editContext.document.nodes.first;
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

        final paragraphNode = context.editContext.document.nodes.first;
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

        final paragraphNode = context.editContext.document.nodes.first;
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
        final document = context.editContext.document;
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

        final paragraphNode = context.editContext.document.nodes.first;
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
        final document = context.editContext.document;
        final paragraph = document.nodes.first as ParagraphNode;

        expect(paragraph.metadata['blockType'], blockquoteAttribution);
        expect(paragraph.text.text.isEmpty, isTrue);
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
