import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/super_textfield/infrastructure/text_field_gestures_interaction_overrides.dart';
import 'package:super_editor/super_text_field.dart';

import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

void main() {
  group('SuperTextField gesture interaction overrides > ', () {
    group('single tap >', () {
      group('single handler >', () {
        testWidgetsOnAllPlatforms('can be customized', (tester) async {
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

          // Tap on the text field.
          await tester.placeCaretInSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTapHandled, isTrue);
          expect(handler.wasDoubleTapHandled, isFalse);
          expect(handler.wasTripleTapHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });

      group('multiple handlers >', () {
        testWidgetsOnAllPlatforms('run seach handler until the gesture is handled', (tester) async {
          final noopHandler = _NoopTextFieldTapHandler();
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [noopHandler, handler]);

          // Tap on the text field.
          await tester.placeCaretInSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTapHandled, isTrue);
          expect(handler.wasDoubleTapHandled, isFalse);
          expect(handler.wasTripleTapHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });

        testWidgetsOnAllPlatforms('stops when a handler handles the gesture', (tester) async {
          final handler1 = _SuperTextFieldTestTapHandler();
          final handler2 = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler1, handler2]);

          // Tap on the text field.
          await tester.placeCaretInSuperTextField(0);

          // Ensure the first tap handler was called.
          expect(handler1.wasTapHandled, isTrue);
          expect(handler1.wasDoubleTapHandled, isFalse);
          expect(handler1.wasTripleTapHandled, isFalse);

          // Ensure the second tap handler was not called.
          expect(handler2.wasTapHandled, isFalse);
          expect(handler2.wasDoubleTapHandled, isFalse);
          expect(handler2.wasTripleTapHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });
    });

    group('double tap >', () {
      group('single handler >', () {
        testWidgetsOnAllPlatforms('can be customized', (tester) async {
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

          await tester.doubleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasDoubleTapHandled, isTrue);
          expect(handler.wasTripleTapHandled, isFalse);

          // Ensure the default behavior of placing the caret was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });

      group('multiple handlers > ', () {
        testWidgetsOnAllPlatforms('run each handler until the gesture is handled', (tester) async {
          final noopHandler = _NoopTextFieldTapHandler();
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [noopHandler, handler]);

          await tester.doubleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasDoubleTapHandled, isTrue);
          expect(handler.wasTripleTapHandled, isFalse);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });

        testWidgetsOnAllPlatforms('stops when a handler handles the gesture', (tester) async {
          final handler1 = _SuperTextFieldTestTapHandler();
          final handler2 = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler1, handler2]);

          await tester.doubleTapAtSuperTextField(0);

          // Ensure the first tap handler was called.
          expect(handler1.wasDoubleTapHandled, isTrue);
          expect(handler1.wasTripleTapHandled, isFalse);

          // Ensure the second tap handler was not called.
          expect(handler2.wasDoubleTapHandled, isFalse);
          expect(handler2.wasTripleTapHandled, isFalse);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });
    });

    group('triple tap', () {
      group('single handler > ', () {
        testWidgetsOnAllPlatforms('can be customized', (tester) async {
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

          // Triple tap on the text field.
          await tester.tripleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTripleTapHandled, isTrue);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });

      group('multiple handlers > ', () {
        testWidgetsOnAllPlatforms('run each handler until the gesture is handled', (tester) async {
          final noopHandler = _NoopTextFieldTapHandler();
          final handler = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [noopHandler, handler]);

          await tester.tripleTapAtSuperTextField(0);

          // Ensure the custom tap handler was called.
          expect(handler.wasTripleTapHandled, isTrue);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });

        testWidgetsOnAllPlatforms('stops when a handler handles the gesture', (tester) async {
          final handler1 = _SuperTextFieldTestTapHandler();
          final handler2 = _SuperTextFieldTestTapHandler();

          await _pumpSingleFieldTestApp(tester, tapHandlers: [handler1, handler2]);

          await tester.tripleTapAtSuperTextField(0);

          // Ensure the first tap handler was called.
          expect(handler1.wasTripleTapHandled, isTrue);

          // Ensure the second tap handler was not called.
          expect(handler2.wasTripleTapHandled, isFalse);

          // Ensure the default behavior of placing an expanded selection
          // was not called.
          expect(
            SuperTextFieldInspector.findSelection(),
            const TextSelection.collapsed(offset: -1),
          );
        });
      });
    });

    testWidgetsOnDesktop('allows customizing mouse cursor', (tester) async {
      final handler = _SuperTextFieldTestTapHandler();

      await _pumpSingleFieldTestApp(tester, tapHandlers: [handler]);

      // Start a gesture outside SuperTextField bounds.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Ensure the cursor type is 'basic' when not hovering SuperTextField.
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);

      // Hover over the text field.
      await gesture.moveTo(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Ensure the cursor type was configured by the custom handler.
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.move);
    });
  });
}

/// Pump a test app with a single [SuperTextField] that has the given [tapHandlers].
Future<void> _pumpSingleFieldTestApp(
  WidgetTester tester, {
  required List<SuperTextFieldTapHandler> tapHandlers,
}) async {
  final textController = AttributedTextEditingController(
    text: AttributedText('This is a text field'),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: 300,
            child: SuperTextField(
              textController: textController,
              lineHeight: 16,
              tapHandlers: tapHandlers,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A [SuperTextFieldTapHandler] that records whether each tap was handled and
/// always specifies [SystemMouseCursors.move] as the mouse cursor.
///
/// This handler prevents any other handlers from running, because it always
/// returns [TapHandlingInstruction.halt].
class _SuperTextFieldTestTapHandler extends SuperTextFieldTapHandler {
  bool get wasTapHandled => _wasTapHandled;
  bool _wasTapHandled = false;

  bool get wasDoubleTapHandled => _wasDoubleTapHandled;
  bool _wasDoubleTapHandled = false;

  bool get wasTripleTapHandled => _wasTripleTapHandled;
  bool _wasTripleTapHandled = false;

  @override
  MouseCursor? mouseCursorForContentHover(TextFieldGestureDetails details) {
    return SystemMouseCursors.move;
  }

  @override
  TapHandlingInstruction onTap(TextFieldGestureDetails details) {
    _wasTapHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(TextFieldGestureDetails details) {
    _wasDoubleTapHandled = true;
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onTripleTap(TextFieldGestureDetails details) {
    _wasTripleTapHandled = true;
    return TapHandlingInstruction.halt;
  }
}

/// A [SuperTextFieldTapHandler] that does nothing.
class _NoopTextFieldTapHandler extends SuperTextFieldTapHandler {}
