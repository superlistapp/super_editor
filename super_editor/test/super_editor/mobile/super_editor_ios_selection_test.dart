import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor mobile selection >", () {
    group("iOS >", () {
      group("long press >", () {
        testWidgetsOnIos("selects word under finger", (tester) async {
          await _pumpAppWithLongText(tester);

          // Ensure that no overlay controls are visible.
          _expectNoControlsAreVisible();

          // Long press on the middle of "conse|ctetur"
          await tester.longPressInParagraph("1", 33);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(SuperEditorInspector.findDocumentSelection(), _wordConsecteturSelection);

          // Ensure the drag handles and toolbar are visible, but the magnifier isn't.
          _expectHandlesAndToolbar();
        });

        testWidgetsOnIos("does nothing with hack global property", (tester) async {
          disableLongPressSelectionForSuperlist = true;
          addTearDown(() => disableLongPressSelectionForSuperlist = false);

          await _pumpAppWithLongText(tester);

          // Long press down on the middle of "conse|ctetur"
          final gesture = await tester.longPressDownInParagraph("1", 33);
          await tester.pump();

          // Ensure that there's no selection.
          expect(SuperEditorInspector.findDocumentSelection(), isNull);

          // Release the long-press.
          await gesture.up();
          await tester.pump();

          // Ensure that only the caret was placed, rather than an expanded selection due
          // to a long press.
          expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isTrue);
        });

        testWidgetsOnIos("over handle does nothing", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          await tester.longPressInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press near the upstream handle, but just before the selected word.
          await tester.longPressInParagraph("1", 11);
          await tester.pumpAndSettle();

          // Ensure that the selection didn't change.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Long-press near the downstream handle, but just after the selected word.
          await tester.longPressInParagraph("1", 18);
          await tester.pumpAndSettle();

          // Ensure that the selection didn't change.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);
        });

        testWidgetsOnIos("selects by word when dragging upstream and then back downstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Ensure the drag handles and magnifier are visible, but the toolbar isn't.
          _expectHandlesAndMagnifier();

          // Drag upstream to the end of the previous word.
          // "Lorem ipsu|m dolor sit amet"
          //            ^ position 10
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const upstreamDragDistance = -130 / dragIncrementCount;
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

          // Drag back towards the original long-press offset.
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const downstreamDragDistance = 80 / dragIncrementCount;
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
        });

        testWidgetsOnIos("selects by word when dragging downstream and then back upstream", (tester) async {
          await _pumpAppWithLongText(tester);

          // Long press on the middle of "do|lor".
          final gesture = await tester.longPressDownInParagraph("1", 14);
          await tester.pumpAndSettle();

          // Ensure the word was selected.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Ensure the drag handles and magnifier are visible, but the toolbar isn't.
          _expectHandlesAndMagnifier();

          // Drag downstream to the beginning of the next word.
          // "Lorem ipsum dolor s|it amet"
          //                     ^ position 19
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const dragIncrementCount = 10;
          const downstreamDragDistance = 80 / dragIncrementCount;
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

          // Drag back towards the original long-press offset.
          //
          // We do this with manual distances because the attempt to look up character
          // offsets was producing unpredictable results.
          const upstreamDragDistance = -40 / dragIncrementCount;
          for (int i = 0; i < dragIncrementCount; i += 1) {
            await gesture.moveBy(const Offset(upstreamDragDistance, 0));
            await tester.pump();
          }

          // Ensure that only the original word is selected.
          expect(SuperEditorInspector.findDocumentSelection(), _wordDolorSelection);

          // Release the gesture so the test system doesn't complain.
          await gesture.up();
        });
      });
    });

    group('within ancestor scrollable', () {
      testWidgetsOnIos("expands selection when dragging horizontally", (tester) async {
        final testContext = await tester
            .createDocument()
            .fromMarkdown(
              '''
SuperEditor containing a
paragraph that spans 
multiple lines.''',
            )
            .insideCustomScrollView()
            .pump();

        final paragraphNode = testContext.document.nodes.first as ParagraphNode;

        // Double tap to select "SuperEditor".
        await tester.doubleTapInParagraph(paragraphNode.id, 0);

        // Drag from "SuperEdito|r" a distance long enough to go through the entire first line.
        await tester.dragSelectDocumentFromPositionByOffset(
          from: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: const TextNodePosition(offset: 10),
          ),
          delta: const Offset(300, 0),
        );

        // Ensure the first line is selected.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 24),
              ),
            ),
          ),
        );
      });

      testWidgetsOnIos("expands selection when dragging vertically", (tester) async {
        final testContext = await tester
            .createDocument()
            .fromMarkdown(
              '''
SuperEditor containing a
paragraph that spans 
multiple lines.''',
            )
            .insideCustomScrollView()
            .pump();

        final paragraphNode = testContext.document.nodes.first as ParagraphNode;

        // Double tap to select "SuperEditor".
        await tester.doubleTapInParagraph(paragraphNode.id, 0);

        // Drag from "SuperEdito|r" a distance long enough to go to the last line.
        await tester.dragSelectDocumentFromPositionByOffset(
          from: DocumentPosition(
            nodeId: paragraphNode.id,
            nodePosition: const TextNodePosition(offset: 10),
          ),
          delta: const Offset(0, 40),
        );

        // Ensure the selection starts at the beginning and end at "multiple l|ines".
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: paragraphNode.id,
                nodePosition: const TextNodePosition(offset: 57),
              ),
            ),
          ),
        );
      });
    });
  });
}

// The test suite was originally laid out and calculated with:
//  - physical size: 2400x1800
//  - device pixel ratio: 3.0

Future<void> _pumpAppWithLongText(WidgetTester tester) async {
  await tester
      .createDocument()
      // "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod...",
      .withSingleParagraph()
      .withiOSToolbarBuilder((context, mobileToolbarKey, focalPoint) =>
          IOSTextEditingFloatingToolbar(key: mobileToolbarKey, focalPoint: focalPoint))
      .pump();
}

const _wordConsecteturSelection = DocumentSelection(
  base: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 28),
  ),
  extent: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 39),
  ),
);

const _wordDolorSelection = DocumentSelection(
  base: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 12),
  ),
  extent: DocumentPosition(
    nodeId: "1",
    nodePosition: TextNodePosition(offset: 17),
  ),
);

void _expectNoControlsAreVisible() {
  expect(find.byType(IOSSelectionHandle), findsNothing);
  expect(find.byType(IOSTextEditingFloatingToolbar), findsNothing);
  expect(find.byType(IOSRoundedRectangleMagnifyingGlass), findsNothing);
}

void _expectHandlesAndMagnifier() {
  expect(find.byType(IOSSelectionHandle), findsExactly(2));
  expect(find.byType(IOSRoundedRectangleMagnifyingGlass), findsOne);
  expect(find.byType(IOSTextEditingFloatingToolbar), findsNothing);
}

void _expectHandlesAndToolbar() {
  expect(find.byType(IOSSelectionHandle), findsExactly(2));
  expect(find.byType(IOSTextEditingFloatingToolbar), findsOne);
  expect(find.byType(IOSRoundedRectangleMagnifyingGlass), findsNothing);
}
