import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';
import 'package:super_text/super_selectable_text.dart';

import '../../../_text_entry_test_tools.dart';
import '../../_platform_test_tools.dart';

void main() {
  group('SuperDesktopTextField', () {
    group('Keyboard handlers and actions', () {
      group('copy shortcut', () {
        group('Mac', () {
          testWidgets('cmd+c copies selected text', (tester) async {
            Platform.setTestInstance(MacPlatform());

            // Note: this is a widget test because we access the Clipboard.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text'),
              selection: const TextSelection(
                baseOffset: 5,
                extentOffset: 12,
              ),
            );

            // The Clipboard requires a platform response, which doesn't exist
            // for widget tests. Pretend that we're the platform and record
            // the incoming clipboard call.
            String clipboardText = '';
            SystemChannels.platform.setMockMethodCallHandler((call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardText = call.arguments['text'];
              }
            });

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                  isMetaPressed: true,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(clipboardText, 'is some');

            Platform.setTestInstance(null);
          });

          test('control+c does NOT copy selected text', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                  isControlPressed: true,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores c-key without cmd', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores cmd without c-key', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.metaLeft,
                  physicalKey: PhysicalKeyboardKey.metaLeft,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                  isMetaPressed: true,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });

        group('Windows + Linux', () {
          testWidgets('control+c copies selected text', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            // Note: this is a widget test because we access the Clipboard.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text'),
              selection: const TextSelection(
                baseOffset: 5,
                extentOffset: 12,
              ),
            );

            // The Clipboard requires a platform response, which doesn't exist
            // for widget tests. Pretend that we're the platform and record
            // the incoming clipboard call.
            String clipboardText = '';
            SystemChannels.platform.setMockMethodCallHandler((call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardText = call.arguments['text'];
              }
            });

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                  isControlPressed: true,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(clipboardText, 'is some');

            Platform.setTestInstance(null);
          });

          test('cmd+c does NOT copy selected text', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                  isMetaPressed: true,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores c-key without control', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores control without c-key', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.metaLeft,
                  physicalKey: PhysicalKeyboardKey.metaLeft,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final result = DefaultSuperTextFieldKeyboardHandlers.copyTextWhenCmdCIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyC,
                  physicalKey: PhysicalKeyboardKey.keyC,
                  isMetaPressed: true,
                ),
                character: 'c',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
      });

      group('paste shortcut', () {
        group('Mac', () {
          testWidgets('cmd+v pastes clipboard text', (tester) async {
            Platform.setTestInstance(MacPlatform());

            // Note: this is a widget test because we access the Clipboard.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'Pasted content: '),
              selection: const TextSelection.collapsed(offset: 16),
            );

            // The Clipboard requires a platform response, which doesn't exist
            // for widget tests. Pretend that we're the platform and handle
            // the incoming clipboard call.
            SystemChannels.platform.setMockMethodCallHandler((call) async {
              if (call.method == 'Clipboard.getData') {
                return {
                  'text': 'this is clipboard text',
                };
              }
            });

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isMetaPressed: true,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);

            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              // We have to run these expectations in the next frame
              // so that the async paste operation has time to complete.
              expect(controller.text.text, 'Pasted content: this is clipboard text');
              expect(controller.selection.isCollapsed, true);
              expect(controller.selection.extentOffset, 38);
            });

            Platform.setTestInstance(null);
          });

          test('control+v does NOT paste clipboard text', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isControlPressed: true,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores v-key without cmd', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isMetaPressed: false,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores cmd without v-key', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.metaLeft,
                  physicalKey: PhysicalKeyboardKey.metaLeft,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isMetaPressed: true,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });

        group('Windows + Linux', () {
          testWidgets('control+v pastes clipboard text', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            // Note: this is a widget test because we access the Clipboard.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'Pasted content: '),
              selection: const TextSelection.collapsed(offset: 16),
            );

            // The Clipboard requires a platform response, which doesn't exist
            // for widget tests. Pretend that we're the platform and handle
            // the incoming clipboard call.
            SystemChannels.platform.setMockMethodCallHandler((call) async {
              if (call.method == 'Clipboard.getData') {
                return {
                  'text': 'this is clipboard text',
                };
              }
            });

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isControlPressed: true,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);

            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              // We have to run these expectations in the next frame
              // so that the async paste operation has time to complete.
              expect(controller.text.text, 'Pasted content: this is clipboard text');
              expect(controller.selection.isCollapsed, true);
              expect(controller.selection.extentOffset, 38);
            });

            Platform.setTestInstance(null);
          });

          test('cmd+v does NOT paste clipboard text', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isMetaPressed: true,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores v-key without control', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isControlPressed: false,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores control without v-key', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.metaLeft,
                  physicalKey: PhysicalKeyboardKey.metaLeft,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final result = DefaultSuperTextFieldKeyboardHandlers.pasteTextWhenCmdVIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyV,
                  physicalKey: PhysicalKeyboardKey.keyV,
                  isControlPressed: true,
                ),
                character: 'v',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
      });

      group('select all', () {
        group('Mac', () {
          test('cmd+a selects all text', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isMetaPressed: true,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 17);

            Platform.setTestInstance(null);
          });

          test('control+a does NOT select all', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isControlPressed: true,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores a-key without cmd', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isMetaPressed: false,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores cmd without a-key', () {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.metaLeft,
                  physicalKey: PhysicalKeyboardKey.metaLeft,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });

        group('Windows + Linux', () {
          test('control+a selects all text', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isControlPressed: true,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 17);

            Platform.setTestInstance(null);
          });

          test('cmd+a does NOT select all', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isMetaPressed: true,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores a-key without control', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isControlPressed: false,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          test('it ignores control without a-key', () {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController();

            final result = DefaultSuperTextFieldKeyboardHandlers.selectAllTextFieldWhenCmdAIsPressed(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.metaLeft,
                  physicalKey: PhysicalKeyboardKey.metaLeft,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
      });

      group('move caret when arrow key is pressed', () {
        group('left arrow', () {
          testWidgets('it does nothing at beginning of text blob', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 0),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            // Move by character
            final characterResult = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                ),
                character: null,
              ),
            );

            expect(characterResult, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);

            // Move by word
            final wordResult = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isAltPressed: true,
                ),
                character: null,
              ),
            );

            expect(wordResult, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);

            // Move to end of line
            final lineResult = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(lineResult, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);
          });

          testWidgets('it moves left by character', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 2),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.extentOffset, 1);
            expect(controller.selection.isCollapsed, true);
          });

          testWidgets('it moves to previous line by character', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 18),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 17);

            // We should have gone from line 2 to line 1. Make double sure by
            // checking that the bounding box for the character that's now selected
            // sits at the top of the text box.
            //
            // The given offset is "16", which represents selection of the 17th
            // character.
            //
            // We give a tiny bit of wiggle room on the value because when this test
            // is run on Windows and Linux CI, there is some kind of precision error
            // that results in a tiny positive number instead of zero.
            expect(selectableTextState.getCharacterBox(const TextPosition(offset: 16)).top, lessThan(0.1));
            expect(selectableTextState.getCharacterBox(const TextPosition(offset: 16)).top, greaterThanOrEqualTo(0));
          });

          testWidgets('it expands left by character', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 2),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 2);
            expect(controller.selection.extentOffset, 1);
          });

          testWidgets('it moves left by word', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 10),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isAltPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.extentOffset, 6);
            expect(controller.selection.isCollapsed, true);
          });

          testWidgets('it expands left by word', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 10),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isAltPressed: true,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 10);
            expect(controller.selection.extentOffset, 6);
          });

          testWidgets('Mac: cmd+left moves left to beginning of line', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 10),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.extentOffset, 0);
            expect(controller.selection.isCollapsed, true);

            Platform.setTestInstance(null);
          });

          testWidgets('Windows + Linux: control + left moves left to beginning of line', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 10),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.extentOffset, 0);
            expect(controller.selection.isCollapsed, true);

            Platform.setTestInstance(null);
          });

          testWidgets('Mac: cmd + shift + left expands left to beginning of line', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 10),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isMetaPressed: true,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 10);
            expect(controller.selection.extentOffset, 0);

            Platform.setTestInstance(null);
          });

          testWidgets('Windows + Linux: control + shift + left expands left to beginning of line', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 10),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                  isControlPressed: true,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 10);
            expect(controller.selection.extentOffset, 0);

            Platform.setTestInstance(null);
          });

          testWidgets('it collapses downstream selection on left side', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection(
                baseOffset: 6,
                extentOffset: 10,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 6);
          });

          testWidgets('it collapses upstream selection on left side', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection(
                baseOffset: 10,
                extentOffset: 6,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowLeft,
                  physicalKey: PhysicalKeyboardKey.arrowLeft,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 6);
          });
        });

        group('right arrow', () {
          testWidgets('it does nothing at end of text blob', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 16),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            // Move by character
            final characterResult = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                ),
                character: null,
              ),
            );

            expect(characterResult, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 16);

            // Move by word
            final wordResult = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isAltPressed: true,
                ),
                character: null,
              ),
            );

            expect(wordResult, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 16);

            // Move to end of line
            final lineResult = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(lineResult, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 16);
          });

          testWidgets('it moves right by character', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 2),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 3);
          });

          testWidgets('it moves to next line by character', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 17),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 18);

            // We should have gone from line 1 to line 2. Make double sure by
            // checking that the bounding box for the character that's now selected
            // does not sit at the top of the text box.
            expect(selectableTextState.getCharacterBox(const TextPosition(offset: 18)).top, isNonZero);
          });

          testWidgets('it expands right by character', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 2),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 2);
            expect(controller.selection.extentOffset, 3);
          });

          testWidgets('it moves right by word', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 6),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isAltPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 10);
          });

          testWidgets('it expands right by word', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 6),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isAltPressed: true,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 6);
            expect(controller.selection.extentOffset, 10);
          });

          testWidgets('Mac: cmd + right moves right to end of line', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 6),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 16);

            Platform.setTestInstance(null);
          });

          testWidgets('Windows + Linux: control + right moves right to end of line', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 6),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 16);

            Platform.setTestInstance(null);
          });

          testWidgets('Mac: cmd + shift + right expands right to end of line', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 6),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isMetaPressed: true,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 6);
            expect(controller.selection.extentOffset, 16);

            Platform.setTestInstance(null);
          });

          testWidgets('Windows + Linux: control + shift + right expands right to end of line', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection.collapsed(offset: 6),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                  isControlPressed: true,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.baseOffset, 6);
            expect(controller.selection.extentOffset, 16);

            Platform.setTestInstance(null);
          });

          testWidgets('it collapses downstream selection on right side', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection(
                baseOffset: 6,
                extentOffset: 10,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 10);
          });

          testWidgets('it collapses upstream selection on right side', (tester) async {
            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'super text field'),
              selection: const TextSelection(
                baseOffset: 10,
                extentOffset: 6,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowRight,
                  physicalKey: PhysicalKeyboardKey.arrowRight,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 10);
          });
        });

        group('up arrow', () {
          testWidgets('it moves to start of text when in first line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowUp,
                  physicalKey: PhysicalKeyboardKey.arrowUp,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);
          });

          testWidgets('it moves to previous line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 18),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowUp,
                  physicalKey: PhysicalKeyboardKey.arrowUp,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);
          });

          testWidgets('it expands to previous line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 18),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowUp,
                  physicalKey: PhysicalKeyboardKey.arrowUp,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.extentOffset, 0);
            expect(controller.selection.baseOffset, 18);
          });

          testWidgets('it preserves horizontal position in previous line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 23),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowUp,
                  physicalKey: PhysicalKeyboardKey.arrowUp,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 5);
          });
        });

        group('down arrow', () {
          testWidgets('it moves to end of text when in last line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 50),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowDown,
                  physicalKey: PhysicalKeyboardKey.arrowDown,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, _multilineLayoutText.length);
          });

          testWidgets('it moves to next line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 0),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowDown,
                  physicalKey: PhysicalKeyboardKey.arrowDown,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 18);
          });

          testWidgets('it expands to next line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 0),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowDown,
                  physicalKey: PhysicalKeyboardKey.arrowDown,
                  isShiftPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, false);
            expect(controller.selection.extentOffset, 18);
            expect(controller.selection.baseOffset, 0);
          });

          testWidgets('it preserves horizontal position in next line', (tester) async {
            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveUpDownLeftAndRightWithArrowKeys(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.arrowDown,
                  physicalKey: PhysicalKeyboardKey.arrowDown,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 23);
          });
        });
      });

      group('delete line before caret', () {
        group('Mac', () {
          testWidgets('cmd + backspace deletes partial line before caret (flowed multiline)', (tester) async {
            Platform.setTestInstance(MacPlatform());

            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 28), // midway through 2nd line
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 18);
            expect(controller.text.text, 'this text is long be multiline in the available space');

            Platform.setTestInstance(null);
          });

          testWidgets('cmd + backspace deletes entire line (flowed multiline)', (tester) async {
            Platform.setTestInstance(MacPlatform());

            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 31, affinity: TextAffinity.upstream), // end of 2nd line
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 18);
            expect(controller.text.text, 'this text is long multiline in the available space');

            Platform.setTestInstance(null);
          });

          testWidgets('cmd + backspace deletes partial line before caret (explicit newlines)', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is line 1\nThis is line 2\nThis is line 3'),
              selection: const TextSelection.collapsed(offset: 23), // midway through 2nd line
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 15);
            expect(controller.text.text, 'This is line 1\nline 2\nThis is line 3');

            Platform.setTestInstance(null);
          });

          testWidgets('cmd + backspace deletes entire line (explicit newlines)', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is line 1\nThis is line 2\nThis is line 3'),
              selection: const TextSelection.collapsed(offset: 29, affinity: TextAffinity.upstream), // end of 2nd line
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 15);
            expect(controller.text.text, 'This is line 1\n\nThis is line 3');

            Platform.setTestInstance(null);
          });

          testWidgets('deletes selection when selection is expanded', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection(
                baseOffset: 0,
                extentOffset: 10,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, 'is long enough to be multiline in the available space');

            Platform.setTestInstance(null);
          });

          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          testWidgets('it does nothing when selection is at start of line', (tester) async {
            Platform.setTestInstance(MacPlatform());

            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 18), // start of 2nd line
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isMetaPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });

        group('Windows + Linux', () {
          testWidgets('control + backspace deletes partial line before caret (flowed multiline)', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 28), // midway through 2nd line
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 18);
            expect(controller.text.text, 'this text is long be multiline in the available space');

            Platform.setTestInstance(null);
          });

          testWidgets('control + backspace deletes entire line (flowed multiline)', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 31, affinity: TextAffinity.upstream), // end of 2nd line
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 18);
            expect(controller.text.text, 'this text is long multiline in the available space');

            Platform.setTestInstance(null);
          });

          testWidgets('control + backspace deletes partial line before caret (explicit newlines)', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is line 1\nThis is line 2\nThis is line 3'),
              selection: const TextSelection.collapsed(offset: 23), // midway through 2nd line
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 15);
            expect(controller.text.text, 'This is line 1\nline 2\nThis is line 3');

            Platform.setTestInstance(null);
          });

          testWidgets('control + backspace deletes entire line (explicit newlines)', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is line 1\nThis is line 2\nThis is line 3'),
              selection: const TextSelection.collapsed(offset: 29, affinity: TextAffinity.upstream), // end of 2nd line
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 15);
            expect(controller.text.text, 'This is line 1\n\nThis is line 3');

            Platform.setTestInstance(null);
          });

          testWidgets('deletes selection when selection is expanded', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection(
                baseOffset: 0,
                extentOffset: 10,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, 'is long enough to be multiline in the available space');

            Platform.setTestInstance(null);
          });

          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });

          testWidgets('it does nothing when selection is at start of line', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            // Note: this test depends on a multi-line text layout, therefore
            // the layout width and the text content must be precise.
            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection.collapsed(offset: 18), // start of 2nd line
            );

            final selectableTextState = await _pumpMultilineLayout(tester);

            final result =
                DefaultSuperTextFieldKeyboardHandlers.deleteTextOnLineBeforeCaretWhenShortcutKeyAndBackspaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isControlPressed: true,
                ),
                character: null,
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
      });

      group('backspace pressed', () {
        test('it does nothing when text is empty', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: ''),
            selection: const TextSelection.collapsed(offset: 0),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.backspace,
                physicalKey: PhysicalKeyboardKey.backspace,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 0);
          expect(controller.text.text, '');
        });

        test('it does nothing at beginning of text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection.collapsed(offset: 0),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.backspace,
                physicalKey: PhysicalKeyboardKey.backspace,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 0);
          expect(controller.text.text, 'this is some text');
        });

        test('it deletes the previous character', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection.collapsed(offset: 2),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.backspace,
                physicalKey: PhysicalKeyboardKey.backspace,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 1);
          expect(controller.text.text, 'tis is some text');
        });

        test('it deletes selected text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection(
              baseOffset: 8,
              extentOffset: 13,
            ),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.backspace,
                physicalKey: PhysicalKeyboardKey.backspace,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 8);
          expect(controller.text.text, 'this is text');
        });
      });

      group('delete pressed', () {
        test('it does nothing when text is empty', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: ''),
            selection: const TextSelection.collapsed(offset: 0),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.delete,
                physicalKey: PhysicalKeyboardKey.delete,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 0);
          expect(controller.text.text, '');
        });

        test('it does nothing at beginning of text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection.collapsed(offset: 17),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.delete,
                physicalKey: PhysicalKeyboardKey.delete,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 17);
          expect(controller.text.text, 'this is some text');
        });

        test('it deletes the next character', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection.collapsed(offset: 2),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.delete,
                physicalKey: PhysicalKeyboardKey.delete,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 2);
          expect(controller.text.text, 'ths is some text');
        });

        test('it deletes selected text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection(
              baseOffset: 8,
              extentOffset: 13,
            ),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.deleteTextWhenBackspaceOrDeleteIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.delete,
                physicalKey: PhysicalKeyboardKey.delete,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 8);
          expect(controller.text.text, 'this is text');
        });
      });

      group('insert newline when enter is pressed', () {
        test('inserts newline in middle of text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection.collapsed(offset: 8),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.insertNewlineWhenEnterIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.enter,
                physicalKey: PhysicalKeyboardKey.enter,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 9);
          expect(controller.text.text, 'this is \nsome text');
        });

        test('inserts newline at beginning of text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection.collapsed(offset: 0),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.insertNewlineWhenEnterIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.enter,
                physicalKey: PhysicalKeyboardKey.enter,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 1);
          expect(controller.text.text, '\nthis is some text');
        });

        test('inserts newline at end of text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: 'this is some text'),
            selection: const TextSelection.collapsed(offset: 17),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.insertNewlineWhenEnterIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.enter,
                physicalKey: PhysicalKeyboardKey.enter,
              ),
              character: null,
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 18);
          expect(controller.text.text, 'this is some text\n');
        });
      });

      group('insert character when key is pressed', () {
        test('inserts character in empty text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: ''),
            selection: const TextSelection.collapsed(offset: 0),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.insertCharacterWhenKeyIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.keyF,
                physicalKey: PhysicalKeyboardKey.keyF,
              ),
              character: 'f',
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 1);
          expect(controller.text.text, 'f');
        });

        test('inserts character in middle of text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: '--><--'),
            selection: const TextSelection.collapsed(offset: 3),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.insertCharacterWhenKeyIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.keyF,
                physicalKey: PhysicalKeyboardKey.keyF,
              ),
              character: 'f',
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 4);
          expect(controller.text.text, '-->f<--');
        });

        test('inserts character at end of text', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: '-->'),
            selection: const TextSelection.collapsed(offset: 3),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.insertCharacterWhenKeyIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.keyF,
                physicalKey: PhysicalKeyboardKey.keyF,
              ),
              character: 'f',
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 4);
          expect(controller.text.text, '-->f');
        });

        test('replaces selected text with character', () {
          final controller = AttributedTextEditingController(
            text: AttributedText(text: '-->REPLACE<--'),
            selection: const TextSelection(baseOffset: 3, extentOffset: 10),
          );

          final result = DefaultSuperTextFieldKeyboardHandlers.insertCharacterWhenKeyIsPressed(
            controller: controller,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.keyF,
                physicalKey: PhysicalKeyboardKey.keyF,
              ),
              character: 'f',
            ),
          );

          expect(result, TextFieldKeyboardHandlerResult.handled);
          expect(controller.selection.isCollapsed, true);
          expect(controller.selection.extentOffset, 4);
          expect(controller.text.text, '-->f<--');
        });
      });

      group("move caret to start/end of line", () {
        group("MacOS", () {
          testWidgets('caret in middle of line, Ctl+A moves caret to start', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isControlPressed: true,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 0);

            Platform.setTestInstance(null);
          });
          testWidgets('caret in middle of line, Ctl+E moves caret to end', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyE,
                  physicalKey: PhysicalKeyboardKey.keyE,
                  isControlPressed: true,
                ),
                character: 'e',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 17);
            expect(controller.selection.extentOffset, 17);

            Platform.setTestInstance(null);
          });
          testWidgets('caret at start, Ctl+A does nothing', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 0),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isControlPressed: true,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 0);

            Platform.setTestInstance(null);
          });
          testWidgets('caret at end, Ctl+E does nothing', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 17),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyE,
                  physicalKey: PhysicalKeyboardKey.keyE,
                  isControlPressed: true,
                ),
                character: 'e',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 17);
            expect(controller.selection.extentOffset, 17);

            Platform.setTestInstance(null);
          });
          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final result = DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd(
              controller: controller,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyE,
                  physicalKey: PhysicalKeyboardKey.keyE,
                  isControlPressed: true,
                ),
                character: 'e',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
        group("Windows", () {
          testWidgets('Ctl+A does nothing', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyA,
                  physicalKey: PhysicalKeyboardKey.keyA,
                  isControlPressed: true,
                ),
                character: 'a',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
          testWidgets('Ctl+E does nothing', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 5),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.moveCaretToStartOrEnd(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.keyE,
                  physicalKey: PhysicalKeyboardKey.keyE,
                  isControlPressed: true,
                ),
                character: 'e',
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
      });

      group("delete word by word", () {
        group("MacOS", () {
          testWidgets('caret at end of word, Alt+Backspace deletes the word', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 4), //this|
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, " is some text");

            Platform.setTestInstance(null);
          });
          testWidgets('caret at middle of word, Alt+Backspace deletes until beginning of word', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 2), //th|is
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, "is is some text");

            Platform.setTestInstance(null);
          });
          testWidgets('caret at start of word, Alt+Backspace deletes previous word', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 8), //this is |some
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 5);
            expect(controller.selection.extentOffset, 5);
            expect(controller.text.text, "this some text");

            Platform.setTestInstance(null);
          });
          testWidgets('selection is expanded, Alt+Backspace deletes selection', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection(
                baseOffset: 0,
                extentOffset: 10,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, 'is long enough to be multiline in the available space');

            Platform.setTestInstance(null);
          });
          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
        group("Windows", () {
          testWidgets('caret at end of word, Alt+Backspace deletes the word', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 4), //this|
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, " is some text");

            Platform.setTestInstance(null);
          });
          testWidgets('caret at middle of word, Alt+Backspace deletes until beginning of word', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 2), //th|is
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 0);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, "is is some text");

            Platform.setTestInstance(null);
          });
          testWidgets('caret at start of word, Alt+Backspace deletes previous word', (tester) async {
            Platform.setTestInstance(MacPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'this is some text'),
              selection: const TextSelection.collapsed(offset: 8), //this is |some
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.baseOffset, 5);
            expect(controller.selection.extentOffset, 5);
            expect(controller.text.text, "this some text");

            Platform.setTestInstance(null);
          });
          testWidgets('selection is expanded, Alt+Backspace deletes selection', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: _multilineLayoutText),
              selection: const TextSelection(
                baseOffset: 0,
                extentOffset: 10,
              ),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.handled);
            expect(controller.selection.isCollapsed, true);
            expect(controller.selection.extentOffset, 0);
            expect(controller.text.text, 'is long enough to be multiline in the available space');

            Platform.setTestInstance(null);
          });
          testWidgets('it does nothing when caret is not focused on any text', (tester) async {
            Platform.setTestInstance(WindowsPlatform());

            final controller = AttributedTextEditingController(
              text: AttributedText(text: 'This is some text that doesn\'t matter for this test.'),
              selection: const TextSelection.collapsed(offset: -1),
            );

            final selectableTextState = await _pumpAndReturnSelectableText(tester, controller.text.text);

            final result = DefaultSuperTextFieldKeyboardHandlers.deleteWordWhenAltBackSpaceIsPressed(
              controller: controller,
              selectableTextState: selectableTextState,
              keyEvent: const FakeRawKeyEvent(
                data: FakeRawKeyEventData(
                  logicalKey: LogicalKeyboardKey.backspace,
                  physicalKey: PhysicalKeyboardKey.backspace,
                  isAltPressed: true,
                ),
              ),
            );

            expect(result, TextFieldKeyboardHandlerResult.notHandled);

            Platform.setTestInstance(null);
          });
        });
      });
    });
  });
}

