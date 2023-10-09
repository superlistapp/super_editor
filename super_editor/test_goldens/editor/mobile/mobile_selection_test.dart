import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../../test/super_editor/supereditor_test_tools.dart';
import '../../test_tools_goldens.dart';

void main() {
  group('SuperEditor', () {
    group("mobile drag handles", () {
      testGoldensOnAndroid("with caret change colors", (tester) async {
        final testContext = await tester //
            .createDocument() //
            .fromMarkdown("This is some text to select.") //
            .useAppTheme(ThemeData(primaryColor: Colors.red)) //
            .pump();
        final nodeId = testContext.findEditContext().document.nodes.first.id;

        //await tester.placeCaretInParagraph(nodeId, 15);

        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, "supereditor_android_collapsed_handle_color");
      });

      testGoldensOnAndroid("with selection change colors", (tester) async {
        final testContext = await tester //
            .createDocument() //
            .fromMarkdown("This is some text to select.") //
            .useAppTheme(ThemeData(primaryColor: Colors.red)) //
            .pump();
        final nodeId = testContext.findEditContext().document.nodes.first.id;

        await tester.doubleTapInParagraph(nodeId, 15);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile("goldens/supereditor_android_expanded_handle_color.png"),
        );
      });

      testGoldensOniOS("with caret change colors", (tester) async {
        final testContext = await tester //
            .createDocument() //
            .fromMarkdown("This is some text to select.") //
            .useAppTheme(ThemeData(primaryColor: Colors.red)) //
            .pump();
        final nodeId = testContext.findEditContext().document.nodes.first.id;

        await tester.placeCaretInParagraph(nodeId, 15);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile("goldens/supereditor_ios_collapsed_handle_color.png"),
        );
      });

      testGoldensOniOS("with selection change colors", (tester) async {
        final testContext = await tester //
            .createDocument() //
            .fromMarkdown("This is some text to select.") //
            .useAppTheme(ThemeData(primaryColor: Colors.red)) //
            .pump();
        final nodeId = testContext.findEditContext().document.nodes.first.id;

        await tester.doubleTapInParagraph(nodeId, 15);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile("goldens/supereditor_ios_expanded_handle_color.png"),
        );
      });
    });

    group('mobile selection', () {
      group('Android', () {
        _testParagraphSelection(
          'single tap text',
          DocumentGestureMode.android,
          "mobile-selection_android_single-tap-text",
          (tester, docKey, _) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBox = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );

            await tester.tapAt(
              docBox.localToGlobal(characterBox!.center),
            );
            await tester.pumpAndSettle();
          },
        );

        _testParagraphSelection(
          'drag collapsed handle upstream',
          DocumentGestureMode.android,
          "mobile-selection_android_drag-collapsed-upstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 28)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.tapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(AndroidSelectionHandle);
            final handleBox = handleFinder.evaluate().first.renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 28),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag collapsed handle downstream',
          DocumentGestureMode.android,
          "mobile-selection_android_drag-collapsed-downstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 39)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.tapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(AndroidSelectionHandle);
            final handleBox = handleFinder.evaluate().first.renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 39),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'double tap text',
          DocumentGestureMode.android,
          "mobile-selection_android_double-tap-text",
          (tester, docKey, rootWidget) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBox = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBox!.center),
            );
            await tester.pumpAndSettle();

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
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
          },
        );

        _testParagraphSelection(
          'triple tap text',
          DocumentGestureMode.android,
          "mobile-selection_android_trip-tap-text",
          (tester, docKey, _) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBox = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );

            await tester.tripleTapAt(
              docBox.localToGlobal(characterBox!.center),
            );
            await tester.pumpAndSettle();

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 231),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag base handle upstream',
          DocumentGestureMode.android,
          "mobile-selection_android_drag-base-upstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 28)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 22)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );

            await tester.pumpAndSettle();

            final handleFinder = find.byType(AndroidSelectionHandle);
            final handleBox = handleFinder.evaluate().first.renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 22),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 39),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag extent handle upstream',
          DocumentGestureMode.android,
          "mobile-selection_android_drag-extent-upstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 38)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 30)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(AndroidSelectionHandle);
            final handleBox = handleFinder.evaluate().elementAt(1).renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 28),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 31, affinity: TextAffinity.upstream),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag extent handle downstream',
          DocumentGestureMode.android,
          "mobile-selection_android_drag-extent-downstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 38)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 44)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(AndroidSelectionHandle);
            final handleBox = handleFinder.evaluate().elementAt(1).renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 28),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 45),
                ),
              ),
            );
          },
        );
      });

      group('iOS', () {
        _testParagraphSelection(
          'single tap text',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_single-tap-text",
          (tester, docKey, _) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBox = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );

            await tester.tapAt(
              docBox.localToGlobal(characterBox!.center),
            );
            await tester.pumpAndSettle();

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 34),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag collapsed handle upstream',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_drag-collapsed-upstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 28)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.tapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(IOSCollapsedHandle);
            final handleBox = handleFinder.evaluate().first.renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            // Pump and settle so that the drag isn't perceived as a 2nd tap.
            await tester.pumpAndSettle();

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 28),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag collapsed handle downstream',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_drag-collapsed-downstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 39)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.tapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(IOSCollapsedHandle);
            final handleBox = handleFinder.evaluate().first.renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            // Pump and settle so that the drag isn't perceived as a 2nd tap.
            await tester.pumpAndSettle();

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 39),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'double tap text',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_double-tap-text",
          (tester, docKey, rootWidget) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBox = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBox!.center),
            );
            await tester.pumpAndSettle();

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
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
          },
        );

        _testParagraphSelection(
          'triple tap text',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_trip-tap-text",
          (tester, docKey, _) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBox = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
            );

            await tester.tripleTapAt(
              docBox.localToGlobal(characterBox!.center),
            );
            await tester.pumpAndSettle();

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 231),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag base handle upstream',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_drag-base-upstream",
          maxPixelMismatchCount: 1,
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 28)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 22)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );

            await tester.pumpAndSettle();

            final handleFinder = find.byType(IOSSelectionHandle);
            final handleBox = handleFinder.evaluate().first.renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 22),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 39),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag extent handle upstream',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_drag-extent-upstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 38)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 30)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(IOSSelectionHandle);
            final handleBox = handleFinder.evaluate().elementAt(1).renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 28),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 31, affinity: TextAffinity.upstream),
                ),
              ),
            );
          },
        );

        _testParagraphSelection(
          'drag extent handle downstream',
          DocumentGestureMode.iOS,
          "mobile-selection_ios_drag-extent-downstream",
          (tester, docKey, dragLine) async {
            final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
            final docLayout = docKey.currentState as DocumentLayout;
            final characterBoxStart = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 38)),
            );
            final characterBoxEnd = docLayout.getRectForPosition(
              const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 44)),
            );
            final dragDelta = characterBoxEnd!.center - characterBoxStart!.center;

            await tester.doubleTapAt(
              docBox.localToGlobal(characterBoxStart.center),
            );
            await tester.pumpAndSettle();

            final handleFinder = find.byType(IOSSelectionHandle);
            final handleBox = handleFinder.evaluate().elementAt(1).renderObject as RenderBox;
            final handleRectGlobal = Rect.fromPoints(
              handleBox.localToGlobal(Offset.zero),
              handleBox.localToGlobal(
                Offset(handleBox.size.width, handleBox.size.height),
              ),
            );

            await tester.dragFrom(handleRectGlobal.center, dragDelta);

            // Update the drag line for debug purposes
            dragLine.value = _Line(handleRectGlobal.center, handleRectGlobal.center + dragDelta);

            // Even though this is a golden test, we verify the final selection
            // to make it easier to spot rendering problems vs selection problems.
            expect(
              SuperEditorInspector.findDocumentSelection(),
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 28),
                ),
                extent: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 45),
                ),
              ),
            );
          },
        );
      });
    });
  });
}

