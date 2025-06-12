import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_spellcheck/src/super_editor/spellcheck_clock.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  group('SuperEditor spellcheck > timing >', () {
    testWidgetsOnArbitraryDesktop(
      'waits for a specified delay before running spellcheck',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        final spellCheckerService = _FakeSpellChecker();

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
          spellCheckDelay: const Duration(seconds: 5),
          // ^ Make sure delay is longer than the simulated typing speed.
          ignoreRules: [
            SpellingIgnoreRules.byBlockType(codeAttribution),
            SpellingIgnoreRules.byBlockType(blockquoteAttribution),
          ],
          spellCheckerService: spellCheckerService,
          clock: testClock,
        );

        // Place the caret in the paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Type text that should be spell checked after a delay.
        //
        // Don't let the test clock pump frames - otherwise it will pump until the spellcheck
        // timer goes off, and then we can't verify whether the check happened immediately, or
        // after the intended delay.
        testClock.pauseAutomaticFramePumping();
        await tester.typeImeText("Hllo");

        // Ensure spell check doesn't run immediately.
        expect(spellCheckerService.queriedTexts, [
          // empty.
        ]);

        // Simulate a delay.
        await tester.pump(const Duration(seconds: 5));

        // Ensure spell check was run after delay.
        expect(spellCheckerService.queriedTexts, [
          "Hllo",
        ]);
      },
    );

    testWidgetsOnArbitraryDesktop(
      'resets timer as user types',
      (tester) async {
        final testClock = SpellcheckClock.forTesting(tester);
        final spellCheckerService = _FakeSpellChecker();

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
          spellCheckDelay: const Duration(seconds: 5),
          // ^ Make sure delay is longer than the simulated typing speed.
          ignoreRules: [
            SpellingIgnoreRules.byBlockType(codeAttribution),
            SpellingIgnoreRules.byBlockType(blockquoteAttribution),
          ],
          spellCheckerService: spellCheckerService,
          clock: testClock,
        );

        // Place the caret in the paragraph.
        await tester.placeCaretInParagraph("1", 0);

        // Don't let the test clock pump frames - otherwise it will pump until the spellcheck
        // timer goes off, and then we can't verify whether the check happened immediately, or
        // after the intended delay.
        testClock.pauseAutomaticFramePumping();

        // Type one character at a time, fast enough to never trigger the timer, but slow enough
        // that if the timer wasn't resetting itself, the first timer would go off and trigger
        // a spell check.
        await tester.typeImeText("H");
        await tester.pump(const Duration(seconds: 2));

        await tester.typeImeText("l");
        await tester.pump(const Duration(seconds: 2));

        await tester.typeImeText("l");
        await tester.pump(const Duration(seconds: 2));

        await tester.typeImeText("o");
        await tester.pump(const Duration(seconds: 2));

        // Ensure spell check didn't run. Even though we took much longer than 5 seconds
        // in total, we never waited 5 seconds before inserting more text. Therefore, no
        // spell check should have been triggered.
        expect(spellCheckerService.queriedTexts, [
          // empty.
        ]);
      },
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
    clock: clock,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          plugins: {plugin},
        ),
      ),
    ),
  );

  return editor;
}

/// A [SpellCheckService] that records the texts that were queried and returns
/// an empty list of suggestions for each query.
class _FakeSpellChecker extends SpellCheckService {
  List<String> get queriedTexts => UnmodifiableListView(_queriedTexts);
  final List<String> _queriedTexts = [];

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    _queriedTexts.add(text);
    return const [];
  }
}
