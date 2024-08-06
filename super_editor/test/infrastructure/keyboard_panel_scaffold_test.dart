import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgetsOnMobile('shows above-keyboard panel at the bottom when there is no keyboard', (tester) async {
      await _pumpTestApp(tester);

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

    testWidgetsOnMobile('shows above-keyboard panel above the keyboard', (tester) async {
      await _pumpTestApp(tester);

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Ensure the above-keyboard panel sits aboce the software keyboard.
      expect(
        tester.getBottomLeft(find.byKey(_aboveKeyboardPanelKey)).dy,
        equals(tester.getSize(find.byType(MaterialApp)).height - _keyboardHeight),
      );
    });

    testWidgetsOnMobile('shows above-keyboard panel above the keyboard when toggling panels and showing the keyboard',
        (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController: softwareKeyboardController);

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
      final controller = KeyboardPanelController(softwareKeyboardController: softwareKeyboardController);

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
      final controller = KeyboardPanelController(softwareKeyboardController: softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

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
      final controller = KeyboardPanelController(softwareKeyboardController: softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

      // Place the caret at the beginning of the document to show the software keyboard.
      await tester.placeCaretInParagraph('1', 0);

      // Request to show the keyboard panel and let the entrance animation run.
      controller.showKeyboardPanel();
      await tester.pumpAndSettle();

      // Ensure the keyboard panel is visible.
      expect(find.byKey(_keyboardPanelKey), findsOneWidget);

      // Hide the keyboard panel and show the software keyboard.
      controller.toggleKeyboard();
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
      final controller = KeyboardPanelController(softwareKeyboardController: softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

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

    testWidgetsOnMobile('shows above-keyboard panel at the bottom when closing the panel and the keyboard',
        (tester) async {
      final softwareKeyboardController = SoftwareKeyboardController();
      final controller = KeyboardPanelController(softwareKeyboardController: softwareKeyboardController);

      await _pumpTestApp(
        tester,
        controller: controller,
        softwareKeyboardController: softwareKeyboardController,
      );

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
/// the `MediaQuery` view insets when the app comunicates with the IME to show/hide
/// the software keyboard.
Future<void> _pumpTestApp(
  WidgetTester tester, {
  KeyboardPanelController? controller,
  SoftwareKeyboardController? softwareKeyboardController,
}) async {
  final keyboardController = softwareKeyboardController ?? SoftwareKeyboardController();
  final keyboardPanelController = controller ?? KeyboardPanelController(softwareKeyboardController: keyboardController);

  await tester //
      .createDocument()
      .withLongDoc()
      .withSoftwareKeyboardController(keyboardController)
      .withCustomWidgetTreeBuilder(
        (superEditor) => MaterialApp(
          home: _SoftwareKeyboardHeightSimulator(
            tester: tester,
            keyboardHeight: _keyboardHeight,
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: KeyboardPanelScaffold(
                controller: keyboardPanelController,
                contentBuilder: (context, isKeyboardPanelVisible) => superEditor,
                aboveKeyboardBuilder: (context, isKeyboardPanelVisible) => SizedBox(
                  key: _aboveKeyboardPanelKey,
                  height: 54,
                ),
                keyboardPanelBuilder: (context) => ColoredBox(
                  key: _keyboardPanelKey,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      )
      .pump();
}

/// A widget that simulates the software keyboard appearance and disappearance.
///
/// This works by listening to platform messages that show/hide the software keyboard
/// and animating the `MediaQuery` bottom insets to reflect the height of the keyboard.
///
/// Place this widget above the `Scaffold` in the widget tree.
class _SoftwareKeyboardHeightSimulator extends StatefulWidget {
  const _SoftwareKeyboardHeightSimulator({
    required this.tester,
    required this.keyboardHeight,
    required this.child,
  });

  final WidgetTester tester;

  /// The desired height of the software keyboard.
  final double keyboardHeight;

  final Widget child;

  @override
  State<_SoftwareKeyboardHeightSimulator> createState() => _SoftwareKeyboardHeightSimulatorState();
}

class _SoftwareKeyboardHeightSimulatorState extends State<_SoftwareKeyboardHeightSimulator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _setupPlatformMethodInterception();
  }

  @override
  void didUpdateWidget(covariant _SoftwareKeyboardHeightSimulator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tester != oldWidget.tester) {
      _setupPlatformMethodInterception();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showKeyboard() {
    if (_animationController.isForwardOrCompleted) {
      // The keyboard is either fully visible or animating its entrance.
      return;
    }

    _animationController.forward();
  }

  void _hideKeyboard() {
    if (const [AnimationStatus.dismissed, AnimationStatus.reverse].contains(_animationController.status)) {
      // The keyboard is either hidden or animating its exit.
      return;
    }

    _animationController.reverse();
  }

  void _setupPlatformMethodInterception() {
    widget.tester.interceptChannel(SystemChannels.textInput.name) //
      ..interceptMethod(
        'TextInput.show',
        (methodCall) {
          _showKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.setClient',
        (methodCall) {
          _showKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.clearClient',
        (methodCall) {
          _hideKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.hide',
        (methodCall) {
          _hideKeyboard();
          return null;
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return MediaQuery(
          data: mediaQuery.copyWith(
            viewInsets: mediaQuery.viewInsets.copyWith(
              bottom: widget.keyboardHeight * _animationController.value,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

const _keyboardHeight = 400.0;
const _aboveKeyboardPanelKey = ValueKey('aboveKeyboardPanel');
const _keyboardPanelKey = ValueKey('keyboardPanel');