/// Pumps a single-paragraph document into the WidgetTester and then hands control
/// to the given [test] method.
void _testParagraphSelection(
  String description,
  DocumentGestureMode platform,
  String goldenName,
  Future<void> Function(WidgetTester, GlobalKey docKey, ValueNotifier<_Line?> dragLine) test, {
  int maxPixelMismatchCount = 0,
}) {
  final docKey = GlobalKey();

  testGoldensOnAndroid(description, (tester) async {
    tester.view
      ..physicalSize = const Size(800, 200)
      ..devicePixelRatio = 1.0;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;

    final dragLine = ValueNotifier<_Line?>(null);

    await tester //
        .createDocument()
        .withCustomContent(_createSingleParagraphDoc())
        .withLayoutKey(docKey)
        .withGestureMode(platform)
        .useStylesheet(Stylesheet(
          documentPadding: const EdgeInsets.all(16),
          rules: defaultStylesheet.rules,
          inlineTextStyler: (attributions, style) => _textStyleBuilder(attributions),
        ))
        .withCustomWidgetTreeBuilder(
      (superEditor) {
        return _buildScaffold(
          dragLine: dragLine,
          child: superEditor,
        );
      },
    ) //
        .pump();

    // Run the test
    await test(tester, docKey, dragLine);

    // Compare the golden
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(_DragLinePaint),
      matchesGoldenFileWithPixelAllowance("goldens/$goldenName.png", maxPixelMismatchCount),
    );

    tester.view.resetPhysicalSize();
  });
}

