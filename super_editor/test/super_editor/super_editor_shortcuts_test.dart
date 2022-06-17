import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("SuperEditor shortcuts", () {
    testWidgets("overrides ancestor Shortcut widgets", (tester) async {
      bool didTriggerShortcut = false;
      await _pumpShortcutsAndSuperEditor(tester, () {
        didTriggerShortcut = true;
      });

      // TODO:
    });

    testWidgets("defers to ancestor Shortcut widgets when requested", (tester) async {
      // TODO:
    });
  });
}

Future<void> _pumpShortcutsAndSuperEditor(WidgetTester tester, VoidCallback onTab) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.tab): VoidCallbackIntent(onTab),
          },
          child: SuperEditor(
            editor: DocumentEditor(
              document: MutableDocument(
                nodes: [
                  ParagraphNode(id: "1", text: AttributedText(text: "")),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
