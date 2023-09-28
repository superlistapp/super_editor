import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("SuperEditor switching between multiple editors", () {
    testWidgetsOnAllPlatforms("selected editor is visible after switching from a different editor", (tester) async {
      await tester.pumpWidget(const _SwitchDocumentDemo());

      // Ensure that the first documents content is visible.
      expect(SuperEditorInspector.findWidgetForComponent<TextComponent>("Document1_Header"), isNotNull);
      expect(SuperEditorInspector.findWidgetForComponent<TextComponent>("Document1_Para"), isNotNull);

      // Switch to the second document.
      await tester.tap(find.byKey(const ValueKey("Document2")));
      await tester.pump();

      // Ensure that the second documents content is visible.
      expect(SuperEditorInspector.findWidgetForComponent<TextComponent>("Document2_Header"), isNotNull);
      expect(SuperEditorInspector.findWidgetForComponent<TextComponent>("Document2_Para"), isNotNull);
    });

    testWidgetsOnAllPlatforms("restores selection when switching back to a previously selected editor", (tester) async {
      const docSelection1 = DocumentSelection(
        base: DocumentPosition(
          nodeId: "Document1_Header",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "Document1_Para",
          nodePosition: TextNodePosition(offset: 10),
        ),
      );
      final composer1 = MutableDocumentComposer(
        initialSelection: docSelection1,
      );

      const docSelection2 = DocumentSelection(
        base: DocumentPosition(
          nodeId: "Document2_Header",
          nodePosition: TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: "Document2_Para",
          nodePosition: TextNodePosition(offset: 5),
        ),
      );
      final composer2 = MutableDocumentComposer(
        initialSelection: docSelection2,
      );

      await tester.pumpWidget(_SwitchDocumentDemo(
        composer1: composer1,
        composer2: composer2,
      ));

      // Switch to the second document.
      await tester.tap(find.byKey(const ValueKey("Document2")));
      await tester.pump();

      // Ensure that the original selection is maintained for the second document.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        docSelection2,
      );

      await tester.tap(find.byKey(const ValueKey("Document1")));
      await tester.pump();

      // Ensure that the original selection is maintained for the first document.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        docSelection1,
      );
    });

    testWidgetsOnDesktop("the user can select content after switching to a different editor", (tester) async {
      await tester.pumpWidget(const _SwitchDocumentDemo());

      // Switch to the second document.
      await tester.tap(find.byKey(const ValueKey("Document2")));
      await tester.pump();

      final document = SuperEditorInspector.findDocument()!;
      final header = document.getNodeById("Document2_Header") as ParagraphNode;
      final paragraph = document.getNodeById("Document2_Para") as ParagraphNode;

      // Change the selection on the second document.
      await tester.dragSelectDocumentFromPositionByOffset(
        from: DocumentPosition(
          nodeId: header.id,
          nodePosition: header.beginningPosition,
        ),
        delta: const Offset(0, 400),
      );

      // Ensure that the selection was changed.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: header.id,
            nodePosition: header.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: paragraph.id,
            nodePosition: paragraph.endPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop("the user can edit content in the selected editor after switching from a different editor",
        (tester) async {
      await tester.pumpWidget(
        _SwitchDocumentDemo(
          composer2: MutableDocumentComposer(
            initialSelection: const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "Document2_Header",
                nodePosition: TextNodePosition(offset: "Document #2".length),
              ),
            ),
          ),
        ),
      );

      // Enable the SuperEditor.
      await tester.placeCaretInParagraph("Document1_Header", 0);

      // Switch to the second document.
      await tester.tap(find.byKey(const ValueKey("Document2")));
      await tester.pump();

      await tester.pressBackspace();

      // Ensure that the text was edited upon pressing backspace.
      expect(
        SuperEditorInspector.findTextInParagraph("Document2_Header").text,
        "Document #",
      );

      await tester.typeImeText("Edit");

      // Ensure that the text was inserted into the paragraph.
      expect(
        SuperEditorInspector.findTextInParagraph("Document2_Header").text,
        "Document #Edit",
      );
    });
  });
}

/// Demo of an [SuperEditor] widget where the [DocumentEditor] changes.
///
/// This demo ensures that [SuperEditor] state resets where appropriate
/// when its content is replaced.
class _SwitchDocumentDemo extends StatefulWidget {
  const _SwitchDocumentDemo({
    Key? key,
    this.composer1,
    this.composer2,
  }) : super(key: key);

  final MutableDocumentComposer? composer1;
  final MutableDocumentComposer? composer2;

  @override
  State<_SwitchDocumentDemo> createState() => _SwitchDocumentDemoState();
}

class _SwitchDocumentDemoState extends State<_SwitchDocumentDemo> {
  late MutableDocument _doc1;
  late MutableDocumentComposer _composer1;
  late Editor _docEditor1;

  late MutableDocument _doc2;
  late MutableDocumentComposer _composer2;
  late Editor _docEditor2;

  late Document _activeDocument;
  late DocumentComposer _activeComposer;
  late Editor _activeDocumentEditor;

  @override
  void initState() {
    super.initState();
    _doc1 = _createDocument1();
    _composer1 = widget.composer1 ?? MutableDocumentComposer();
    _docEditor1 = createDefaultDocumentEditor(document: _doc1, composer: _composer1);

    _doc2 = _createDocument2();
    _composer2 = widget.composer2 ?? MutableDocumentComposer();
    _docEditor2 = createDefaultDocumentEditor(document: _doc2, composer: _composer2);

    _activeDocument = _doc1;
    _activeComposer = _composer1;
    _activeDocumentEditor = _docEditor1;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            _buildDocSelector(),
            Expanded(
              child: SuperEditor(
                editor: _activeDocumentEditor,
                document: _activeDocument,
                composer: _activeComposer,
                stylesheet: defaultStylesheet.copyWith(
                  documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          key: const ValueKey("Document1"),
          onPressed: () {
            setState(() {
              _activeDocument = _doc1;
              _activeComposer = _composer1;
              _activeDocumentEditor = _docEditor1;
            });
          },
          child: const Text('Document 1'),
        ),
        const SizedBox(width: 24),
        TextButton(
          key: const ValueKey("Document2"),
          onPressed: () {
            setState(() {
              _activeDocument = _doc2;
              _activeComposer = _composer2;
              _activeDocumentEditor = _docEditor2;
            });
          },
          child: const Text('Document 2'),
        ),
      ],
    );
  }
}

MutableDocument _createDocument1() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "Document1_Header",
        text: AttributedText('Document #1'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: "Document1_Para",
        text: AttributedText(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
    ],
  );
}

MutableDocument _createDocument2() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "Document2_Header",
        text: AttributedText('Document #2'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: "Document2_Para",
        text: AttributedText(
          'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.',
        ),
      ),
    ],
  );
}
