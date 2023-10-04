import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor mobile selection >", () {
    group("Android >", () {
      group("long press >", () {
        testWidgetsOnAndroid("selects word under finger", (tester) async {
          await tester
              .createDocument()
              // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
              .withSingleParagraph()
              .withAndroidToolbarBuilder((context) => const AndroidTextEditingFloatingToolbar())
              .pump();

          // Ensure that no overlay controls are visible.
          expect(find.byType(AndroidSelectionHandle), findsNothing);
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
          expect(find.byType(AndroidMagnifyingGlass), findsNothing);

          // Long press on the middle of "conse|ctetur"
          await tester.longPressInParagraph("1", 33);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 28),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 39),
              ),
            ),
          );

          // Ensure the drag handles and toolbar are visible, but the magnifier isn't.
          expect(find.byType(AndroidSelectionHandle), findsExactly(2));
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsOne);
          expect(find.byType(AndroidMagnifyingGlass), findsNothing);
        });

        testWidgetsOnAndroid("selects by word when dragging upstream", (tester) async {
          await tester
              .createDocument()
              // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
              .withSingleParagraph()
              .withAndroidToolbarBuilder((context) => const AndroidTextEditingFloatingToolbar())
              .pump();

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          const wordSelection = DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 17),
            ),
          );
          expect(SuperEditorInspector.findDocumentSelection(), wordSelection);

          // Ensure the toolbar is visible, but drag handles and magnifier aren't.
          expect(find.byType(AndroidSelectionHandle), findsNothing);
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsOne);
          expect(find.byType(AndroidMagnifyingGlass), findsNothing);

          // Drag upstream to the end of the previous word.
          // "Lorem ipsu|m dolor sit amet"
          //            ^ position 10
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const upstreamDragDistance = -13.0;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure the original word and upstream word are both selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
            ),
          );

          // Now that we've started dragging, ensure the magnifier is visible and the
          // toolbar is hidden.
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
          expect(find.byType(AndroidMagnifyingGlass), findsOne);

          // Drag back towards the original long-press offset.
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const downstreamDragDistance = 8.0;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(downstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure that only the original word is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                // Note: when we move the selection back the other way, the word calculation
                // decided to include the leading space, which is why we pass a different
                // selection here.
                nodePosition: TextNodePosition(offset: 11),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 17),
              ),
            ),
          );

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();

          // Now that the drag is done, ensure the handles and toolbar are visible and
          // the magnifier isn't.
          expect(find.byType(AndroidSelectionHandle), findsExactly(2));
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsOne);
          expect(find.byType(AndroidMagnifyingGlass), findsNothing);
        });

        testWidgetsOnAndroid("selects by word when dragging downstream", (tester) async {
          await tester
              .createDocument()
              // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
              .withSingleParagraph()
              .withAndroidToolbarBuilder((context) => const AndroidTextEditingFloatingToolbar())
              .pump();

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          const wordSelection = DocumentSelection(
            base: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 12),
            ),
            extent: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 17),
            ),
          );
          expect(SuperEditorInspector.findDocumentSelection(), wordSelection);

          // Ensure the toolbar is visible, but drag handles and magnifier aren't.
          expect(find.byType(AndroidSelectionHandle), findsNothing);
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsOne);
          expect(find.byType(AndroidMagnifyingGlass), findsNothing);

          // Drag downstream to the beginning of the next word.
          // "Lorem ipsum dolor s|it amet"
          //                     ^ position 19
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const downstreamDragDistance = 8.0;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(downstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure the original word and downstream word are both selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 12),
              ),
              extent: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 21),
              ),
            ),
          );

          // Now that we've started dragging, ensure the magnifier is visible and the
          // toolbar is hidden.
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsNothing);
          expect(find.byType(AndroidMagnifyingGlass), findsOne);

          // Drag back towards the original long-press offset.
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const upstreamDragDistance = -3.0;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure that only the original word is selected.
          expect(SuperEditorInspector.findDocumentSelection(), wordSelection);

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
          await tester.pump();

          // Now that the drag is done, ensure the handles and toolbar are visible and
          // the magnifier isn't.
          expect(find.byType(AndroidSelectionHandle), findsExactly(2));
          expect(find.byType(AndroidTextEditingFloatingToolbar), findsOne);
          expect(find.byType(AndroidMagnifyingGlass), findsNothing);
        });
      });
    });
  });
}