const _multilineLayoutText = 'this text is long enough to be multiline in the available space';

// Based on experiments, the text is laid out as follows:
//
//  (0)this text is long (18 - upstream)
// (18)enough to be (31 - upstream)
// (31)multiline in the (48 - upstream)
// (48)available space(63)
Future<SuperSelectableTextState> _pumpMultilineLayout(
  WidgetTester tester,
) async {
  final selectableText = await _pumpAndReturnSelectableText(
    tester,
    _multilineLayoutText,
    (Widget child) {
      return SizedBox(
        width: 300,
        child: child,
      );
    },
  );

  // The following code prints the bounding box for every
  // character of text in the layout. You can use that info
  // to figure out where line breaks occur.
  // for (int i = 0; i < _multilineLayoutText.length; ++i) {
  //   print('$i: ${selectableText.getCharacterBox(TextPosition(offset: i))}');
  // }

  return selectableText;
}

Future<SuperSelectableTextState> _pumpAndReturnSelectableText(
  WidgetTester tester,
  String text, [
  Widget Function(Widget child)? decorator,
]) async {
  final textKey = GlobalKey<SuperSelectableTextState>();

  final selectableText = SuperSelectableText.plain(
    key: textKey,
    text: text,
    style: const TextStyle(),
  );

  final decoratedText = decorator == null ? selectableText : decorator(selectableText);

  await tester.pumpWidget(
    MaterialApp(
      // The Center allows the content to be smaller than the display
      home: Center(
        child: decoratedText,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return textKey.currentState!;
}
