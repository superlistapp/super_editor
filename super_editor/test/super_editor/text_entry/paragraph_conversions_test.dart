import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../document_test_tools.dart';

void main() {
  group("SuperEditor content conversion >", () {
    group("paragraph to headers >", () {
      testWidgetsOnAllPlatforms(
        "with a #",
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

      testWidgetsOnAllPlatforms("doesn't convert with 7 or more #", (tester) async {
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
