import 'package:example/demos/example_editor/_example_document.dart';
import 'package:example/demos/example_editor/example_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

/// A demo of a [SuperEditor] experience.
///
/// This demo only shows a single, typical [SuperEditor]. To see a variety of
/// demos, see the main demo experience in this project.
void main() {
  initLoggers(Level.FINEST, {
    // editorScrollingLog,
    // editorGesturesLog,
    // longPressSelectionLog,
    // editorImeLog,
    // editorImeDeltasLog,
    // editorIosFloatingCursorLog,
    // editorKeyLog,
    // editorOpsLog,
    // editorLayoutLog,
    // editorDocLog,
    // editorStyleLog,
    // textFieldLog,
    // editorUserTagsLog,
    // contentLayersLog,
  });

  runApp(
    MaterialApp(
      home: Scaffold(
        body: ExampleEditor(),
      ),
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    ),
  );
}

class _StandardEditor extends StatefulWidget {
  const _StandardEditor();

  @override
  State<_StandardEditor> createState() => _StandardEditorState();
}

class _StandardEditorState extends State<_StandardEditor> {
  final GlobalKey _docLayoutKey = GlobalKey();

  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  late FocusNode _editorFocusNode;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _doc = createInitialDocument();
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    _editorFocusNode = FocusNode();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editorFocusNode.dispose();
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditor(
      editor: _docEditor,
      document: _doc,
      composer: _composer,
      focusNode: _editorFocusNode,
      scrollController: _scrollController,
      documentLayoutKey: _docLayoutKey,
    );
  }
}
