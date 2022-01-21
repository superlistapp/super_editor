import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

// TODO: Create a fake keyboard that operates at the system channel level
//       - typeCharacter('m')
//       - enter()
//       - backspace()
//       - delete()
//       - etc.
void main() {
  group('Editor smoke tests', () {
    testWidgets('document entry', (tester) async {
      final documentEditor = DocumentEditor(
        document: MutableDocument(
          nodes: [
            ParagraphNode(
              id: DocumentEditor.createNodeId(),
              text: AttributedText(text: ''),
              metadata: {'blockType': header1Attribution},
            ),
          ],
        ),
      );
      final composer = DocumentComposer();
      final layoutKey = GlobalKey();
      DocumentLayout documentLayoutResolver() => layoutKey.currentState as DocumentLayout;
      final commonOps = CommonEditorOperations(
        editor: documentEditor,
        composer: composer,
        documentLayoutResolver: documentLayoutResolver,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: documentEditor,
              composer: composer,
              documentLayoutKey: layoutKey,
              gestureMode: DocumentGestureMode.mouse,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      composer.selection = DocumentSelection.collapsed(
          position: DocumentPosition(
        nodeId: documentEditor.document.nodes.first.id,
        nodePosition: const TextNodePosition(offset: 0),
      ));

      const header = 'Smoke Test';
      for (final character in header.characters) {
        commonOps.insertCharacter(character);
      }

      commonOps.insertBlockLevelNewline();

      const p1 =
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id.';
      for (final character in p1.characters) {
        commonOps.insertCharacter(character);
      }
      // TODO: the selection is nulled out to get rid of the blinking caret.
      //       Add code to the caret painter that prevents animation running in
      //       debug mode.
      composer.selection = null;
      await tester.pumpAndSettle();

      // Print statements are for debugging until we have a useful document
      // comparison matcher to show what doesn't match.
      // print('Actual document:');
      // for (final node in documentEditor.document.nodes) {
      //   print(' - $node');
      // }
      // print('------------');
      // print('Expected document:');
      // for (final node in expectedDocument.nodes) {
      //   print(' - $node');
      // }

      expect(documentEditor.document.hasEquivalentContent(expectedDocument), true);
    });
  });
}

final expectedDocument = MutableDocument(nodes: [
  ParagraphNode(
    id: '1',
    text: AttributedText(text: 'Smoke Test'),
    metadata: {
      'blockType': header1Attribution,
    },
  ),
  ParagraphNode(
    id: '2',
    text: AttributedText(
      text:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id.',
    ),
  ),
]);
