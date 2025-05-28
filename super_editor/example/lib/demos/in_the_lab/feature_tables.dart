import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class TablesDemo extends StatefulWidget {
  const TablesDemo({super.key});

  @override
  State<TablesDemo> createState() => _TablesDemoState();
}

class _TablesDemoState extends State<TablesDemo> {
  late final Editor _editor;

  @override
  void initState() {
    print("Tables demo initState");
    super.initState();

    _editor = createDefaultDocumentEditor(
      document: _createInitialDocument(),
      composer: MutableDocumentComposer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Building Table Demo");
    return InTheLabScaffold(
      content: SuperEditor(
        editor: _editor,
        stylesheet: defaultStylesheet.copyWith(
          addRulesAfter: darkModeStyles,
        ),
        documentOverlayBuilders: [
          DefaultCaretOverlayBuilder(
            caretStyle: const CaretStyle().copyWith(color: Colors.redAccent),
          ),
        ],
        componentBuilders: [
          const TableComponentBuilder(),
          ...defaultComponentBuilders,
        ],
      ),
    );
  }
}

MutableDocument _createInitialDocument() {
  print("Creating initial document");
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText("Tables"),
        metadata: {
          NodeMetadata.blockType: header1Attribution,
        },
      ),
      TableNode.sparse(
        "2",
        {
          (row: 0, col: 0): TableCellNode(
            "3",
            [],
          ),
          (row: 0, col: 1): TableCellNode(
            "4",
            [],
          ),
          (row: 0, col: 2): TableCellNode(
            "5",
            [],
          ),
        },
      ),
    ],
  );
}