Widget _buildScaffold({
  required ValueNotifier<_Line?> dragLine,
  required Widget child,
}) {
  return _DragLinePaint(
    line: dragLine,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: IntrinsicHeight(
            child: child,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}

TextStyle _textStyleBuilder(attributions) {
  return const TextStyle(
    color: Colors.black,
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 1.4,
  );
}

MutableDocument _createSingleParagraphDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText(
          "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        ),
      ),
    ],
  );
}

class _DragLinePaint extends StatelessWidget {
  const _DragLinePaint({
    Key? key,
    required this.line,
    required this.child,
  }) : super(key: key);

  final ValueNotifier<_Line?> line;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_Line?>(
      valueListenable: line,
      builder: (context, line, child) {
        return CustomPaint(
          foregroundPainter: line != null ? _DragLinePainter(line: line) : null,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _DragLinePainter extends CustomPainter {
  _DragLinePainter({
    required _Line line,
  })  : _line = line,
        _paint = Paint();

  final _Line _line;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    _paint.color = Colors.red;
    canvas.drawCircle(_line.from, 5, _paint);

    _paint.shader = ui.Gradient.linear(
      _line.from,
      _line.to,
      [const Color(0x00FF0000), const Color(0xFFFF0000)],
    );

    canvas.drawRect(
        Rect.fromPoints(
          _line.from - const Offset(0, 2),
          _line.to + const Offset(0, 2),
        ),
        _paint);
  }

  @override
  bool shouldRepaint(_DragLinePainter oldDelegate) {
    return _line != oldDelegate._line;
  }
}

class _Line {
  _Line(this.from, this.to);

  final Offset from;
  final Offset to;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Line && runtimeType == other.runtimeType && from == other.from && to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

extension on WidgetTester {
  Future<void> doubleTapAt(Offset offset) async {
    await tapAt(offset);
    await pump(kDoubleTapMinTime);
    await tapAt(offset);
  }

  Future<void> tripleTapAt(Offset offset) async {
    await tapAt(offset);
    await pump(kDoubleTapMinTime);
    await tapAt(offset);
    await pump(kDoubleTapMinTime);
    await tapAt(offset);
  }
}
