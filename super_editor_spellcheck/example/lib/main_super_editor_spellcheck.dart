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
