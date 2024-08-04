import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/super_editor_markdown.dart';

import '../../test_tools_goldens.dart';

void main() {
  group("SuperEditor > text entry > spelling error >", () {
    group("direct styling >", () {
      testGoldensOnMobile(
        "is underlined in paragraph",
        _createWidgetTest(
          contentTypeName: "paragraph",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _paragraphMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMobile(
        "is underlined in blockquote",
        _createWidgetTest(
          contentTypeName: "blockquote",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _blockquoteMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMobile(
        "is underlined in list item",
        _createWidgetTest(
          contentTypeName: "list-item",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _listItemMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMobile(
        "is underlined in task",
        _createWidgetTest(
          contentTypeName: "task",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _taskMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );

      testGoldensOnMac(
        "is underlined in paragraph",
        _createWidgetTest(
          contentTypeName: "paragraph",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _paragraphMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMac(
        "is underlined in blockquote",
        _createWidgetTest(
          contentTypeName: "blockquote",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _blockquoteMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMac(
        "is underlined in list item",
        _createWidgetTest(
          contentTypeName: "list-item",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _listItemMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMac(
        "is underlined in task",
        _createWidgetTest(
          contentTypeName: "task",
          testNameQualifier: "no-stylesheet",
          stylesheet: _stylesheetWithNoSpellingErrorStyles,
          content: _taskMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
    });

    group("stylesheet styling >", () {
      testGoldensOnMobile(
        "is underlined in paragraph",
        _createWidgetTest(
          contentTypeName: "paragraph",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _paragraphMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMobile(
        "is underlined in blockquote",
        _createWidgetTest(
          contentTypeName: "blockquote",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _blockquoteMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMobile(
        "is underlined in list item",
        _createWidgetTest(
          contentTypeName: "list-item",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _listItemMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMobile(
        "is underlined in task",
        _createWidgetTest(
          contentTypeName: "task",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _taskMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );

      testGoldensOnMac(
        "is underlined in paragraph",
        _createWidgetTest(
          contentTypeName: "paragraph",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _paragraphMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMac(
        "is underlined in blockquote",
        _createWidgetTest(
          contentTypeName: "blockquote",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _blockquoteMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMac(
        "is underlined in list item",
        _createWidgetTest(
          contentTypeName: "list-item",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _listItemMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
      testGoldensOnMac(
        "is underlined in task",
        _createWidgetTest(
          contentTypeName: "task",
          testNameQualifier: "with-stylesheet",
          stylesheet: _stylesheetWithSpellingErrorStyles,
          content: _taskMarkdown,
        ),
        windowSize: goldenSizeLongStrip,
      );
    });
  });
}

Future<void> Function(WidgetTester) _createWidgetTest({
  required String contentTypeName,
  required String testNameQualifier,
  required Stylesheet stylesheet,
  required String content,
}) {
  return (WidgetTester tester) async {
    final (editor, document) = await _pumpScaffold(tester, stylesheet, content);

    _addSpellingError(tester, editor, document);

    await screenMatchesGolden(tester,
        "super-editor_text-entry_spelling-error-shows-underline_${contentTypeName}_${defaultTargetPlatform.name}_${testNameQualifier}");
  };
}

Future<(Editor, Document)> _pumpScaffold(WidgetTester tester, Stylesheet stylesheet, String contentMarkdown) async {
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
          stylesheet: stylesheet,
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
final _stylesheetWithNoSpellingErrorStyles = defaultStylesheet.copyWith(
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

/// The same as [_stylesheetWithNoSpellingErrorStyles] but with an explicit style
/// for spelling errors.
final _stylesheetWithSpellingErrorStyles = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) {
      return {
        Styles.textStyle: const TextStyle(
          fontFamily: 'Roboto',
        ),
        Styles.spellingErrorUnderlineStyle: const SquiggleUnderlineStyle(
          color: Colors.blue,
        ),
      };
    })
  ],
);
