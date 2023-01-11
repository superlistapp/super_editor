import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

void main() {
  group('SuperTextField gestures', () {
    group('tapping in empty space places the caret at the end of the text', () {
      testWidgetsOnMobile("when the field does not have focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });

      testWidgetsOnMobile("when the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        await tester.pumpAndSettle();

        // Ensure selection is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });
    });

    group('tapping on padding places caret', () {
      testWidgetsOnAllPlatforms('on the left side', (tester) async {
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(left: 20),
        );

        final finder = find.byType(SuperTextField);
        // Tap at the left side of the text field, at the vertical center.
        await tester.tapAt(tester.getTopLeft(finder) + Offset(1, tester.getSize(finder).height / 2));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });

      testWidgetsOnAllPlatforms('on the top', (tester) async {
        /// Pump a center-aligned text field so we can tap at the middle of the text.
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(top: 20),
          textAlign: TextAlign.center,
        );

        final finder = find.byType(SuperTextField);
        // Tap at the top of the text field, at the horizontal center.
        // On linux, tapping exactly at middle is placing caret at offset 1.
        await tester.tapAt(tester.getTopLeft(finder) + Offset((tester.getSize(finder).width / 2) + 1, 1));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );
      });

      testWidgetsOnAllPlatforms('on the bottom', (tester) async {
        /// Pump a center-aligned text field so we can tap at the middle of the text.
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(bottom: 20),
          textAlign: TextAlign.center,
        );

        final finder = find.byType(SuperTextField);
        // Tap at the bottom of the text field, at the horizontal center.
        // On linux, tapping exactly at middle is placing caret at offset 1.
        await tester.tapAt(tester.getBottomRight(finder) - Offset((tester.getSize(finder).width / 2) - 1, 1));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 2),
        );
      });

      testWidgetsOnAllPlatforms('on the right side', (tester) async {
        await _pumpTestApp(
          tester,
          padding: const EdgeInsets.only(right: 20),
        );

        final finder = find.byType(SuperTextField);
        // Tap at the right side of the text field, at the vertical center.
        await tester.tapAt(tester.getBottomRight(finder) - Offset(1, tester.getSize(finder).height / 2));
        await tester.pumpAndSettle();

        // Ensure caret was placed.
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 3),
        );
      });
    });

    group('tapping in an area containing text places the caret at tap position', () {
      testWidgetsOnMobile("when the field does not have focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure selection is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });

      testWidgetsOnMobile("when the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        // Tap in a place without text
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        // Tap in a place containing text
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure selection is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });
    });

    group("on desktop", () {
      testWidgetsOnDesktop("tap down focuses the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down, but don't release.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure the field has a selection
        expect(SuperTextFieldInspector.findSelection()!.isValid, true);

        // Normally, `gesture.removePointer()` would be placed in a teardown
        // because we don't really care about removing the pointer. However,
        // in this case, when the pointer is removed, it triggers the field's
        // "pan cancel", which throws a null-pointer exception because the
        // widget tree is being torn down and a `GlobalKey` is used. The only
        // way I found to fix this issue was to run both an `up()` and
        // `removePointer()` here.
        await gesture.up();
        await gesture.removePointer();
      });
    });

    group("on mobile", () {
      testWidgetsOnMobile("tap down does NOT focus the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down, but don't release.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        await tester.pumpAndSettle();

        // Ensure the field has no selection
        expect(SuperTextFieldInspector.findSelection()!.isValid, false);
      });

      testWidgetsOnMobile("tap down and drag does NOT focus the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down, start a pan, then drag up.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        await tester.pumpAndSettle();
        await gesture.moveBy(const Offset(2, 2));
        await tester.pumpAndSettle();
        await gesture.moveBy(const Offset(0, -300));
        await tester.pumpAndSettle();

        // Ensure the field has no selection
        expect(SuperTextFieldInspector.findSelection()!.isValid, false);
      });

      testWidgetsOnMobile("tap up focuses the field", (tester) async {
        await _pumpTestApp(tester);

        // Tap down and up.
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure the field now has a selection.
        expect(SuperTextFieldInspector.findSelection()!.isValid, true);
      });

      testWidgetsOnMobile("tap down in focused field moves the caret", (tester) async {
        await _pumpTestApp(tester);

        // Tap in empty space to place the caret at the end of the text.
        await tester.tapAt(tester.getBottomRight(find.byType(SuperTextField)) - const Offset(10, 10));
        // Without this 'delay' onTapDown is not called the second time
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(SuperTextFieldInspector.findSelection()!.extent.offset, greaterThan(0));

        // Tap DOWN at beginning of text to move the caret.
        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        await tester.pumpAndSettle();

        // Ensure the caret moved to the beginning of the text.
        expect(SuperTextFieldInspector.findSelection()!.extent.offset, 0);
      });

      // mobile only because precise input (mouse) doesn't use touch slop
      testWidgetsOnMobile("MediaQuery gesture settings are respected", (tester) async {
        bool horizontalDragStartCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onHorizontalDragStart: (d) {
                  horizontalDragStartCalled = true;
                },
                child: Builder(builder: (context) {
                  // Custom gesture settings that ensure same value for touchSlop
                  // and panSlop
                  final data = MediaQuery.of(context).copyWith(
                    gestureSettings: const _GestureSettings(
                      panSlop: 18,
                      touchSlop: 18,
                    ),
                  );
                  return MediaQuery(
                    data: data,
                    child: SuperTextField(
                      textController: AttributedTextEditingController(
                        text: AttributedText(text: 'a b c'),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );

        // Tap down and up so the field is focused.
        await tester.placeCaretInSuperTextField(0);

        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );

        // The gesture should trigger the selection PanGestureRecognizer instead
        // the HorizontalDragGestureRecognizer below.

        final gesture = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture.removePointer());
        await gesture.moveBy(const Offset(19, 0));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(horizontalDragStartCalled, isFalse);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onHorizontalDragStart: (d) {
                  horizontalDragStartCalled = true;
                },
                child: Builder(builder: (context) {
                  // Gesture settings that mimic flutter default where
                  // panSlop = 2x touchSlop
                  final data = MediaQuery.of(context).copyWith(
                    gestureSettings: const _GestureSettings(
                      touchSlop: 18,
                      panSlop: 36,
                    ),
                  );
                  return MediaQuery(
                    data: data,
                    child: SuperTextField(
                      textController: AttributedTextEditingController(
                        text: AttributedText(text: 'a b c'),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );

        final gesture2 = await tester.startGesture(tester.getTopLeft(find.byType(SuperTextField)));
        addTearDown(() => gesture2.removePointer());
        await gesture2.moveBy(const Offset(19, 0));
        await gesture2.up();
        await tester.pumpAndSettle();

        // With default gesture settings the horizontal drag recognizer will
        // win instead of the selection PanGestureRecognizer.
        expect(horizontalDragStartCalled, isTrue);
        expect(
          SuperTextFieldInspector.findSelection(),
          const TextSelection.collapsed(offset: 0),
        );
      });

      testWidgetsOnMobile("tap up shows the keyboard if the field already has focus", (tester) async {
        await _pumpTestApp(tester);

        bool isShowKeyboardCalled = false;

        // Tap down and up so the field is focused.
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Intercept messages sent to the platform.
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(SystemChannels.textInput.name, (message) async {
          final methodCall = const JSONMethodCodec().decodeMethodCall(message);
          if (methodCall.method == "TextInput.show") {
            isShowKeyboardCalled = true;
          }
          return null;
        });

        // Avoid a double tap.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

        // Tap down and up again.
        await tester.tapAt(tester.getTopLeft(find.byType(SuperTextField)));
        await tester.pumpAndSettle();

        // Ensure we requested the keyboard to the platform
        expect(isShowKeyboardCalled, true);
      });

      testWidgetsOnIos("tap up attaches to IME if the field already has focus", (tester) async {
        final controller = ImeAttributedTextEditingController();

        await _pumpTestApp(tester, controller: controller);

        // Tap down and up so the field is focused.
        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();
        // Avoid a double tap.
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

        // Ensure we are connected.
        expect(controller.isAttachedToIme, true);

        // Disconnect from IME.
        // In a real app this could happen when the user taps outside the field
        // or clicks on the OK button of the software keyboard.
        controller.detachFromIme();
        await tester.pumpAndSettle();

        // Ensure we are not connected.
        expect(controller.isAttachedToIme, false);

        // Tap down and up again.
        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();

        // Ensure we are connected again.
        expect(controller.isAttachedToIme, true);
      });
    });
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  AttributedTextEditingController? controller,
  EdgeInsets? padding,
  TextAlign? textAlign,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperTextField(
          padding: padding,
          textAlign: textAlign ?? TextAlign.left,
          textController: controller ??
              AttributedTextEditingController(
                text: AttributedText(text: 'abc'),
              ),
        ),
      ),
    ),
  );
}

// Custom gesture settings that ensure panSlop equal to touchSlop
class _GestureSettings extends DeviceGestureSettings {
  const _GestureSettings({
    required double touchSlop,
    required this.panSlop,
  }) : super(touchSlop: touchSlop);

  @override
  final double panSlop;
}
