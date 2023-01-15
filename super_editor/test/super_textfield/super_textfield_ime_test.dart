import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

void main() {
  group('SuperTextField', () {
    group('with IME input source', () {
      group('inserts character', () {
        testWidgetsOnAllPlatforms('in empty text', (tester) async {
          await _pumpEmptySuperTextField(tester);
          await tester.placeCaretInSuperTextField(0);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().text, "f");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnAllPlatforms('in middle of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(text: '--><--'),
            ),
          );
          await tester.placeCaretInSuperTextField(3);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().text, "-->f<--");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnAllPlatforms('at end of text', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(text: '-->'),
            ),
          );
          await tester.placeCaretInSuperTextField(3);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().text, "-->f");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });

        testWidgetsOnAllPlatforms('and replaces selected text', (tester) async {
          // TODO: We create the controller outside the pump so that we can explicitly set its selection
          //  because we don't support gesture selection on mobile, yet.
          final controller = AttributedTextEditingController(
            text: AttributedText(text: '-->REPLACE<--'),
          );
          await _pumpSuperTextField(
            tester,
            controller,
          );

          // TODO: switch this to gesture selection when we support that on mobile
          controller.selection = const TextSelection(baseOffset: 3, extentOffset: 10);

          await tester.ime.typeText("f", getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().text, "-->f<--");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 4));
        });
      });

      // TODO: implement newline tests when SuperTextField supports configuration of the action button
      //   group('inserts line', () {
      //     testWidgetsOnDesktop('when ENTER is pressed in middle of text', (tester) async {
      //       await _pumpSuperTextField(
      //         tester,
      //         AttributedTextEditingController(
      //           text: AttributedText(text: 'this is some text'),
      //         ),
      //       );
      //       await tester.placeCaretInSuperTextField(8);
      //
      //       await tester.pressEnter();
      //
      //       expect(SuperTextFieldInspector.findText().text, "this is \nsome text");
      //       expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 9));
      //     });
      //
      //     testWidgetsOnDesktop('when ENTER is pressed at beginning of text', (tester) async {
      //       await _pumpSuperTextField(
      //         tester,
      //         AttributedTextEditingController(
      //           text: AttributedText(text: 'this is some text'),
      //         ),
      //       );
      //       await tester.placeCaretInSuperTextField(0);
      //
      //       await tester.pressEnter();
      //
      //       expect(SuperTextFieldInspector.findText().text, "\nthis is some text");
      //       expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
      //     });
      //
      //     testWidgetsOnDesktop('when ENTER is pressed at end of text', (tester) async {
      //       await _pumpSuperTextField(
      //         tester,
      //         AttributedTextEditingController(
      //           text: AttributedText(text: 'this is some text'),
      //         ),
      //       );
      //       await tester.placeCaretInSuperTextField(17);
      //
      //       await tester.pressEnter();
      //
      //       expect(SuperTextFieldInspector.findText().text, "this is some text\n");
      //       expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 18));
      //     });
      //   });
      //
      group('delete text', () {
        testWidgetsOnAllPlatforms('BACKSPACE does nothing when text is empty', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(text: ""),
            ),
          );
          await tester.placeCaretInSuperTextField(0);

          await tester.ime.backspace(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().text, "");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
        });

        testWidgetsOnAllPlatforms('BACKSPACE deletes the previous character', (tester) async {
          await _pumpSuperTextField(
            tester,
            AttributedTextEditingController(
              text: AttributedText(text: "this is some text"),
            ),
          );
          await tester.placeCaretInSuperTextField(2);

          await tester.ime.backspace(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findText().text, "tis is some text");
          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 1));
        });

        testWidgetsOnAllPlatforms('BACKSPACE deletes selection when selection is expanded', (tester) async {
          // TODO: We create the controller outside the pump so that we can explicitly set its selection
          //  because we don't support gesture selection on mobile, yet.
          final controller = AttributedTextEditingController(
            text: AttributedText(text: _multilineLayoutText),
          );
          await _pumpSuperTextField(
            tester,
            controller,
          );

          // TODO: switch this to gesture selection when we support that on mobile
          controller.selection = const TextSelection(baseOffset: 0, extentOffset: 10);

          await tester.ime.backspace(getter: imeClientGetter);

          expect(SuperTextFieldInspector.findSelection(), const TextSelection.collapsed(offset: 0));
          expect(SuperTextFieldInspector.findText().text, "is long enough to be multiline in the available space");
        });
      });
    });

    testWidgetsOnMobile('configures the software keyboard action button', (tester) async {
      await tester.pumpWidget(
        _buildScaffold(
          child: const SuperTextField(
            textInputAction: TextInputAction.next,
          ),
        ),
      );

      // Holds the keyboard input action sent to the platform.
      String? inputAction;

      // Intercept messages sent to the platform.
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(SystemChannels.textInput.name, (message) async {
        final methodCall = const JSONMethodCodec().decodeMethodCall(message);
        if (methodCall.method == 'TextInput.setClient') {
          final params = methodCall.arguments[1] as Map;
          inputAction = params['inputAction'];
        }
        return null;
      });

      // Tap the text field to show the software keyboard.
      await tester.placeCaretInSuperTextField(0);

      // Ensure the given TextInputAction was applied.
      expect(inputAction, 'TextInputAction.next');
    });

    testWidgetsOnAllPlatforms('disconnects from IME when disposed', (tester) async {
      final controller = ImeAttributedTextEditingController();
      await _pumpSuperTextField(tester, controller);

      // Place the caret to open an IME connection.
      await tester.placeCaretInSuperTextField(0);

      // Ensure the IME connection is open.
      expect(controller.isAttachedToIme, isTrue);

      // Pump a different tree to cause the text field to dispose.
      await tester.pumpWidget(const MaterialApp());

      // Ensure the IME connection is closed.
      expect(controller.isAttachedToIme, isFalse);
    });
  });

  group('SuperTextField on some bad Android software keyboards', () {
    testWidgetsOnAndroid('handles BACKSPACE key event instead of deletion for a collapsed selection (on Android)',
        (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: 'This is a text'),
      );
      await _pumpScaffoldForBuggyKeyboards(tester, controller: controller);

      // Focus the text field
      // TODO: change to use the robot when mobile is supported
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Place caret at This|. We don't put caret at the end of the text
      // to ensure we are not deleting always the last character
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.pressBackspace();

      // Ensure text is deleted
      expect(controller.text.text, 'Thi is a text');
    });

    testWidgetsOnAndroid('handles BACKSPACE key event instead of deletion for a expanded selection (on Android)',
        (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(text: 'This is a text'),
      );
      await _pumpScaffoldForBuggyKeyboards(tester, controller: controller);

      // Focus the text field
      // TODO: change to use the robot when mobile is supported
      await tester.tapAt(tester.getCenter(find.byType(SuperTextField)));
      await tester.pump();

      // Selects ' text'
      controller.selection = const TextSelection(
        baseOffset: 9,
        extentOffset: 14,
      );
      await tester.pump();

      await tester.pressBackspace();

      // Ensure text is deleted
      expect(controller.text.text, 'This is a');
    });
  });
}

