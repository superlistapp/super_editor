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
    testGoldenSceneOnAndroid(
      // ^ Test on mobile to prevent an attempt to talk to the native Mac spelling and grammar system.
      'does not automatically re-apply spellcheck underline after deleting misspelled word',
      (tester) async {
        final clock = SpellcheckClock.forTesting(tester);

        await FilmStrip(
          tester,
          goldenName: "spelling-error-underline-reset_${spellcheckDelayVariant.currentValue!.fileNameQualifier}",
          layout: SceneLayout.column,
        )
            .setup((tester) async {
              final spellCheckerService = _FakeSpellChecker({
                "Hllo": ["Hello"],
                "Flutt": ["Flutter"],
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
            .takePhoto("Original Error", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
            })
            .takePhoto("3 Characters", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.typeImeText("__");
            })
            .takePhoto("Add back and more", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
              await tester.pressBackspace();
              await tester.pressBackspace();
            })
            .takePhoto("2 Characters", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
            })
            .takePhoto("1 Character", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.pressBackspace();
            })
            .takePhoto("Empty", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.typeImeText("F");
            })
            .takePhoto("Insert Character", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.typeImeText("lutt");

              // Wait for the spell check to kick in.
              await tester.pump(const Duration(seconds: 4));

              // One extra pump to render the underline.
              await tester.pump();
            })
            .takePhoto("Report New Error", find.byType(ParagraphComponent))
            .renderOrCompareGolden();
      },
      variant: spellcheckDelayVariant,
    );

    testGoldenSceneOnAndroid(
      // ^ Test on mobile to prevent an attempt to talk to the native Mac spelling and grammar system.
      'immediately adjusts downstream spellcheck underlines when typing new characters',
      (tester) async {
        final clock = SpellcheckClock.forTesting(tester);

        await FilmStrip(
          tester,
          goldenName:
              "spelling-error-underlines-after-upstream-typing_${spellcheckDelayVariant.currentValue!.fileNameQualifier}",
          layout: SceneLayout.column,
        )
            .setup((tester) async {
              final spellCheckerService = _FakeSpellChecker({
                "msplled": ["misspelled"],
                "mlutpel": ["multiple"],
                "bnodes": ["bounds"],
              });

              await _pumpTestApp(
                tester,
                document: MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: "1",
                      text: AttributedText(
                        'Paragraph with msplled words at mlutpel places to check bnodes',
                      ),
                    ),
                  ],
                ),
                spellCheckerService: spellCheckerService,
                spellCheckDelay: spellcheckDelayVariant.currentValue == SpellcheckDelayVariant.withDelay
                    ? const Duration(seconds: 3)
                    : Duration.zero,
                clock: clock,
              );

              // One more pump to paint underlines.
              await tester.pump();
            })
            .takePhoto("Errors at start", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              // Place caret somewhere after the first misspelled word, and before the others.
              await tester.placeCaretInParagraph("1", 23);

              // Pause the clock's automatic ticker, so that we don't immediately
              // pump multiple seconds of frames and trigger a spellcheck update.
              clock.pauseAutomaticFramePumping();

              // Type some new characters.
              await tester.typeImeText("new ");
            })
            .takePhoto("After typing characters", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              // Delete some of the characters we just added.
              await tester.pressBackspace();
              await tester.pressBackspace();
            })
            .takePhoto("After deleting characters", find.byType(ParagraphComponent))
            .renderOrCompareGolden();
      },
      variant: spellcheckDelayVariant,
    );

    testGoldenSceneOnAndroid(
      // ^ Test on mobile to prevent an attempt to talk to the native Mac spelling and grammar system.
      'immediately adjusts downstream spellcheck underlines when replacing upstream word',
      (tester) async {
        final clock = SpellcheckClock.forTesting(tester);

        await FilmStrip(
          tester,
          goldenName:
              "spelling-error-underlines-after-upstream-replacement_${spellcheckDelayVariant.currentValue!.fileNameQualifier}",
          layout: SceneLayout.column,
        )
            .setup((tester) async {
              final spellCheckerService = _FakeSpellChecker({
                "msplled": ["misspelled"],
                "mlutpel": ["multiple"],
                "bnodes": ["bounds"],
              });

              await _pumpTestApp(
                tester,
                document: MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: "1",
                      text: AttributedText(
                        'Paragraph with msplled words at mlutpel places to check bnodes',
                      ),
                    ),
                  ],
                ),
                spellCheckerService: spellCheckerService,
                spellCheckDelay: spellcheckDelayVariant.currentValue == SpellcheckDelayVariant.withDelay
                    ? const Duration(seconds: 3)
                    : Duration.zero,
                clock: clock,
              );

              // One more pump to paint underlines.
              await tester.pump();
            })
            .takePhoto("Errors at start", find.byType(ParagraphComponent))
            .modifyScene((tester, testContext) async {
              await tester.placeCaretInParagraph("1", 18);

              // With the current implementation of flutter_test_goldens, we won't
              // be able to see the popover toolbar. So check for it with a Finder
              // and then tap the suggestion.
              expect(find.byType(AndroidSpellingSuggestionToolbar), findsOne);
              await tester.tap(find.text("misspelled"));
              await tester.pump();
            })
            .takePhoto("After correcting first word", find.byType(ParagraphComponent))
            .renderOrCompareGolden();
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
/// a pre-canned list of suggestions for each query.
class _FakeSpellChecker extends SpellCheckService {
  _FakeSpellChecker([this._replacements = const {}]);

  final Map<String, List<String>> _replacements;

  List<String> get queriedTexts => UnmodifiableListView(_queriedTexts);
  final List<String> _queriedTexts = [];

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    _queriedTexts.add(text);

    final fakeSuggestions = <SuggestionSpan>[];
    for (final misspelledWord in _replacements.keys) {
      int nextMisspelledWord = 0;
      do {
        nextMisspelledWord = text.indexOf(misspelledWord, nextMisspelledWord);
        if (nextMisspelledWord >= 0) {
          fakeSuggestions.add(
            SuggestionSpan(
              TextRange(start: nextMisspelledWord, end: nextMisspelledWord + misspelledWord.length),
              _replacements[misspelledWord]!,
            ),
          );
          nextMisspelledWord += 1;
        }
      } while (nextMisspelledWord >= 0);
    }

    return fakeSuggestions;
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
