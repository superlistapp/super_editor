import 'package:example/demos/in_the_lab/in_the_lab_scaffold.dart';
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

  late final PatternTagPlugin _hashTagPlugin;

  final _tags = <IndexedTag>[];

  @override
  void initState() {
    super.initState();

    _document = MutableDocument.empty();
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

    _hashTagPlugin = PatternTagPlugin() //
      ..tagIndex.addListener(_updateHashTagList);
  }

  @override
  void dispose() {
    _hashTagPlugin.tagIndex.removeListener(_updateHashTagList);
    super.dispose();
  }

  void _updateHashTagList() {
    setState(() {
      _tags
        ..clear()
        ..addAll(_hashTagPlugin.tagIndex.getAllTags());
    });
  }

  @override
  Widget build(BuildContext context) {
    return InTheLabScaffold(
      content: _buildEditor(),
      supplemental: _buildTagList(),
    );
  }

  Widget _buildEditor() {
    return IntrinsicHeight(
      child: SuperEditor(
        editor: _editor,
        stylesheet: defaultStylesheet.copyWith(
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
        plugins: {
          _hashTagPlugin,
        },
      ),
    );
  }

  Widget _buildTagList() {
    if (_tags.isEmpty) {
      return const SizedBox();
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final tag in _tags) //
            Chip(label: Text(tag.tag.raw)),
        ],
      ),
    );
  }
}
