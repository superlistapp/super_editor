import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:super_editor_markdown/src/markdown_to_document_parsing.dart';

class NotePage extends StatefulWidget {
  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late final Document _document;
  final _selection = ValueNotifier<DocumentSelection?>(null);
  final _selectionLayerLinks = SelectionLayerLinks();

  String exampleMarkdownDoc1 = '''
# Example 1
---
This is an example doc that has various types of nodes, like [links](https://www.youtube.com/shorts/lLlsouEjDCc).

It includes multiple paragraphs, ordered list items, unordered list items, images, and HRs.

 * unordered item 1
 * unordered item 2
   * unordered item 2.1
   * unordered item 2.2
 * unordered item 3

---

 1. ordered item 1
 2. ordered item 2
   1. ordered item 2.1
   2. ordered item 2.2
 3. ordered item 3

---

![Image alt text](https://res.cloudinary.com/demo/basketball_shot.jpg)

- [ ] Pending task
with multiple lines

Another paragraph

- [x] Completed task

---

:---
# Example 1 With Left Alignment
:---:
# Example 1 With Center Alignment
---:
# Example 1 With Right Alignment
-::-
# Example 1 With Justify Alignment

The end!
''';

  @override
  void initState() {
    _document = deserializeMarkdownToDocument(exampleMarkdownDoc1);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Note Page'),
      ),
      body: DismissiblePage(
        minRadius: 0.0,
        onDismissed: () {
          Navigator.of(context).pop();
        },
        direction: DismissiblePageDismissDirection.startToEnd,
        child: Center(
          child: SuperReader(
            document: _document,
            selection: _selection,
            selectionLayerLinks: _selectionLayerLinks,
            documentOverlayBuilders: [],
            selectionStyle: SelectionStyles(
              selectionColor: Colors.transparent,
            ),
            componentBuilders: [
              ...defaultComponentBuilders,
            ],
            androidToolbarBuilder: (_) => AndroidTextEditingFloatingToolbar(
              onCopyPressed: null,
              onSelectAllPressed: null,
            ),
          ),
        ),
      ),
    );
  }
}
