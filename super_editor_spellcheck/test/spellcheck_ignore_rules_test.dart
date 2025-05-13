import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  group('SuperEditor spellcheck >', () {
    group('ignore rules >', () {
      testWidgetsOnArbitraryDesktop('ignores by block type', (tester) async {
        final spellCheckerService = _FakeSpellChecker();

        await _pumpTestApp(
          tester,
          document: MutableDocument(
            nodes: [
              ParagraphNode(
                id: "1",
                text: AttributedText(
                  'This is a paragraph',
                ),
              ),
              ParagraphNode(
                id: "2",
                text: AttributedText(
                  'This is a code block',
                ),
                metadata: const {
                  NodeMetadata.blockType: codeAttribution,
                },
              ),
              ParagraphNode(
                id: "3",
                text: AttributedText(
                  'This is another paragraph',
                ),
              ),
              ParagraphNode(
                id: "4",
                text: AttributedText(
                  'This is a blockquote',
                ),
                metadata: const {
                  NodeMetadata.blockType: blockquoteAttribution,
                },
              ),
            ],
          ),
          ignoreRules: [
            SpellingIgnoreRules.byBlockType(codeAttribution),
            SpellingIgnoreRules.byBlockType(blockquoteAttribution),
          ],
          spellCheckerService: spellCheckerService,
        );

        // Ensure the spell checker service was queried for the paragraphs but
        // not for the code block or blockquote.
        expect(spellCheckerService.queriedTexts, [
          'This is a paragraph',
          'This is another paragraph',
        ]);
      });

      testWidgetsOnArbitraryDesktop('ignores by pattern', (tester) async {
        final spellCheckerService = _FakeSpellChecker();

        await _pumpTestApp(
          tester,
          document: MutableDocument(
            nodes: [
              ParagraphNode(
                id: Editor.createNodeId(),
                text: AttributedText(
                  'An user @mention and @another one',
                ),
              ),
            ],
          ),
          ignoreRules: [
            // Ignores user mentions, like "@mention".
            SpellingIgnoreRules.byPattern(RegExp(r'@\w+')),
          ],
          spellCheckerService: spellCheckerService,
        );

        // Ensure the spell checker service was queried without the text
        // that matches the pattern.
        expect(spellCheckerService.queriedTexts, ['An user          and          one']);
      });

      testWidgetsOnArbitraryDesktop('ignores by attribution', (tester) async {
        final spellCheckerService = _FakeSpellChecker();

        await _pumpTestApp(
          tester,
          document: MutableDocument(
            nodes: [
              ParagraphNode(
                id: Editor.createNodeId(),
                text: AttributedText(
                  'A bold text and another bold text',
                  AttributedSpans(
                    attributions: [
                      // First "bold" word.
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 2,
                        markerType: SpanMarkerType.start,
                      ),
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 5,
                        markerType: SpanMarkerType.end,
                      ),
                      // Second "bold" word.
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 24,
                        markerType: SpanMarkerType.start,
                      ),
                      const SpanMarker(
                        attribution: boldAttribution,
                        offset: 27,
                        markerType: SpanMarkerType.end,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ignoreRules: [
            SpellingIgnoreRules.byAttribution(boldAttribution),
          ],
          spellCheckerService: spellCheckerService,
        );

        // Ensure the spell checker service was queried without the text
        // that contains the bold attribution.
        expect(spellCheckerService.queriedTexts, ['A      text and another      text']);
      });

      testWidgetsOnArbitraryDesktop('ignores by attribution filter', (tester) async {
        final spellCheckerService = _FakeSpellChecker();

        await _pumpTestApp(
          tester,
          document: MutableDocument(
            nodes: [
              ParagraphNode(
                id: Editor.createNodeId(),
                text: AttributedText(
                  'A link and another link',
                  AttributedSpans(
                    attributions: [
                      // First link.
                      const SpanMarker(
                        attribution: LinkAttribution('https://www.google.com'),
                        offset: 2,
                        markerType: SpanMarkerType.start,
                      ),
                      const SpanMarker(
                        attribution: LinkAttribution('https://www.google.com'),
                        offset: 5,
                        markerType: SpanMarkerType.end,
                      ),
                      // Second link.
                      const SpanMarker(
                        attribution: LinkAttribution('https://www.youtube.com'),
                        offset: 19,
                        markerType: SpanMarkerType.start,
                      ),
                      const SpanMarker(
                        attribution: LinkAttribution('https://www.youtube.com'),
                        offset: 22,
                        markerType: SpanMarkerType.end,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ignoreRules: [
            SpellingIgnoreRules.byAttributionFilter((attribution) => attribution is LinkAttribution),
          ],
          spellCheckerService: spellCheckerService,
        );

        // Ensure the spell checker service was queried without the text
        // that contains the link attribution.
        expect(spellCheckerService.queriedTexts, ['A      and another     ']);
      });

      testWidgetsOnArbitraryDesktop('allows overlapping rules', (tester) async {
        final spellCheckerService = _FakeSpellChecker();

        await _pumpTestApp(
          tester,
          document: MutableDocument(
            nodes: [
              ParagraphNode(
                id: Editor.createNodeId(),
                text: AttributedText(
                  'The first text and the second text',
                ),
              ),
            ],
          ),
          ignoreRules: [
            (TextNode node) {
              // The first text and the second text
              //          ^^^^^^^^
              return const [TextRange(start: 10, end: 18)];
            },
            // The first text and the second text
            //               ^^^^^^^^^^^^^^
            (TextNode node) {
              return const [TextRange(start: 15, end: 29)];
            }
          ],
          spellCheckerService: spellCheckerService,
        );

        // Ensure the spell checker service was queried without the text
        // of the overlapping ranges.
        expect(spellCheckerService.queriedTexts, ['The first                     text']);
      });
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required MutableDocument document,
  List<SpellingIgnoreRule> ignoreRules = const [],
  SpellCheckService? spellCheckerService,
}) async {
  final editor = createDefaultDocumentEditor(
    document: document,
    composer: MutableDocumentComposer(),
  );

  final plugin = SpellingAndGrammarPlugin(
    ignoreRules: ignoreRules,
    spellCheckService: spellCheckerService,
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
