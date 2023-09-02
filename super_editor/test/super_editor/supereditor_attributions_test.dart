import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/test/ime.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';

import 'supereditor_test_tools.dart';

void main() {
  group("SuperEditor", () {
    group("applies attributions", () {
      group("when selecting by tapping", () {
        testWidgetsOnAllPlatforms("and typing at the end of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bold** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Place the caret at "bold|".
          await tester.placeCaretInParagraph(doc.nodes.first.id, 6);

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("er");

          // Place the caret at "text|".
          await tester.placeCaretInParagraph(doc.nodes.first.id, 13);

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText(".");

          // Ensure the bold attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("A **bolder** text."));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bld** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Place the caret at b|ld.
          await tester.placeCaretInParagraph(doc.nodes.first.id, 3);

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("o");

          // Place the caret at A|.
          await tester.placeCaretInParagraph(doc.nodes.first.id, 1);

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText("nother");

          // Ensure the bold attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("Another **bold** text"));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of a link", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("[This is a link](https://google.com) to google")
              .withInputSource(TextInputSource.ime)
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Place the caret at This is a|.
          await tester.placeCaretInParagraph(doc.nodes.first.id, 9);

          // Type at an offset that should expand the link attribution.
          await tester.typeImeText("nother");

          // Place the caret at google|.
          await tester.placeCaretInParagraph(doc.nodes.first.id, 30);

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText(".");

          // Ensure the link attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("[This is another link](https://google.com) to google."));
        });
      });

      group("when selecting by the keyboard", () {
        testWidgetsOnAllPlatforms("and typing at the end of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bold** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Place the caret at |text.
          await tester.placeCaretInParagraph(doc.nodes.first.id, 7);

          // Press left arrow to place the caret at bold|.
          await tester.pressLeftArrow();

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("er");

          // Press right arrow to place the caret at |text.
          await tester.pressRightArrow();

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText("new ");

          // Ensure the bold attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("A **bolder** new text"));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of the attributed text", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("A **bld** text")
              .withInputSource(TextInputSource.ime)
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Place the caret at A|.
          await tester.placeCaretInParagraph(doc.nodes.first.id, 1);

          // Press right arrow twice to place the caret at b|ld.
          await tester.pressRightArrow();
          await tester.pressRightArrow();

          // Type at an offset that should expand the bold attribution.
          await tester.typeImeText("o");

          // Pres right arrow three times to place the caret at bold |text.
          await tester.pressRightArrow();
          await tester.pressRightArrow();
          await tester.pressRightArrow();

          // Type at an offset that shouldn't expand any attributions.
          await tester.typeImeText("new ");

          // Ensure the bold attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("A **bold** new text"));
        });

        testWidgetsOnAllPlatforms("and typing at the middle of a link", (tester) async {
          await tester //
              .createDocument()
              .fromMarkdown("[This is a link](https://google.com) to google")
              .withInputSource(TextInputSource.ime)
              .pump();

          final doc = SuperEditorInspector.findDocument()!;

          // Place the caret at |to google.
          await tester.placeCaretInParagraph(doc.nodes.first.id, 15);

          // Press left arrow twice to place caret at lin|k.
          await tester.pressLeftArrow();
          await tester.pressLeftArrow();

          // Typing at this offset should expand the link attribution.
          await tester.typeImeText("n");

          // Press right arrow twice to place caret at |to google.
          await tester.pressRightArrow();
          await tester.pressRightArrow();

          // Typing at this offset shouldn't expand any attributions.
          await tester.typeImeText("pointing ");

          // Ensure the link attribution was applied to the inserted text.
          expect(doc, equalsMarkdown("[This is a linnk](https://google.com) pointing to google"));
        });
      });
    });

    group("doesn't apply attributions", () {
      testWidgetsOnAllPlatforms("when typing before the start of the attributed text", (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown("A **bold** text")
            .withInputSource(TextInputSource.ime)
            .pump();

        final doc = SuperEditorInspector.findDocument()!;

        // Place the caret at |bold.
        await tester.placeCaretInParagraph(doc.nodes.first.id, 2);

        // Type some letters.
        await tester.typeImeText("very ");

        // Ensure the bold attribution wasn't applied to the inserted text.
        expect(doc, equalsMarkdown("A very **bold** text"));
      });
    });

    group("doesn't clear attributions", () {
      testWidgetsOnAllPlatforms("when changing the selection affinity", (tester) async {
        final context = await tester //
            .createDocument()
            .fromMarkdown("This text should be")
            .withInputSource(TextInputSource.ime)
            .pump();

        final doc = context.findEditContext().document;
        final composer = context.findEditContext().composer;

        // Place the caret at the end of the paragraph.
        await tester.placeCaretInParagraph(doc.nodes.first.id, 19);

        // Toggle the bold attribution.
        composer.preferences.toggleStyle(boldAttribution);
        await tester.pump();

        // Ensure we have an upstream selection.
        expect((composer.selection!.extent.nodePosition as TextNodePosition).affinity, TextAffinity.upstream);

        // Simulate the IME sending us a selection at the same offset
        // but with a different affinity.
        await tester.ime.sendDeltas(
          [
            const TextEditingDeltaNonTextUpdate(
              oldText: "This text should be",
              selection: TextSelection.collapsed(offset: 19, affinity: TextAffinity.downstream),
              composing: TextRange.empty,
            ),
          ],
          getter: imeClientGetter,
        );

        // Type text at the end of the paragraph.
        await tester.typeImeText(" bold");

        // Ensure the bold attribution is applied.
        expect(doc, equalsMarkdown("This text should be** bold**"));
      });
    });
  });
}
