import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  runApp(_SuperEditorSpellcheckPluginApp());
}

class _SuperEditorSpellcheckPluginApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: _SuperEditorSpellcheckScreen(),
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
  final _spellingAndGrammarPlugin = SpellingAndGrammarPlugin();

  @override
  void initState() {
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: MutableDocument.empty(),
      composer: MutableDocumentComposer(),
    );

    _insertMisspelledText();
  }

  void _insertMisspelledText() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editor.execute([
        InsertTextRequest(
          documentPosition: DocumentPosition(
            nodeId: _editor.context.document.first.id,
            nodePosition: _editor.context.document.first.beginningPosition,
          ),
          textToInsert:
              'Flutter is a populr framework developd by Google for buildng natively compilid applications for mobil, web, and desktop from a single code base. Its hot reload featur allows developers to see the changes they make in real-time without havng to restart the app, which can greatly sped up the development proccess. With a rich set of widgets and a customizble UI, Flutter makes it easy to creat beautiful and performant apps quickly.',
          attributions: {},
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SuperEditor(
        editor: _editor,
        customStylePhases: [
          _spellingAndGrammarPlugin.styler,
        ],
        plugins: {
          _spellingAndGrammarPlugin,
        },
      ),
    );
  }
}
