import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

class AppShortcutsDemo extends StatefulWidget {
  @override
  _AppShortcutsDemoState createState() => _AppShortcutsDemoState();
}

class _AppShortcutsDemoState extends State<AppShortcutsDemo> {
  String _message = '';

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Shortcuts(
        // autofocus: true,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.digit1, meta: true): MetaAndDigitIntent(1),
          SingleActivator(LogicalKeyboardKey.digit2, meta: true): MetaAndDigitIntent(2),
          SingleActivator(LogicalKeyboardKey.digit3, meta: true): MetaAndDigitIntent(3),
        },
        child: Actions(
          actions: {
            MetaAndDigitIntent: CallbackAction<MetaAndDigitIntent>(
              onInvoke: (intent) => setState(
                () => _message = 'Meta + ${intent.value}',
              ),
            ),
          },
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SuperEditor(
                    editor: DocumentEditor(
                      document: MutableDocument(
                        nodes: [
                          ParagraphNode(
                            id: DocumentEditor.createNodeId(),
                            text: AttributedText(text: 'Random paragraph....'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const TextField(
                  decoration: InputDecoration(
                    hintText: "Text goes here",
                  ),
                ),
                Text(_message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MetaAndDigitIntent extends Intent {
  const MetaAndDigitIntent(this.value);
  final int value;
}
