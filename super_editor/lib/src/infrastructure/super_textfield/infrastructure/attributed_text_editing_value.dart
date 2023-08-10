import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/services.dart';

/// The logical value of a text editable that displays attributed
/// text.
class AttributedTextEditingValue {
  factory AttributedTextEditingValue.empty() => AttributedTextEditingValue(
        text: AttributedText(text: ""),
      );

  factory AttributedTextEditingValue.emptyWithCaret() => AttributedTextEditingValue(
        text: AttributedText(text: ""),
        selection: const TextSelection.collapsed(offset: 0),
      );

  const AttributedTextEditingValue({
    required this.text,
    this.selection = const TextSelection.collapsed(offset: -1),
    this.composingRegion = TextRange.empty,
  });

  /// The text displayed in the editable.
  final AttributedText text;

  /// The text selection in the editable.
  ///
  /// A [selection] of `TextSelection.collapsed(offset: -1)` represents
  /// the absence of a selection.
  final TextSelection selection;

  /// The region of [text] that's currently being composed.
  ///
  /// Composing regions are used by operating system input method
  /// engines (IMEs) to create compound characters, check spelling,
  /// and apply other effects on the platform side.
  final TextRange composingRegion;
}
