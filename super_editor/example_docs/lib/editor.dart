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
            inlineTextStyler: _applyStyles,
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

  TextStyle _applyStyles(Set<Attribution> attributions, TextStyle existingStyle) {
    TextStyle styles = defaultInlineTextStyler(attributions, existingStyle);

    final backgroundColorAttribution = attributions.whereType<BackgroundColorAttribution>().firstOrNull;
    if (backgroundColorAttribution != null) {
      styles = styles.copyWith(backgroundColor: backgroundColorAttribution.color);
    }

    final fontSizeAttribution = attributions.whereType<FontSizeAttribution>().firstOrNull;
    if (fontSizeAttribution != null) {
      styles = styles.copyWith(fontSize: fontSizeAttribution.fontSize);
    }

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

// Selection styles when the editor has focus.
const _standardEditorSelectionStyle = defaultSelectionStyle;

// Selection styles when the editor doesn't have focus.
final _unfocusedEditorSelectionStyle = SelectionStyles(
  selectionColor: const Color(0xFFDDDDDD),
  highlightEmptyTextBlocks: defaultSelectionStyle.highlightEmptyTextBlocks,
);

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a backgrounnd color change.
///
/// Every [BackgroundColorAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [BackgroundColorAttribution]s
/// from overlapping.
class BackgroundColorAttribution implements Attribution {
  BackgroundColorAttribution(this.color);

  @override
  String get id => "${color.value}";

  final Color color;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundColorAttribution && runtimeType == other.runtimeType && color == other.color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() {
    return '[BackgroundColorAttribution]: $color';
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

/// Attribution to be used within [AttributedText] to
/// represent an inline span of a font size change.
///
/// Every [FontSizeAttribution] is considered equivalent so
/// that [AttributedText] prevents multiple [FontSizeAttribution]s
/// from overlapping.
class FontSizeAttribution implements Attribution {
  FontSizeAttribution(this.fontSize);

  @override
  String get id => fontSize.toString();

  final double fontSize;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontSizeAttribution && runtimeType == other.runtimeType && fontSize == other.fontSize;

  @override
  int get hashCode => fontSize.hashCode;

  @override
  String toString() {
    return '[FontSizeAttribution]: $fontSize';
  }
}
