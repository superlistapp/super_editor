import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  runApp(_SuperEditorSpellcheckPluginApp());
}

class _SuperEditorSpellcheckPluginApp extends StatefulWidget {
  @override
  State<_SuperEditorSpellcheckPluginApp> createState() => _SuperEditorSpellcheckPluginAppState();
}

class _SuperEditorSpellcheckPluginAppState extends State<_SuperEditorSpellcheckPluginApp> {
  var _brightness = Brightness.light;

  void _toggleBrightness() {
    setState(() {
      _brightness = _brightness == Brightness.light ? Brightness.dark : Brightness.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: _brightness,
      ),
      home: SafeArea(
        child: Stack(
          children: [
            const _SuperEditorSpellcheckScreen(),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: _buildToolbar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return SizedBox(
      width: 48,
      child: Column(
        children: [
          const Spacer(),
          IconButton(
            onPressed: _toggleBrightness,
            icon: Icon(_brightness == Brightness.light ? Icons.dark_mode : Icons.light_mode),
          ),
        ],
      ),
    );
  }
}

class _SuperEditorSpellcheckScreen extends StatefulWidget {
  const _SuperEditorSpellcheckScreen();

  @override
  State<_SuperEditorSpellcheckScreen> createState() => _SuperEditorSpellcheckScreenState();
}

class _SuperEditorSpellcheckScreenState extends State<_SuperEditorSpellcheckScreen> {
  late final Editor _editor;
  late final SpellingAndGrammarPlugin _spellingAndGrammarPlugin;

  late final SuperEditorIosControlsController _iosControlsController;
  late final SuperEditorAndroidControlsController _androidControlsController;

  @override
  void initState() {
    super.initState();

    _iosControlsController = SuperEditorIosControlsController();
    _androidControlsController = SuperEditorAndroidControlsController();

    _spellingAndGrammarPlugin = SpellingAndGrammarPlugin(
      iosControlsController: _iosControlsController,
      androidControlsController: _androidControlsController,
      ignoreRules: [
        SpellingIgnoreRules.byAttribution(boldAttribution),
        SpellingIgnoreRules.byAttributionFilter((attr) => attr is LinkAttribution),
        SpellingIgnoreRules.byPattern(RegExp(r'#\w+')),
      ],
    );

    _editor = createDefaultDocumentEditor(
      document: MutableDocument(
        // Start the document with some misspelled content to ensure pre-existing
        // content is analyzed and styled.
        nodes: [
          ParagraphNode(id: "1", text: AttributedText("Tihs is mipelled")),
          ParagraphNode(id: "2", text: AttributedText()),
        ],
      ),
      composer: MutableDocumentComposer(),
    );

    _insertMisspelledText();
  }

  @override
  void dispose() {
    _iosControlsController.dispose();
    _androidControlsController.dispose();
    super.dispose();
  }

  void _insertMisspelledText() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editor.execute([
        InsertTextRequest(
          documentPosition: DocumentPosition(
            nodeId: _editor.context.document.last.id,
            nodePosition: _editor.context.document.last.beginningPosition,
          ),
          textToInsert:
              'Flutter is a populr framework developd by Google for buildng natively compilid applications for mobil, web, and desktop from a single code base. Its hot reload featur allows developers to see the changes they make in real-time without havng to restart the app, which can greatly sped up the development proccess. With a rich set of widgets and a customizble UI, Flutter makes it easy to creat beautiful and performant apps quickly.',
          attributions: {},
        ),
      ]);
      _editor.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: _editor.context.document.last.id,
          newNode: ParagraphNode(id: Editor.createNodeId(), text: AttributedText('')),
        )
      ]);
      _editor.execute([
        InsertAttributedTextRequest(
          DocumentPosition(
            nodeId: _editor.context.document.last.id,
            nodePosition: _editor.context.document.last.endPosition,
          ),
          AttributedText(
            'The spellchecking can be configured to ignore spelling errors for some situation, like links: https://www.populr.com, '
            'tags: #framwork, or text with specific attributions, like bold attbution.',
            AttributedSpans(
              attributions: [
                const SpanMarker(
                  attribution: LinkAttribution('https://www.populr.com'),
                  offset: 94,
                  markerType: SpanMarkerType.start,
                ),
                const SpanMarker(
                  attribution: LinkAttribution('https://www.populr.com'),
                  offset: 115,
                  markerType: SpanMarkerType.end,
                ),
                const SpanMarker(
                  attribution: PatternTagAttribution(),
                  offset: 124,
                  markerType: SpanMarkerType.start,
                ),
                const SpanMarker(
                  attribution: PatternTagAttribution(),
                  offset: 132,
                  markerType: SpanMarkerType.end,
                ),
                const SpanMarker(
                  attribution: boldAttribution,
                  offset: 176,
                  markerType: SpanMarkerType.start,
                ),
                const SpanMarker(
                  attribution: boldAttribution,
                  offset: 189,
                  markerType: SpanMarkerType.end,
                ),
              ],
            ),
          ),
        )
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SuperEditorAndroidControlsScope(
        controller: _androidControlsController,
        child: SuperEditorIosControlsScope(
          controller: _iosControlsController,
          child: SuperEditor(
            autofocus: true,
            editor: _editor,
            stylesheet: defaultStylesheet.copyWith(
              inlineTextStyler: (attributions, existingStyle) {
                TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

                if (attributions.whereType<PatternTagAttribution>().isNotEmpty) {
                  style = style.copyWith(
                    color: Colors.orange,
                  );
                }

                return style;
              },
              addRulesAfter: [
                if (Theme.of(context).brightness == Brightness.dark) ..._darkModeStyles,
              ],
            ),
            plugins: {
              _spellingAndGrammarPlugin,
            },
          ),
        ),
      ),
    );
  }
}

// Makes text light, for use during dark mode styling.
final _darkModeStyles = [
  StyleRule(
    BlockSelector.all,
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Color(0xFFCCCCCC),
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header1"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Color(0xFF888888),
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header2"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Color(0xFF888888),
        ),
      };
    },
  ),
];
