import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

class SpellingErrorDecorationsDemo extends StatefulWidget {
  const SpellingErrorDecorationsDemo({super.key});

  @override
  State<SpellingErrorDecorationsDemo> createState() => _SpellingErrorDecorationsDemoState();
}

class _SpellingErrorDecorationsDemoState extends State<SpellingErrorDecorationsDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  var _decoration = _DecorationType.line;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument(nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          "SuperEditor cna sytle spelling error attribtions with various decorations, including custom decorations.",
          AttributedSpans(
            attributions: [
              SpanMarker(attribution: spellingErrorAttribution, offset: 12, markerType: SpanMarkerType.start),
              SpanMarker(attribution: spellingErrorAttribution, offset: 14, markerType: SpanMarkerType.end),
              SpanMarker(attribution: spellingErrorAttribution, offset: 16, markerType: SpanMarkerType.start),
              SpanMarker(attribution: spellingErrorAttribution, offset: 20, markerType: SpanMarkerType.end),
              SpanMarker(attribution: spellingErrorAttribution, offset: 37, markerType: SpanMarkerType.start),
              SpanMarker(attribution: spellingErrorAttribution, offset: 47, markerType: SpanMarkerType.end),
            ],
          ),
        ),
      ),
    ]);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _document, composer: _composer);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InTheLabScaffold(
      content: Center(
        child: IntrinsicHeight(
          child: _buildEditor(),
        ),
      ),
      supplemental: _buildControlPanel(),
    );
  }

  Widget _buildEditor() {
    return SuperEditor(
      editor: _editor,
      componentBuilders: [
        SpellingErrorParagraphComponentBuilder(_decoration.style),
        ...defaultComponentBuilders,
      ],
      stylesheet: defaultStylesheet.copyWith(
        addRulesAfter: [
          ...darkModeStyles,
          StyleRule(
            BlockSelector.all,
            (doc, docNode) {
              print("Processing StyleRule for node: ${docNode}");
              return {
                Styles.spellingErrorUnderlineStyle: SquiggleUnderlineStyle(color: Colors.blue),
              };
            },
          ),
        ],
      ),
      documentOverlayBuilders: [
        DefaultCaretOverlayBuilder(
          caretStyle: CaretStyle().copyWith(color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            label: "Line",
            isEnabled: _decoration != _DecorationType.line,
            onPressed: () {
              setState(() {
                _decoration = _DecorationType.line;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildButton(
            label: "Dots",
            isEnabled: _decoration != _DecorationType.dots,
            onPressed: () {
              setState(() {
                _decoration = _DecorationType.dots;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildButton(
            label: "Squiggles",
            isEnabled: _decoration != _DecorationType.squiggles,
            onPressed: () {
              setState(() {
                _decoration = _DecorationType.squiggles;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    bool isEnabled = true,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      child: Text(label),
    );
  }
}

enum _DecorationType {
  line,
  dots,
  squiggles;

  UnderlineStyle get style {
    switch (this) {
      case _DecorationType.line:
        return StraightUnderlineStyle(
          color: Colors.red,
        );
      case _DecorationType.dots:
        return DottedUnderlineStyle();
      case _DecorationType.squiggles:
        return SquiggleUnderlineStyle();
    }
  }
}

class SpellingErrorParagraphComponentBuilder implements ComponentBuilder {
  const SpellingErrorParagraphComponentBuilder(this.underlineStyle);

  final UnderlineStyle underlineStyle;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    final viewModel = ParagraphComponentBuilder().createViewModel(document, node) as ParagraphComponentViewModel?;
    if (viewModel == null) {
      return null;
    }

    print("Creating paragraph view model with style: $underlineStyle");
    return viewModel
      ..spellingErrorUnderlineStyle = underlineStyle
      ..spellingErrors = (node as TextNode)
          .text
          .getAttributionSpansByFilter((a) => a == spellingErrorAttribution)
          .map((a) => TextRange(start: a.start, end: a.end + 1)) // +1 because text range end is exclusive
          .toList();
  }

  @override
  ParagraphComponent? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    return ParagraphComponentBuilder().createComponent(componentContext, componentViewModel);
  }
}
