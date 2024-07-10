import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

class AppShortcutsDemo extends StatefulWidget {
  @override
  State<AppShortcutsDemo> createState() => _AppShortcutsDemoState();
}

class _AppShortcutsDemoState extends State<AppShortcutsDemo> {
  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  String _message = '';

  @override
  void initState() {
    super.initState();

    _doc = MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText('Random paragraph....'),
        ),
      ],
    );
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

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
                  child: SuperEditor(editor: _editor),
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
