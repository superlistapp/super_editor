import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// An empty document.
///
/// This demo allows us to verify conditions related to empty content:
///  - the layout doesn't throw errors when content is empty
///  - the layout doesn't contract to zero when content is empty
///  - tapping anywhere will place the caret when there's no content
///
/// This demo can also be used to quickly hack experiments and tests.
class EmptyDocumentDemo extends StatefulWidget {
  @override
  State<EmptyDocumentDemo> createState() => _EmptyDocumentDemoState();
}

class _EmptyDocumentDemoState extends State<EmptyDocumentDemo> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = MutableDocument.empty("1");
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SuperEditor(
        editor: _docEditor,
        gestureMode: DocumentGestureMode.mouse,
      ),
    );
  }
}