// Based on experiments, the text is laid out as follows (at 320px wide):
//
//  (0)this text is long (18 - upstream)
// (18)enough to be (31 - upstream)
// (31)multiline in the (48 - upstream)
// (48)available space(63)
const _multilineLayoutText = 'this text is long enough to be multiline in the available space';

Future<void> _pumpEmptySuperTextField(WidgetTester tester) async {
  await _pumpSuperTextField(
    tester,
    AttributedTextEditingController(text: AttributedText(text: '')),
  );
}

Future<void> _pumpSuperTextField(
  WidgetTester tester,
  AttributedTextEditingController controller, {
  int? minLines,
  int? maxLines,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The Center allows the content to be smaller than the display
      home: Center(
        // This SizedBox, combined with the font size in the TextStyle,
        // determines the text line wrapping, which is critical for the
        // tests in this suite.
        child: SizedBox(
          width: 320,
          child: SuperTextField(
            textController: controller,
            inputSource: TextInputSource.ime,
            minLines: minLines,
            maxLines: maxLines,
            lineHeight: 18,
            textStyleBuilder: (_) {
              return const TextStyle(
                // This font size, combined with the layout width below, are
                // critical to determining the text line wrapping.
                fontSize: 18,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The following code prints the bounding box for every
  // character of text in the layout. You can use that info
  // to figure out where line breaks occur.
  // final textLayout = SuperTextFieldInspector.findProseTextLayout();
  // for (int i = 0; i < _multilineLayoutText.length; ++i) {
  //   print('$i: ${textLayout.getCharacterBox(TextPosition(offset: i))}');
  // }
}

Future<void> _pumpScaffoldForBuggyKeyboards(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300),
          child: SuperTextField(
            textController: controller,
          ),
        ),
      ),
    ),
  );
}

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: child,
      ),
    ),
  );
}
