import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:flutter_test_goldens/golden_bricks.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  group('SuperEditor spellcheck > styling >', () {
    // The following test on mobile to prevent an attempt to talk to the native Mac
    // spelling and grammar system.
    testGoldenSceneOnAndroid(
      'does not automatically re-apply spellcheck underline after deleting misspelled word',
      (tester) async {
        final clock = SpellcheckClock.forTesting(tester);

        await FilmStrip(tester)
            .setup((tester) async {
              final spellCheckerService = _FakeSpellChecker({
                "Hllo": {"Hello"},
                "Flutt": {"Flutter"},
              });

              await _pumpTestApp(
                tester,
                document: MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: "1",
                      text: AttributedText(''),
                    ),
                  ],
                ),
                spellCheckerService: spellCheckerService,
                spellCheckDelay: spellcheckDelayVariant.currentValue == SpellcheckDelayVariant.withDelay
                    ? const Duration(seconds: 3)
                    : Duration.zero,
                clock: clock,
              );

              // Place the caret in the paragraph.
              await tester.placeCaretInParagraph("1", 0);

              // Stop our clock from pumping frames so that as we delete and insert
              // characters, we don't wait for the spellcheck before deleting or
              // inserting more characters.
              clock.pauseAutomaticFramePumping();

              // Type a misspelled word.
              await tester.typeImeText("Hllo");

              // Wait long enough to trigger a spell check.
              await tester.pump(const Duration(seconds: 4));

              // One extra pump to render the underline.
              await tester.pump();
            })
            .takePhoto(find.byType(ParagraphComponent), "Original Error")
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
            })
            .takePhoto(find.byType(ParagraphComponent), "3 Characters")
            .modifyScene((tester, testContext) async {
              await tester.typeImeText("__");
            })
            .takePhoto(find.byType(ParagraphComponent), "Add back and more")
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
              await tester.pressBackspace();
              await tester.pressBackspace();
            })
            .takePhoto(find.byType(ParagraphComponent), "2 Characters")
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
            })
            .takePhoto(find.byType(ParagraphComponent), "1 Character")
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
            })
            .takePhoto(find.byType(ParagraphComponent), "Empty")
            .modifyScene((tester, testContext) async {
              await tester.typeImeText("F");
            })
            .takePhoto(find.byType(ParagraphComponent), "Insert Character")
            .modifyScene((tester, testContext) async {
              await tester.typeImeText("lutt");

              // Wait for the spell check to kick in.
              await tester.pump(const Duration(seconds: 4));

              // One extra pump to render the underline.
              await tester.pump();
            })
            .takePhoto(find.byType(ParagraphComponent), "Report New Error")
            .renderOrCompareGolden(
              goldenName: "spelling-error-underline-reset_${spellcheckDelayVariant.currentValue!.fileNameQualifier}",
              layout: SceneLayout.column,
            );
      },
      variant: spellcheckDelayVariant,
    );
  });
}

Future<Editor> _pumpTestApp(
  WidgetTester tester, {
  required MutableDocument document,
  List<SpellingIgnoreRule> ignoreRules = const [],
  SpellCheckService? spellCheckerService,
  Duration spellCheckDelay = Duration.zero,
  SpellcheckClock? clock,
}) async {
  final editor = createDefaultDocumentEditor(
    document: document,
    composer: MutableDocumentComposer(),
  );

  final plugin = SpellingAndGrammarPlugin(
    ignoreRules: ignoreRules,
    spellCheckService: spellCheckerService,
    spellCheckDelayAfterEdit: spellCheckDelay,
    clock: clock ?? SpellcheckClock.forTesting(tester),
    androidControlsController: SuperEditorAndroidControlsController(),
    iosControlsController: SuperEditorIosControlsController(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          stylesheet: _stylesheet,
          plugins: {plugin},
        ),
      ),
    ),
  );

  return editor;
}

final _stylesheet = defaultStylesheet.copyWith(
  inlineTextStyler: (Set<Attribution> attributions, TextStyle baseStyle) {
    return defaultStylesheet.inlineTextStyler(attributions, baseStyle).copyWith(
          fontFamily: goldenBricks,
        );
  },
);

/// A [SpellCheckService] that records the texts that were queried and returns
/// an empty list of suggestions for each query.
class _FakeSpellChecker extends SpellCheckService {
  _FakeSpellChecker([this._responses = const {}]);

  List<String> get queriedTexts => UnmodifiableListView(_queriedTexts);
  final List<String> _queriedTexts = [];

  final Map<String, Set<String>> _responses;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    _queriedTexts.add(text);

    if (_responses[text] == null) {
      return [];
    }

    return [
      // This canned response mechanism works for single word submissions. We'll need
      // to rewrite this if we want to process text with more than one word.
      SuggestionSpan(TextRange(start: 0, end: text.length), _responses[text]?.toList() ?? []),
    ];
  }
}

final spellcheckDelayVariant = ValueVariant(SpellcheckDelayVariant.values.toSet());

enum SpellcheckDelayVariant {
  noDelay,
  withDelay;

  String get fileNameQualifier => switch (this) {
        SpellcheckDelayVariant.noDelay => "no-delay",
        SpellcheckDelayVariant.withDelay => "with-delay",
      };
}
