import 'package:example_perf/documents/frankenstein.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class LongDocDemo extends StatefulWidget {
  const LongDocDemo({super.key});

  @override
  State<LongDocDemo> createState() => _LongDocDemoState();
}

class _LongDocDemoState extends State<LongDocDemo> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = MutableDocument(nodes: frankNodes());
    _composer = MutableDocumentComposer();

    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SuperEditor(editor: _docEditor),
    );
  }
}
