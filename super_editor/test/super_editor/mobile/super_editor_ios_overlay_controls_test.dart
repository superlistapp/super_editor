import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_runners.dart';
import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor > iOS > overlay controls >", () {
    group("on device and web > shows ", () {
      testWidgetsOnIosDeviceAndWeb("caret", (tester) async {
        await _pumpApp(tester);

        // Create a collapsed selection.
        await tester.tapInParagraph("1", 1);

        // Ensure we have a collapsed selection.
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isTrue);

        // Ensure caret (and only caret) is visible.
        expect(SuperEditorInspector.findMobileCaret(), findsOneWidget);
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);
      });

      testWidgetsOnIosDeviceAndWeb("upstream and downstream handles", (tester) async {
        await _pumpApp(tester);

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

    group("on device >", () {
      group("shows", () {
        testWidgetsOnIos("the magnifier", (tester) async {
          await _pumpApp(tester);

          // Long press, and hold, so that the magnifier appears.
          await tester.longPressDownInParagraph("1", 1);

          // Ensure the magnifier is wanted AND visible.
          expect(SuperEditorInspector.wantsMobileMagnifierToBeVisible(), isTrue);
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
        });

        testWidgetsOnIos("the floating toolbar", (tester) async {
          await _pumpApp(tester);

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
    });

    group("on web >", () {
      group("defers to browser to show", () {
        testWidgetsOnWebIos("the magnifier", (tester) async {
          await _pumpApp(tester);

          // Long press, and hold, so that the magnifier appears.
          await tester.longPressDownInParagraph("1", 1);

          // Ensure the magnifier is desired, but not displayed.
          expect(SuperEditorInspector.wantsMobileMagnifierToBeVisible(), isTrue);
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
        });

        testWidgetsOnWebIos("the floating toolbar", (tester) async {
          await _pumpApp(tester);

          // Create an expanded selection.
          await tester.doubleTapInParagraph("1", 1);

          // Ensure we have an expanded selection.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

          // Ensure that the toolbar is desired, but not displayed.
          expect(SuperEditorInspector.wantsMobileToolbarToBeVisible(), isTrue);
          expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
        });
      });
    });
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester
      .createDocument()
      // Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor...
      .withSingleParagraph()
      .pump();
}
