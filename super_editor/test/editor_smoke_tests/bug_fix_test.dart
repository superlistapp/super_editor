import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Bug fix", () {
    group("429 - delete multiple new nodes", () {
      testWidgets("bug repro", (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText(text: "")),
          ],
        );
        final editor = DocumentEditor(document: document);
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: editor,
                composer: composer,
                gestureMode: DocumentGestureMode.mouse,
                inputSource: DocumentInputSource.keyboard,
              ),
            ),
          ),
        );
        await tester.tap(find.byType(SuperEditor));
        await tester.pumpAndSettle();

        // Create a couple new nodes.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Select the new nodes.
        composer.selection = DocumentSelection(
          base: DocumentPosition(
            nodeId: document.nodes[2].id,
            nodePosition: document.nodes[2].endPosition,
          ),
          extent: DocumentPosition(
            nodeId: document.nodes[1].id,
            nodePosition: document.nodes[1].beginningPosition,
          ),
        );
        await tester.pumpAndSettle();

        // Delete the new nodes.
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        // Bug #429 - the deletion threw an error due to a selection
        // type mismatch.
        expect(document.nodes.length, 2);
        expect(composer.selection!.isCollapsed, true);
        expect(
          composer.selection!.extent,
          DocumentPosition(
            nodeId: document.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        );
      });

      testWidgets("related to bug", (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText(text: "")),
          ],
        );
        final editor = DocumentEditor(document: document);
        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SuperEditor(
                editor: editor,
                composer: composer,
                gestureMode: DocumentGestureMode.mouse,
                inputSource: DocumentInputSource.keyboard,
              ),
            ),
          ),
        );
        await tester.tap(find.byType(SuperEditor));
        await tester.pumpAndSettle();

        // Create a couple new nodes.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Select the new nodes.
        composer.selection = DocumentSelection(
          base: DocumentPosition(
            nodeId: document.nodes[1].id,
            nodePosition: document.nodes[1].beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: document.nodes[2].id,
            nodePosition: document.nodes[2].endPosition,
          ),
        );
        await tester.pumpAndSettle();

        // Delete the new nodes.
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        // The bug was a problem with an expanded upstream selection.
        // Here we make sure that deleting an expanded downstream
        // selection works, too.
        expect(document.nodes.length, 2);
        expect(composer.selection!.isCollapsed, true);
        expect(
          composer.selection!.extent,
          DocumentPosition(
            nodeId: document.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        );
      });
    });
  });
}
