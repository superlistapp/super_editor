import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_runners.dart';
import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor > Android > overlay controls >", () {
    testWidgetsOnAndroid("hides all controls when placing the caret", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Place the caret.
      await tester.tapInParagraph("1", 200);

      // Ensure all controls are hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
    });

    testWidgetsOnAndroid("shows magnifier when dragging the caret", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Place the caret.
      await tester.tapInParagraph("1", 200);

      // Press and drag the caret somewhere else in the paragraph.
      final gesture = await tester.tapDownInParagraph("1", 200);
      for (int i = 0; i < 5; i += 1) {
        await gesture.moveBy(const Offset(24, 0));
        await tester.pump();
      }

      // Ensure magnifier is visible and toolbar is hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgetsOnAndroid("shows magnifier when dragging the collapsed handle", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Place the caret.
      await tester.tapInParagraph("1", 200);

      // Press and drag the caret somewhere else in the paragraph.
      final gesture = await tester.pressDownOnCollapsedMobileHandle();
      for (int i = 0; i < 5; i += 1) {
        await gesture.moveBy(const Offset(24, 0));
        await tester.pump();
      }

      // Ensure magnifier is visible and toolbar is hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgetsOnAndroid("shows toolbar when selection is expanded", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Select a word.
      await tester.doubleTapInParagraph("1", 200);

      // Ensure toolbar is visible and magnifier is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnAndroid("hides toolbar when tapping on expanded selection", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Select a word.
      await tester.doubleTapInParagraph("1", 200);

      // Ensure toolbar is visible and magnifier is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);

      // Tap on the selected text.
      await tester.tapInParagraph("1", 200);

      // Ensure that all controls are now hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnAndroid("shows magnifier when dragging expanded handle", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Select a word.
      await tester.doubleTapInParagraph("1", 250);

      // Press and drag upstream handle
      final gesture = await tester.pressDownOnUpstreamMobileHandle();
      for (int i = 0; i < 5; i += 1) {
        await gesture.moveBy(const Offset(-24, 0));
        await tester.pump();
      }

      // Ensure that the magnifier is visible.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    group("on device and web > shows", () {
      testWidgetsOnAndroidDeviceAndWeb("caret", (tester) async {
        await _pumpSingleParagraphApp(tester);

        // Create a collapsed selection.
        await tester.tapInParagraph("1", 1);

        // Ensure we have a collapsed selection.
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isTrue);

        // Ensure caret (and only caret) is visible.
        expect(SuperEditorInspector.findMobileCaret(), findsOneWidget);
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);
      });

      testWidgetsOnAndroidDeviceAndWeb("upstream and downstream handles", (tester) async {
        await _pumpSingleParagraphApp(tester);

        // Create an expanded selection.
        await tester.doubleTapInParagraph("1", 1);

        // Ensure we have an expanded selection.
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

        // Ensure expanded handles are visible, but caret isn't.
        expect(SuperEditorInspector.findMobileCaret(), findsNothing);
        expect(SuperEditorInspector.findMobileUpstreamDragHandle(), findsOneWidget);
        expect(SuperEditorInspector.findMobileDownstreamDragHandle(), findsOneWidget);
      });
    });

    group("on device > shows", () {
      testWidgetsOnAndroid("the magnifier", (tester) async {
        await _pumpSingleParagraphApp(tester);

        final gesture = await tester.longPressDownInParagraph("1", 1);
        for (int i = 0; i < 5; i += 1) {
          await gesture.moveBy(const Offset(-24, 0));
          await tester.pump();
        }

        // Ensure the magnifier is wanted AND visible.
        expect(SuperEditorInspector.wantsMobileMagnifierToBeVisible(), isTrue);
        expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
      });

      testWidgetsOnAndroid("the floating toolbar", (tester) async {
        await _pumpSingleParagraphApp(tester);

        // Create an expanded selection.
        await tester.doubleTapInParagraph("1", 1);

        // Ensure we have an expanded selection.
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

        // Ensure that the toolbar is desired AND displayed.
        expect(SuperEditorInspector.wantsMobileToolbarToBeVisible(), isTrue);
        expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      });
    });

    group("on web > shows", () {
      testWidgetsOnWebAndroid("the magnifier", (tester) async {
        // Explanation: On iOS, we defer some overlay controls to the mobile browser.
        // This test is here to explicitly show that we don't defer those things to
        // the mobile browser on Android.
        await _pumpSingleParagraphApp(tester);

        // Long press and drag so that the magnifier appears.
        final gesture = await tester.longPressDownInParagraph("1", 1);
        for (int i = 0; i < 5; i += 1) {
          await gesture.moveBy(const Offset(-24, 0));
          await tester.pump();
        }

        // Ensure the magnifier is desired AND displayed.
        expect(SuperEditorInspector.wantsMobileMagnifierToBeVisible(), isTrue);
        expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
      });

      testWidgetsOnWebAndroid("the floating toolbar", (tester) async {
        // Explanation: On iOS, we defer some overlay controls to the mobile browser.
        // This test is here to explicitly show that we don't defer those things to
        // the mobile browser on Android.
        await _pumpSingleParagraphApp(tester);

        // Create an expanded selection.
        await tester.doubleTapInParagraph("1", 1);

        // Ensure we have an expanded selection.
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

        // Ensure that the toolbar is desired AND displayed
        expect(SuperEditorInspector.wantsMobileToolbarToBeVisible(), isTrue);
        expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      });
    });
  });
}

Future<void> _pumpSingleParagraphApp(WidgetTester tester) async {
  await tester
      .createDocument()
      // Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor...
      .withSingleParagraph()
      .pump();
}
