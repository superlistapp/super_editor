import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

import '../../../test/super_editor/supereditor_test_tools.dart';
import '../../test_tools_goldens.dart';

void main() {
  group("SuperEditor > text entry > composing region underline >", () {
    testGoldensOnMac("in paragraph", (tester) async {
      final context = await tester
          .createDocument()
          .withCustomContent(
            deserializeMarkdownToDocument("Typing with composing a"),
          )
          .useStylesheet(_stylesheet)
          .pump();

      final nodeId = context.document.nodes.first.id;
      context.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(
          DocumentRange(
            start: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 22),
            ),
            end: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
        ),
      ]);
      await tester.pumpAndSettle();

      // Ensure the composing region is underlined.
      await screenMatchesGolden(tester, "super-editor_text-entry_composing-region-underline_paragraph_1");

      context.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(null),
      ]);
      await tester.pump();

      // Ensure the underline disappeared now that the composing region is null.
      await screenMatchesGolden(tester, "super-editor_text-entry_composing-region-underline_paragraph_2");
    });

    testGoldensOnMac("in list item", (tester) async {
      final context = await tester
          .createDocument()
          .withCustomContent(
            deserializeMarkdownToDocument(" * Typing with composing a"),
          )
          .useStylesheet(_stylesheet)
          .pump();

      final nodeId = context.document.nodes.first.id;
      context.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(
          DocumentRange(
            start: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 22),
            ),
            end: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
        ),
      ]);
      await tester.pumpAndSettle();

      // Ensure the composing region is underlined.
      await screenMatchesGolden(tester, "super-editor_text-entry_composing-region-underline_list-item_1");

      context.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(null),
      ]);
      await tester.pump();

      // Ensure the underline disappeared now that the composing region is null.
      await screenMatchesGolden(tester, "super-editor_text-entry_composing-region-underline_list-item_2");
    });

    testGoldensOnMac("in task", (tester) async {
      // TODO: Whenever we're able to create a TaskComponentBuilder without passing the Editor, refactor
      //       this setup to look like a normal SuperEditor test.
      final document = deserializeMarkdownToDocument("- [ ] Typing with composing a");
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SuperEditor(
            editor: editor,
            document: document,
            composer: composer,
            componentBuilders: [
              TaskComponentBuilder(editor),
              ...defaultComponentBuilders,
            ],
            stylesheet: _stylesheet,
          ),
        ),
      ));

      final nodeId = document.nodes.first.id;
      editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(
          DocumentRange(
            start: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 22),
            ),
            end: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
        ),
      ]);
      await tester.pumpAndSettle();

      // Ensure the composing region is underlined.
      await screenMatchesGolden(tester, "super-editor_text-entry_composing-region-underline_task_1");

      editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: nodeId,
              nodePosition: const TextNodePosition(offset: 23),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        ChangeComposingRegionRequest(null),
      ]);
      await tester.pump();

      // Ensure the underline disappeared now that the composing region is null.
      await screenMatchesGolden(tester, "super-editor_text-entry_composing-region-underline_task_2");
    });
  });
}

/// A [StyleSheet] which applies the Roboto font for all nodes.
///
/// This is needed to use real font glyphs in the golden tests.
final _stylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) {
      return {
        "textStyle": const TextStyle(
          fontFamily: 'Roboto',
        ),
      };
    })
  ],
);
