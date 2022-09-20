import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'example_document.dart';

class SuperDocumentDemo extends StatefulWidget {
  const SuperDocumentDemo({Key? key}) : super(key: key);

  @override
  State<SuperDocumentDemo> createState() => _SuperDocumentDemoState();
}

class _SuperDocumentDemoState extends State<SuperDocumentDemo> {
  late final Document _document;

  @override
  void initState() {
    super.initState();
    _document = createInitialDocument();
  }

  @override
  Widget build(BuildContext context) {
    return SuperDocument(
      document: _document,
    );
  }
}
