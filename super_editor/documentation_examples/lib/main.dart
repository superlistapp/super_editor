import 'package:documentation_examples/super_editor/getting_started/getting_started_with_document.dart';
import 'package:documentation_examples/super_reader/getting_started/getting_started_with_document.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DocumentationExamplesApp());
}

class DocumentationExamplesApp extends StatelessWidget {
  const DocumentationExamplesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Documentation Examples',
      home: DocumentationExamplesPage(),
    );
  }
}

class DocumentationExamplesPage extends StatefulWidget {
  const DocumentationExamplesPage({super.key});

  @override
  State<DocumentationExamplesPage> createState() => _DocumentationExamplesPageState();
}

class _DocumentationExamplesPageState extends State<DocumentationExamplesPage> {
  @override
  Widget build(BuildContext context) {
    // return const GettingStartedWithDocumentExample();
    return const GettingStartedExample();
  }
}
