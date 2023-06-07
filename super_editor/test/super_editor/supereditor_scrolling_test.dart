import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("SuperEditor scrolling", () {
    testWidgetsOnArbitraryDesktop('scrolls document when dragging using the trackpad (downstream)', (tester) async {
      final scrollController = ScrollController();
      await tester
          .createDocument() //
          .withLongTextContent()
          .withEditorSize(const Size(300, 300))
          .withScrollController(scrollController)
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final firstParagraph = document.nodes.first as ParagraphNode;

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: firstParagraph.id,
          nodePosition: firstParagraph.beginningPosition,
        ),
        startAlignmentWithinPosition: Alignment.topLeft,
        deviceKind: PointerDeviceKind.trackpad,
      );

      // Move a distance big enough to ensure a pan gesture.
      await dragGesture.moveBy(const Offset(0, kPanSlop));
      await tester.pump();

      // Drag up.
      await dragGesture.moveBy(const Offset(0, -300));
      await tester.pump();

      await tester.endDocumentDragGesture(dragGesture);

      // Ensure the document scrolled down.
      expect(scrollController.offset, greaterThan(0));
    });

    testWidgetsOnArbitraryDesktop('scrolls document when dragging using the trackpad (upstream)', (tester) async {
      final scrollController = ScrollController();
      await tester
          .createDocument() //
          .withLongTextContent()
          .withEditorSize(const Size(300, 300))
          .withScrollController(scrollController)
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final lastParagraph = document.nodes.last as ParagraphNode;

      // Jump to the end of the document
      scrollController.jumpTo(scrollController.position.maxScrollExtent);

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: lastParagraph.id,
          nodePosition: lastParagraph.endPosition,
        ),
        startAlignmentWithinPosition: Alignment.bottomRight,
        deviceKind: PointerDeviceKind.trackpad,
      );

      // Move a distance big enough to ensure a pan gesture.
      await dragGesture.moveBy(const Offset(0, kPanSlop));
      await tester.pump();

      // Drag down.
      await dragGesture.moveBy(const Offset(0, 300));
      await tester.pump();

      await tester.endDocumentDragGesture(dragGesture);

      // Ensure the document scrolled up.
      expect(scrollController.offset, lessThan(scrollController.position.maxScrollExtent));
    });

    testWidgetsOnDesktop("auto-scrolls down", (tester) async {
      const windowSize = Size(800, 600);
      tester.binding.window.physicalSizeTestValue = windowSize;

      await tester //
          .createDocument() //
          .withLongTextContent() //
          .forDesktop() //
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final firstParagraph = document.nodes.first as ParagraphNode;
      final lastParagraph = document.nodes.last as ParagraphNode;

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: firstParagraph.id,
          nodePosition: firstParagraph.beginningPosition,
        ),
        startAlignmentWithinPosition: Alignment.topLeft,
      );
      await dragGesture.moveBy(Offset(windowSize.width - 20, windowSize.height - 20));
      // Pump enough times to scroll all the way to the top.
      // TODO: find a way to scroll as much as possible without pumping an arbitrary number of times
      for (int i = 0; i < 60; i += 1) {
        await tester.pump();
      }
      await tester.endDocumentDragGesture(dragGesture);

      // Ensure that the entire document is selected.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: firstParagraph.id,
            nodePosition: firstParagraph.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: lastParagraph.id,
            nodePosition: lastParagraph.endPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop("auto-scrolls up", (tester) async {
      const windowSize = Size(800, 600);
      tester.binding.window.physicalSizeTestValue = windowSize;

      final docContext = await tester //
          .createDocument() //
          .withLongTextContent() //
          .forDesktop() //
          .pump();

      final document = SuperEditorInspector.findDocument()!;
      final firstParagraph = document.nodes.first as ParagraphNode;
      final lastParagraph = document.nodes.last as ParagraphNode;

      // Place the caret at the end of the document, which causes the editor to
      // scroll to the bottom.
      docContext.editContext.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: lastParagraph.id,
              nodePosition: lastParagraph.endPosition,
            ),
          ),
          SelectionChangeType.place,
          SelectionReason.userInteraction,
        ),
      ]);

      docContext.focusNode.requestFocus();
      await tester.pumpAndSettle();

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: lastParagraph.id,
          nodePosition: lastParagraph.endPosition,
        ),
        startAlignmentWithinPosition: Alignment.bottomRight,
      );
      await dragGesture.moveBy(-Offset(windowSize.width - 20, windowSize.height - 20));
      // Pump enough times to scroll all the way to the top.
      // TODO: find a way to scroll as much as possible without pumping an arbitrary number of times
      for (int i = 0; i < 60; i += 1) {
        await tester.pump();
      }
      await tester.endDocumentDragGesture(dragGesture);

      // Ensure that the entire document is selected.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: lastParagraph.id,
            nodePosition: TextNodePosition(
              offset: lastParagraph.endPosition.offset,
              affinity: TextAffinity.upstream,
            ),
          ),
          extent: DocumentPosition(
            nodeId: firstParagraph.id,
            nodePosition: firstParagraph.beginningPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop("auto-scrolls to caret position", (tester) async {
      const windowSize = Size(800, 600);
      tester.binding.window.physicalSizeTestValue = windowSize;

      final docContext = await tester //
          .createDocument() //
          .withLongTextContent() //
          .forDesktop() //
          .pump();
      final document = SuperEditorInspector.findDocument()!;
      final lastParagraph = document.nodes.last as ParagraphNode;

      // Place the caret at the end of the document, which should cause the
      // editor to scroll to the bottom.
      docContext.editContext.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: lastParagraph.id,
              nodePosition: lastParagraph.endPosition,
            ),
          ),
          SelectionChangeType.place,
          SelectionReason.userInteraction,
        ),
      ]);
      docContext.focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Ensure that the last character in the document is visible.
      expect(
        SuperEditorInspector.isPositionVisibleGlobally(
          DocumentPosition(
            nodeId: lastParagraph.id,
            nodePosition: lastParagraph.endPosition,
          ),
          windowSize,
        ),
        isTrue,
      );
    });

    testWidgetsOnDesktop("doesn't auto-scroll for selection changes that aren't user interactions", (tester) async {
      final scrollController = ScrollController();

      // Pump a editor with a size we know will cause the editor to be scrollable.
      final docContext = await tester //
          .createDocument()
          .withLongTextContent()
          .withEditorSize(const Size(300, 100))
          .withScrollController(scrollController)
          .pump();

      // Select the first paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Place the caret at the last paragraph, simulating an event that wasn't initiated by the user.
      // This paragraph is outside the viewport.
      docContext.editContext.editor.execute([
        const ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '4',
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.place,
          SelectionReason.contentChange,
        ),
      ]);
      await tester.pumpAndSettle();

      // Ensure the editor didn't scroll.
      expect(scrollController.position.pixels, 0.0);
    });

    testWidgetsOnAllPlatforms("doesn't auto-scroll for key presses that don't insert any content", (tester) async {
      final scrollController = ScrollController();

      // Pump an editor with a size we know will cause the editor to be scrollable.
      final docContext = await tester //
          .createDocument()
          .withLongTextContent()
          .withEditorSize(const Size(300, 100))
          .withScrollController(scrollController)
          .pump();

      // Select the first paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Place the caret at the last paragraph, simulating an event that was initiated by the user.
      // We pretend it was initiated by the user because that's what causes an auto-scroll.
      // But the auto-scroll should be smart enough to see that the selection hasn't changed
      // and therefore it shouldn't auto-scroll.
      docContext.editContext.editor.execute([
        const ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.place,
          SelectionReason.userInteraction,
        ),
      ]);
      await tester.pumpAndSettle();

      // Ensure the editor didn't scroll.
      expect(scrollController.position.pixels, 0.0);

      // Press non-content keys.
      await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      // We don't expect anything to happen, but in case something unexpected happens,
      // give the editor whatever time it needs to run the unexpected behavior.
      await tester.pumpAndSettle();

      // Ensure the editor didn't scroll.
      expect(scrollController.position.pixels, 0.0);
    });

    testWidgetsOnArbitraryDesktop("doesn't scroll when dragging over an image", (tester) async {
      const editorSize = Size(300, 300);

      await tester
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: "1",
                  text: AttributedText(text: "First Paragraph"),
                ),
                ParagraphNode(
                  id: "2",
                  text: AttributedText(text: "Second Paragraph"),
                ),
                ImageNode(
                  id: "img-node",
                  imageUrl: 'https://this.is.a.fake.image',
                  metadata: const SingleColumnLayoutComponentStyles(
                    width: double.infinity,
                  ).toMetadata(),
                ),
              ],
            ),
          )
          .withAddedComponents([const FakeImageComponentBuilder(size: editorSize)])
          .withEditorSize(editorSize)
          .pump();

      // Drag from the second paragraph to the image.
      await tester.dragSelectDocumentFromPositionByOffset(
        from: const DocumentPosition(
          nodeId: '2',
          nodePosition: TextNodePosition(offset: 1),
        ),
        delta: const Offset(0, 50),
      );

      // Ensure the bottom of the image isn't visible.
      expect(
        SuperEditorInspector.isPositionVisibleGlobally(
          const DocumentPosition(
            nodeId: 'img-node',
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
          editorSize,
        ),
        false,
      );
    });

    testWidgetsOnMobile("stops momentum on tap down and doesn't place the caret", (tester) async {
      final scrollController = ScrollController();

      await tester //
          .createDocument() //
          .withLongDoc() //
          .withScrollController(scrollController) //
          .pump();

      // Ensure the editor initially has no selection.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);

      // Fling scroll the editor.
      await tester.fling(find.byType(SuperEditor), const Offset(0.0, -1000), 1000);

      // Pump a few frames of momentum.
      for (int i = 0; i < 25; i += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrollOffsetInMiddleOfMomentum = scrollController.offset;

      // Tap to stop the momentum.
      await tester.tap(find.byType(SuperEditor));

      // Let any remaining momentum run (there shouldn't be any).
      await tester.pumpAndSettle();

      // Ensure that the momentum stopped exactly where we tapped.
      expect(scrollOffsetInMiddleOfMomentum, scrollController.offset);

      // Ensure that tapping on the editor didn't place the caret.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);
    });
  });
}
