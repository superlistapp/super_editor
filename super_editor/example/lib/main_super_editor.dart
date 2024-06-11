import 'package:example/demos/example_editor/_example_document.dart';
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
        body: _Demo(),
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

class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  @override
  void initState() {
    super.initState();
    _document = createInitialDocument();
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _document, composer: _composer);
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StandardEditor(
            document: _document,
            composer: _composer,
            editor: _docEditor,
          ),
        ),
        _buildToolbar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorHistoryPanel(editor: _docEditor),
        Container(
          width: 24,
          height: double.infinity,
          color: const Color(0xFF2F2F2F),
          child: Column(),
        ),
      ],
    );
  }
}

class _EditorHistoryPanel extends StatefulWidget {
  const _EditorHistoryPanel({
    required this.editor,
  });

  final Editor editor;

  @override
  State<_EditorHistoryPanel> createState() => _EditorHistoryPanelState();
}

class _EditorHistoryPanelState extends State<_EditorHistoryPanel> {
  final _scrollController = ScrollController();
  late EditListener _editListener;

  @override
  void initState() {
    super.initState();

    _editListener = FunctionalEditListener(_onEditorChange);
    widget.editor.addListener(_editListener);
  }

  @override
  void didUpdateWidget(_EditorHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editor != oldWidget.editor) {
      oldWidget.editor.removeListener(_editListener);
      widget.editor.addListener(_editListener);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.editor.removeListener(_editListener);
    super.dispose();
  }

  void _onEditorChange(changes) {
    setState(() {
      // Build the latest list of changes.
    });

    // Always scroll to bottom of transaction list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.position.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
      ),
      child: Container(
        width: 300,
        height: double.infinity,
        color: const Color(0xFF333333),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                for (final history in widget.editor.history)
                  ListTile(
                    title: Text("${history.changes.length} changes"),
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                    ),
                    subtitle: Text("${history.changes.map((event) => event.describe()).join("\n")}"),
                    subtitleTextStyle: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      height: 1.4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandardEditor extends StatefulWidget {
  const _StandardEditor({
    required this.document,
    required this.composer,
    required this.editor,
  });

  final MutableDocument document;
  final MutableDocumentComposer composer;
  final Editor editor;

  @override
  State<_StandardEditor> createState() => _StandardEditorState();
}

class _StandardEditorState extends State<_StandardEditor> {
  final GlobalKey _docLayoutKey = GlobalKey();

  late FocusNode _editorFocusNode;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditor(
      editor: widget.editor,
      document: widget.document,
      composer: widget.composer,
      focusNode: _editorFocusNode,
      scrollController: _scrollController,
      documentLayoutKey: _docLayoutKey,
      stylesheet: defaultStylesheet.copyWith(
        addRulesAfter: [
          taskStyles,
        ],
      ),
      componentBuilders: [
        TaskComponentBuilder(widget.editor),
        ...defaultComponentBuilders,
      ],
    );
  }
}
