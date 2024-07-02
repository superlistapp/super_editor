import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A [ComponentBuilder] that builds a blockquote component for the Feather app.
///
/// The Feather blockquote is styled differently from the standard Super Editor
/// blockquote, and therefore requires its own component and builder.
class FeatherBlockquoteComponentBuilder extends BlockquoteComponentBuilder {
  const FeatherBlockquoteComponentBuilder();

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! BlockquoteComponentViewModel) {
      return null;
    }

    return FeatherBlockquoteComponent(
      textKey: componentContext.componentKey,
      text: componentViewModel.text,
      textAlign: componentViewModel.textAlignment,
      styleBuilder: componentViewModel.textStyleBuilder,
      backgroundColor: componentViewModel.backgroundColor,
      borderRadius: componentViewModel.borderRadius,
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
      composingRegion: componentViewModel.composingRegion,
      showComposingUnderline: componentViewModel.showComposingUnderline,
    );
  }
}

/// A Super Editor component that displays a blockquote with a vertical line
/// on left edge of the block.
class FeatherBlockquoteComponent extends StatelessWidget {
  const FeatherBlockquoteComponent({
    super.key,
    required this.textKey,
    required this.text,
    this.textAlign = TextAlign.left,
    required this.styleBuilder,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    required this.backgroundColor,
    required this.borderRadius,
    this.highlightWhenEmpty = false,
    this.composingRegion,
    this.showComposingUnderline = false,
    this.showDebugPaint = false,
  });

  final GlobalKey textKey;
  final AttributedText text;
  final TextAlign textAlign;
  final AttributionStyleBuilder styleBuilder;
  final TextSelection? textSelection;
  final Color selectionColor;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final bool highlightWhenEmpty;
  final TextRange? composingRegion;
  final bool showComposingUnderline;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFCCCCCC), width: 4),
          ),
        ),
        child: TextComponent(
          key: textKey,
          text: text,
          textAlign: textAlign,
          textStyleBuilder: styleBuilder,
          textSelection: textSelection,
          selectionColor: selectionColor,
          highlightWhenEmpty: highlightWhenEmpty,
          composingRegion: composingRegion,
          showComposingUnderline: showComposingUnderline,
          showDebugPaint: showDebugPaint,
        ),
      ),
    );
  }
}
