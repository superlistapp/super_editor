import 'package:example/demos/features/feature_demo_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class UserTagsFeatureDemo extends StatefulWidget {
  const UserTagsFeatureDemo({super.key});

  @override
  State<UserTagsFeatureDemo> createState() => _UserTagsFeatureDemoState();
}

class _UserTagsFeatureDemoState extends State<UserTagsFeatureDemo> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  final _users = <String>[];

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
      reactionPipeline: [
        KeepCaretOutOfTagReaction(),
        TagUserReaction(),
      ],
      listeners: [
        FunctionalEditListener(_onEdit),
      ],
    );
  }

  void _onEdit(List<EditEvent> changeList) {
    if (changeList.whereType<DocumentEdit>().isEmpty) {
      return;
    }

    _updateUserTagList();
  }

  void _updateUserTagList() {
    setState(() {
      _users.clear();

      for (final node in _document.nodes) {
        if (node is! TextNode) {
          continue;
        }

        final userSpans = node.text.getAttributionSpansInRange(
          attributionFilter: (a) => a is UserTagAttribution,
          range: SpanRange(start: 0, end: node.text.text.length - 1),
        );

        for (final userSpan in userSpans) {
          _users.add(node.text.text.substring(userSpan.start, userSpan.end + 1));
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

          if (attributions.contains(userTagComposingAttribution)) {
            style = style.copyWith(
              color: Colors.blue,
            );
          }

          if (attributions.whereType<UserTagAttribution>().isNotEmpty) {
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
        child: _users.isNotEmpty
            ? SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final tag in _users) //
                      Chip(label: Text(tag)),
                  ],
                ),
              )
            : Text(
                "NO USERS",
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
