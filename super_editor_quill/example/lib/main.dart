import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web';

import 'package:flutter/material.dart';
import 'package:super_editor_quill/super_editor_quill.dart';
import 'package:super_editor_quill_example/js_glue.dart';

String _quillEditorDomId(int counter) => 'quill-editor-$counter';
const _jsGlue = JsGlue();

void main() {
  platformViewRegistry.registerViewFactory(
    'quill-editor',
    (counter) => html.DivElement()..id = _quillEditorDomId(counter),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quill <-> SuperEditor Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Quill <-> SuperEditor Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  final _deltaChangeLog = <(Delta, Delta?)>[];
  var _initialized = false;
  var _applyingQuillChange = false;
  var _applyingSuperEditorChange = false;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument();
    final listener = DeltaDocumentChangeListener(
      peekAtDocument: () => _document,
      onDeltaChangeDetected: (delta) {
        if (!_initialized) return;
        setState(() {
          _deltaChangeLog.add((_deltaChangeLog.last.$1.compose(delta), delta));
        });
        _jsGlue.updateQuillContents(delta);
      },
    );

    _document.addListener((changeLog) {
      if (_initialized && _applyingQuillChange) return;
      _applyingSuperEditorChange = true;
      listener(changeLog);
      _applyingSuperEditorChange = false;
    });

    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [...defaultRequestHandlers],
      reactionPipeline: [...defaultEditorReactions],
    );
  }

  @override
  void dispose() {
    _document.dispose();
    _composer.dispose();
    _editor.dispose();
    super.dispose();
  }

  void _handleQuillContents(Delta contents) {
    if (_applyingSuperEditorChange) return;
    _applyingQuillChange = true;
    const DeltaApplier().apply(_editor, contents);
    _applyingQuillChange = false;
    _initialized = true;

    setState(() {
      _deltaChangeLog.add((contents, null));
    });
  }

  void _handleQuillTextChanged(Delta document, Delta change) {
    if (_applyingSuperEditorChange) return;
    _applyingQuillChange = true;
    const DeltaApplier().apply(_editor, change);
    _applyingQuillChange = false;

    setState(() {
      _deltaChangeLog.add((document, change));
    });
  }

  void _handlePlatformViewCreated(int counter) {
    _jsGlue
      ..setInitialQuillContentsChangedListener(
        _handleQuillContents,
      )
      ..setQuillTextChangedListener(
        _handleQuillTextChanged,
      )
      ..initializeQuillEditor(
        _quillEditorDomId(counter),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Row(
        children: [
          Flexible(
            flex: 1,
            child: Column(
              children: [
                Flexible(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0)
                            .subtract(const EdgeInsets.only(bottom: 8)),
                        child: const Text('SuperEditor'),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                          ),
                          child: SuperEditor(
                            autofocus: false,
                            editor: _editor,
                            document: _document,
                            composer: _composer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('QuillJS Editor'),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          child: HtmlElementView(
                            viewType: 'quill-editor',
                            onPlatformViewCreated: _handlePlatformViewCreated,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              separatorBuilder: (context, index) {
                return Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black12,
                );
              },
              itemCount: _deltaChangeLog.length,
              itemBuilder: (context, index) {
                final log = _deltaChangeLog.reversed.toList();
                final document = log[index].$1;
                final delta = log[index].$2;
                return ListTile(
                  leading: Text('#${_deltaChangeLog.length - index - 1}'),
                  title: delta != null
                      ? Text('change: ${jsonEncode(delta.toJson())}')
                      : const Text('document opened'),
                  subtitle:
                      Text('document state: ${jsonEncode(document.toJson())}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
