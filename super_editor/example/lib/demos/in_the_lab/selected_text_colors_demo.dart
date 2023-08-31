import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class SelectedTextColorsDemo extends StatefulWidget {
  const SelectedTextColorsDemo({super.key});

  @override
  State<SelectedTextColorsDemo> createState() => _SelectedTextColorsDemoState();
}

class _SelectedTextColorsDemoState extends State<SelectedTextColorsDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument(nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
            "SuperEditor can dynamically change color of selected text to better contrast with the highlight."),
      ),
    ]);
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        ...defaultRequestHandlers,
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InTheLabScaffold(
      supplemental: _buildControlPanel(),
      child: Center(
        child: IntrinsicHeight(
          child: _buildEditor(),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return SuperEditor(
      editor: _editor,
      document: _document,
      composer: _composer,
      stylesheet: defaultStylesheet.copyWith(
        selectedTextColorStrategy: _selectedTextColorStrategy,
        inlineTextStyler: (attributions, existingStyle) {
          TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

          if (attributions.whereType<PatternTagAttribution>().isNotEmpty) {
            style = style.copyWith(
              color: Colors.orange,
            );
          }

          return style;
        },
        addRulesAfter: [
          ...darkModeStyles,
        ],
      ),
      documentOverlayBuilders: [
        DefaultCaretOverlayBuilder(
          caretStyle: CaretStyle().copyWith(color: Colors.redAccent),
        ),
      ],
    );
  }

  Color _selectedTextColorStrategy({required Color originalTextColor, required Color selectionHighlightColor}) {
    return Colors.black;
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text("HELLO"),
    );
  }
}
