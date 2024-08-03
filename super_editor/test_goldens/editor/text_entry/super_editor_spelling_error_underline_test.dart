import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

import '../../test_tools_goldens.dart';

void main() {
  group("SuperEditor > text entry > spelling error >", () {
    testGoldensOnAndroid("is underlined in paragraph", _showsUnderlineInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOnAndroid("is underlined in blockquote", _showsUnderlineInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOnAndroid("is underlined in list item", _showsUnderlineInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOnAndroid("is underlined in task", _showsUnderlineInTask, windowSize: goldenSizeLongStrip);

    testGoldensOniOS("is underlined in paragraph", _showsUnderlineInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOniOS("is underlined in blockquote", _showsUnderlineInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOniOS("is underlined in list item", _showsUnderlineInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOniOS("is underlined in task", _showsUnderlineInTask, windowSize: goldenSizeLongStrip);

    testGoldensOnMac("is underlined in paragraph", _showsUnderlineInParagraph, windowSize: goldenSizeLongStrip);
    testGoldensOnMac("is underlined in blockquote", _showsUnderlineInBlockquote, windowSize: goldenSizeLongStrip);
    testGoldensOnMac("is underlined in list item", _showsUnderlineInListItem, windowSize: goldenSizeLongStrip);
    testGoldensOnMac("is underlined in task", _showsUnderlineInTask, windowSize: goldenSizeLongStrip);
  });
}

Future<void> _showsUnderlineInParagraph(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _paragraphMarkdown);

  _addSpellingError(tester, editor, document);

  // Ensure the composing region is underlined.
  await screenMatchesGolden(
      tester, "super-editor_text-entry_spelling-error-shows-underline_paragraph_${defaultTargetPlatform.name}_1");
}

Future<void> _showsUnderlineInBlockquote(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _blockquoteMarkdown);

  _addSpellingError(tester, editor, document);

  // Ensure the composing region is underlined.
  await screenMatchesGolden(
      tester, "super-editor_text-entry_spelling-error-shows-underline_blockquote_${defaultTargetPlatform.name}_1");
}

Future<void> _showsUnderlineInListItem(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _listItemMarkdown);

  _addSpellingError(tester, editor, document);

  // Ensure the composing region is underlined.
  await screenMatchesGolden(
      tester, "super-editor_text-entry_spelling-error-shows-underline_list-item_${defaultTargetPlatform.name}_1");
}

Future<void> _showsUnderlineInTask(WidgetTester tester) async {
  final (editor, document) = await _pumpScaffold(tester, _taskMarkdown);

  _addSpellingError(tester, editor, document);

  // Ensure the composing region is underlined.
  await screenMatchesGolden(
      tester, "super-editor_text-entry_spelling-error-shows-underline_task_${defaultTargetPlatform.name}_1");
}

Future<(Editor, Document)> _pumpScaffold(WidgetTester tester, String contentMarkdown) async {
  // TODO: Whenever we're able to create a TaskComponentBuilder without passing the Editor, refactor
  //       this setup to look like a normal SuperEditor test.
  final document = deserializeMarkdownToDocument(contentMarkdown);
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SuperEditor(
          editor: editor,
          componentBuilders: [
            TaskComponentBuilder(editor),
            ...defaultComponentBuilders,
          ],
          stylesheet: _stylesheet,
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  ));

  return (editor, document);
}

Future<void> _addSpellingError(WidgetTester tester, Editor editor, Document document) async {
  final nodeId = document.first.id;
  editor.execute([
    AddTextAttributionsRequest(
      documentRange: DocumentRange(
        start: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 22),
        ),
        end: DocumentPosition(
          nodeId: nodeId,
          nodePosition: const TextNodePosition(offset: 23),
        ),
      ),
      attributions: {spellingErrorAttribution},
    ),
  ]);
  await tester.pumpAndSettle();
}

const _paragraphMarkdown = "Typing with composing a";
const _blockquoteMarkdown = "> Typing with composing a";
const _listItemMarkdown = " * Typing with composing a";
const _taskMarkdown = "- [ ] Typing with composing a";

/// A [StyleSheet] which applies the Roboto font for all nodes.
///
/// This is needed to use real font glyphs in the golden tests.
final _stylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) {
      return {
        Styles.textStyle: const TextStyle(
          fontFamily: 'Roboto',
        ),
      };
    })
  ],
);
