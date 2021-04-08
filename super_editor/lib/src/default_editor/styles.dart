import 'dart:ui';

/// The key in the `extensions` map that corresponds to the
/// text style builder within the `ComponentContext` that
/// is used to build each component in the document layout.
final String textStylesExtensionKey = 'editor.text_styles';

/// The key in the `extensions` map that corresponds to the
/// styles applied to selected content.
final String selectionStylesExtensionKey = 'editor.selection_styles';

class SelectionStyle {
  const SelectionStyle({
    required this.textCaretColor,
    required this.selectionColor,
  });

  final Color textCaretColor;
  final Color selectionColor;
}
