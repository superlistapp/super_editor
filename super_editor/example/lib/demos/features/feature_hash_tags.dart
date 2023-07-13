import 'package:example/demos/features/feature_demo_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class HashTagsFeatureDemo extends StatefulWidget {
  const HashTagsFeatureDemo({super.key});

  @override
  State<HashTagsFeatureDemo> createState() => _HashTagsFeatureDemoState();
}

class _HashTagsFeatureDemoState extends State<HashTagsFeatureDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  late final HashTagPlugin _hashTagPlugin;

  final _tags = <String>[];

  @override
  void initState() {
    super.initState();

    _document = MutableDocument(nodes: [ParagraphNode(id: Editor.createNodeId(), text: AttributedText(text: ""))]);
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        ...defaultRequestHandlers,
      ],
      listeners: [
        FunctionalEditListener(_onEdit),
      ],
    );

    _hashTagPlugin = HashTagPlugin();
  }

  void _onEdit(List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      return;
    }

    _updateHashTagList();
  }

  void _updateHashTagList() {
    setState(() {
      _tags.clear();

      for (final node in _document.nodes) {
        if (node is! TextNode) {
          continue;
        }

        final tagSpans = node.text.getAttributionSpansInRange(
          attributionFilter: (a) => a is HashTagAttribution,
          range: SpanRange(start: 0, end: node.text.text.length - 1),
        );

        for (final tagSpan in tagSpans) {
          _tags.add(node.text.text.substring(tagSpan.start, tagSpan.end + 1));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FeatureDemoScaffold(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildEditor(),
          ),
          _buildTagList(),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return SuperEditor(
      editor: _editor,
      document: _document,
      composer: _composer,
      stylesheet: defaultStylesheet.copyWith(
        inlineTextStyler: (attributions, existingStyle) {
          TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

          if (attributions.whereType<HashTagAttribution>().isNotEmpty) {
            style = style.copyWith(
              color: Colors.orange,
            );
          }

          return style;
        },
        addRulesAfter: [
          ..._darkModeStyles,
        ],
      ),
      documentOverlayBuilders: [
        DefaultCaretOverlayBuilder(
          CaretStyle().copyWith(color: Colors.redAccent),
        ),
      ],
      plugins: {
        _hashTagPlugin,
      },
    );
  }

  Widget _buildTagList() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(width: 1, color: Colors.white.withOpacity(0.1)),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _tags.isNotEmpty
            ? SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final tag in _tags) //
                      Chip(label: Text(tag)),
                  ],
                ),
              )
            : Text(
                "NO TAGS",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.1),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

// Makes text light, for use during dark mode styling.
final _darkModeStyles = [
  StyleRule(
    BlockSelector.all,
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 32,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header1"),
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFF888888),
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header2"),
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFF888888),
        ),
      };
    },
  ),
];
