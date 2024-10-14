import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

import '../super_editor/supereditor_test_tools.dart';

void main() {
  group('Keyboard panel scaffold', () {
    testWidgetsOnMobile('does not show panel upon initialization', (tester) async {
      await _pumpTestApp(tester);

      // Ensure the keyboard panel is not visible.
      expect(find.byKey(_keyboardPanelKey), findsNothing);
    });

    testWidgetsOnMobile('shows keyboard panel at the bottom when there is no keyboard', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the above-keyboard panel.
      controller.showToolbar();
      await tester.pump();

      // Ensure the above-keyboard panel sits at the bottom of the screen.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        equals(tester.getSize(find.byType(MaterialApp)).height),
      );
    });

    testWidgetsOnMobile('does not show keyboard panel upon keyboard appearance', (tester) async {
      await _pumpTestApp(tester);

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Ensure the keyboard panel is not visible.
      expect(find.byKey(_keyboardPanelKey), findsNothing);
    });

    testWidgetsOnMobile('shows keyboard toolbar above the keyboard', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the above-keyboard panel.
      controller.showToolbar();
      await tester.pump();

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Ensure the above-keyboard panel sits above the software keyboard.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        equals(tester.getSize(find.byType(MaterialApp)).height - _keyboardHeight),
      );
    });

    testWidgetsOnMobile('shows keyboard toolbar above the keyboard when toggling panels and showing the keyboard',
        (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the above-keyboard panel.
      controller.showToolbar();
      await tester.pump();

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Hide both the keyboard panel and the software keyboard.
      controller.closeKeyboardAndPanel();
      await tester.pumpAndSettle();

      // Place the caret at the beginning of the document to show the software keyboard again.
      await tester.placeCaretInParagraph('1', 0);

      // Ensure the top panel sits above the keyboard.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        equals(tester.getSize(find.byType(MaterialApp)).height - _keyboardHeight),
      );
    });

    testWidgetsOnMobile('shows keyboard panel upon request', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is visible.
      expect(find.byKey(_keyboardPanelKey), findsOneWidget);
    });

    testWidgetsOnMobile('displays panel with the same height as the keyboard', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the above-keyboard panel.
      controller.showToolbar();
      await tester.pump();

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel and let the entrance animation run.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel has the same size as the software keyboard.
      expect(
        tester.getSize(find.byKey(_keyboardPanelKey)).height,
        equals(_keyboardHeight),
      );

      // Ensure the above-keyboard panel sits immediately above the keyboard panel.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        equals(tester.getSize(find.byType(MaterialApp)).height - _keyboardHeight),
      );
    });

    testWidgetsOnMobile('hides the panel when toggling the keyboard', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the above-keyboard panel.
      controller.showToolbar();
      await tester.pump();

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel and let the entrance animation run.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is visible.
      expect(find.byKey(_keyboardPanelKey), findsOneWidget);

      // Hide the keyboard panel and show the software keyboard.
      controller.toggleSoftwareKeyboardWithPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is not visible.
      expect(find.byKey(_keyboardPanelKey), findsNothing);

      // Ensure the above-keyboard panel sits immediately above the keyboard.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        equals(tester.getSize(find.byType(MaterialApp)).height - _keyboardHeight),
      );
    });

    testWidgetsOnMobile('hides the panel upon request', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the above-keyboard panel.
      controller.showToolbar();
      await tester.pump();

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel and let the entrance animation run.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is visible.
      expect(find.byKey(_keyboardPanelKey), findsOneWidget);

      controller.closeKeyboardAndPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is not visible.
      expect(find.byKey(_keyboardPanelKey), findsNothing);

      // Ensure the above-keyboard panel sits at the bottom of the screen.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        equals(tester.getSize(find.byType(MaterialApp)).height),
      );
    });

    testWidgetsOnMobile('hides the panel when IME connection closes', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the keyboard toolbar.
      controller.showToolbar();
      await tester.pump();

      // Place the caret at the beginning of the document to open the IME connection.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel and let the entrance animation run.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is visible.
      expect(find.byKey(_keyboardPanelKey), findsOneWidget);

      // Close the IME connection.
      softwareKeyboardController.close();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is not visible.
      expect(find.byKey(_keyboardPanelKey), findsNothing);
    });

    testWidgetsOnMobile('shows keyboard toolbar at the bottom when closing the panel and the keyboard', (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Request to show the above-keyboard panel.
      controller.showToolbar();
      await tester.pump();

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel and let the entrance animation run.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is visible.
      expect(find.byKey(_keyboardPanelKey), findsOneWidget);

      // Hide the keyboard panel and the software keyboard.
      controller.closeKeyboardAndPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is not visible.
      expect(find.byKey(_keyboardPanelKey), findsNothing);

      // Ensure the above-keyboard panel sits at the bottom of the screen.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        tester.getSize(find.byType(MaterialApp)).height,
      );
    });
  });
}

/// Pumps a tree that displays a panel at the software keyboard position.
///
/// Simulates the software keyboard appearance and disappearance by animating
/// the `MediaQuery` view insets when the app communicates with the IME to show/hide
/// the software keyboard.
Future<void> _pumpTestApp(
  WidgetTester tester, {
  KeyboardPanelController? controller,
  SoftwareKeyboardController? softwareKeyboardController,
  ValueNotifier<bool>? isImeConnected,
}) async {
  final keyboardController = softwareKeyboardController ?? SoftwareKeyboardController();
  final keyboardPanelController = controller ?? KeyboardPanelController(keyboardController);
  final imeConnectionNotifier = isImeConnected ?? ValueNotifier<bool>(false);

  await tester //
      .createDocument()
      .withLongDoc()
      .withSoftwareKeyboardController(keyboardController)
      .withImeConnectionNotifier(imeConnectionNotifier)
      .simulateSoftwareKeyboardInsets(true)
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Builder(builder: (context) {
              return KeyboardPanelScaffold(
                controller: keyboardPanelController,
                isImeConnected: imeConnectionNotifier,
                contentBuilder: (context, isKeyboardPanelVisible) => superEditor,
                toolbarBuilder: (context, isKeyboardPanelVisible) => Container(
                  key: _aboveKeyboardPanelKey,
                  height: 54,
                  color: Colors.blue,
                ),
                keyboardPanelBuilder: (context) => const ColoredBox(
                  key: _keyboardPanelKey,
                  color: Colors.red,
                ),
              );
            }),
          ),
        ),
      )
      .pump();
}

const _keyboardHeight = 300.0;
const _aboveKeyboardPanelKey = ValueKey('aboveKeyboardPanel');
const _keyboardPanelKey = ValueKey('keyboardPanel');
