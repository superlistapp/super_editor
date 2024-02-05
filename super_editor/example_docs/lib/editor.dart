import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:super_editor/super_editor.dart';

import 'theme.dart';

/// An editable document within a Docs app.
///
/// This is the primary editing experience for the app. A [DocsEditor] takes up
/// all the space beneath the app header pane.
class DocsEditor extends StatefulWidget {
  const DocsEditor({
    super.key,
    this.focusNode,
    required this.document,
    required this.composer,
    required this.editor,
  });

  final FocusNode? focusNode;
  final MutableDocument document;
  final MutableDocumentComposer composer;
  final Editor editor;

  @override
  State<DocsEditor> createState() => _DocsEditorState();
}

class _DocsEditorState extends State<DocsEditor> {
  late FocusNode _editorFocusNode;

  @override
  void initState() {
    super.initState();
    _editorFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant DocsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _editorFocusNode.dispose();
      }
      _editorFocusNode = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _editorFocusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _editorFocusNode,
      builder: (context, child) {
        return SuperEditor(
          focusNode: _editorFocusNode,
          editor: widget.editor,
          document: widget.document,
          composer: widget.composer,
          stylesheet: defaultStylesheet.copyWith(
            addRulesAfter: docsStylesheet,
            inlineTextStyler: _applyFontFamily,
          ),
          selectionStyle: _editorFocusNode.hasPrimaryFocus //
              ? _standardEditorSelectionStyle
              : _unfocusedEditorSelectionStyle,
          selectionPolicies: const SuperEditorSelectionPolicies(
            clearSelectionWhenEditorLosesFocus: false,
            clearSelectionWhenImeConnectionCloses: false,
          ),
          documentOverlayBuilders: const [
            DefaultCaretOverlayBuilder(
              displayCaretWithExpandedSelection: false,
            ),
          ],
          componentBuilders: [
            ...defaultComponentBuilders,
            TaskComponentBuilder(widget.editor),
          ],
        );
      },
    );
  }

  TextStyle _applyFontFamily(Set<Attribution> attributions, TextStyle existingStyle) {
    TextStyle styles = defaultInlineTextStyler(attributions, existingStyle);

    final fontFamilyAttribution = attributions.whereType<FontFamilyAttribution>().firstOrNull;
    if (fontFamilyAttribution != null) {
      styles = GoogleFonts.getFont(
        fontFamilyAttribution.fontFamily,
        textStyle: styles,
      );
    }

    return styles;
  }
}

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a font family change.
///
/// Every [FontFamilyAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [FontFamilyAttribution]s
/// from overlapping.
class FontFamilyAttribution implements Attribution {
  FontFamilyAttribution(this.fontFamily);

  @override
  String get id => fontFamily;

  final String fontFamily;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamilyAttribution && runtimeType == other.runtimeType && fontFamily == other.fontFamily;

  @override
  int get hashCode => fontFamily.hashCode;

  @override
  String toString() {
    return '[FontFamilyAttribution]: $fontFamily';
  }
}

// Selection styles when the editor has focus.
const _standardEditorSelectionStyle = defaultSelectionStyle;

// Selection styles when the editor doesn't have focus.
final _unfocusedEditorSelectionStyle = SelectionStyles(
  selectionColor: const Color(0xFFDDDDDD),
  highlightEmptyTextBlocks: defaultSelectionStyle.highlightEmptyTextBlocks,
);
