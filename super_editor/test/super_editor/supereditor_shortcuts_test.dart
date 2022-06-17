import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'supereditor_robot.dart';

void main() {
  group("SuperEditor shortcuts", () {
    testWidgetsOnDesktop("overrides ancestor Shortcut widgets", (tester) async {
      bool didTriggerAncestorShortcut = false;
      await _pumpShortcutsAndSuperEditor(
        tester,
        // The default keyboard actions include an ENTER handler.
        defaultKeyboardActions,
        () {
          didTriggerAncestorShortcut = true;
        },
      );
      await tester.placeCaretInParagraph("1", 0);

      // Press ENTER, which we expect to be handled by SuperEditor.
      await tester.pressEnter();

      // Ensure that the ancestor Shortcuts widget didn't receive
      // the ENTER key.
      expect(didTriggerAncestorShortcut, false);
    });

    testWidgetsOnDesktop("defers to ancestor Shortcut widgets when requested", (tester) async {
      int ancestorTriggerCount = 0;
      await _pumpShortcutsAndSuperEditor(
        tester,
        [
          ignoreKeyCombos([
            const KeyCombo(key: LogicalKeyboardKey.enter),
            const KeyCombo(key: LogicalKeyboardKey.arrowRight, isShiftPressed: true),
          ]),
          ...defaultKeyboardActions,
        ],
        () {
          ancestorTriggerCount += 1;
        },
      );
      await tester.placeCaretInParagraph("1", 0);

      // Press ENTER, which we expect to defer to the ancestor Shortcuts.
      await tester.pressEnter();
      // Press SHIFT + RIGHT ARROW, which we expect to defer to the ancestor
      // Shortcuts. We test this combination to make sure that SuperEditor
      // considers modifier keys, too.
      await tester.pressShiftRightArrow();

      // Ensure that the ancestor Shortcuts widget received the key combos.
      expect(ancestorTriggerCount, 2);
    });
  });
}

Future<void> _pumpShortcutsAndSuperEditor(
  WidgetTester tester,
  List<DocumentKeyboardAction> keyboardActions,
  VoidCallback onShortcut,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Shortcuts(
          shortcuts: {
            // These activators should only trigger when the child
            // SuperEditor explicitly ignores these keys.
            const SingleActivator(LogicalKeyboardKey.enter): VoidCallbackIntent(onShortcut),
            const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): VoidCallbackIntent(onShortcut),
          },
          child: SuperEditor(
            editor: DocumentEditor(
              document: MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText(text: "")),
                ],
              ),
            ),
            keyboardActions: keyboardActions,
          ),
        ),
      ),
    ),
  );
}
