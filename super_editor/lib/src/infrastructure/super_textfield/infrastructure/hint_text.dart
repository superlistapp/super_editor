import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/attributed_text_styles.dart';

/// Policy that dictates when to display a hint in a Super Text Field.
enum HintBehavior {
  /// Display a hint when the text field is empty until
  /// the text field receives focus, then hide the hint.
  displayHintUntilFocus,

  /// Display a hint when the text field is empty until
  /// at least 1 character is entered into the text field.
  displayHintUntilTextEntered,

  /// Do not display a hint.
  noHint,
}

/// Builds a hint widget based on given [hintText] and a [hintTextStyleBuilder].
class StyledHintBuilder {
  StyledHintBuilder({
    this.hintText,
    this.hintTextStyleBuilder = defaultHintStyleBuilder,
  });

  /// Text displayed when the text field has no content.
  final AttributedText? hintText;

  /// Text style factory that creates styles for the [hintText],
  /// which is displayed when [textController] is empty.
  final AttributionStyleBuilder hintTextStyleBuilder;

  Widget build(BuildContext context) {
    return Text.rich(
      hintText?.computeTextSpan(hintTextStyleBuilder) ?? TextSpan(text: "", style: hintTextStyleBuilder({})),
    );
  }
}

/// Creates default [TextStyles] for hint text in a super text field.
TextStyle defaultHintStyleBuilder(Set<Attribution> attributions) {
  TextStyle newStyle = const TextStyle(
    color: Colors.grey,
    fontSize: 16,
    height: 1.4,
  );

  for (final attribution in attributions) {
    if (attribution == header1Attribution) {
      newStyle = newStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.0,
      );
    } else if (attribution == header2Attribution) {
      newStyle = newStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF888888),
        height: 1.0,
      );
    } else if (attribution == blockquoteAttribution) {
      newStyle = newStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: Colors.grey,
      );
    } else if (attribution == boldAttribution) {
      newStyle = newStyle.copyWith(
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == italicsAttribution) {
      newStyle = newStyle.copyWith(
        fontStyle: FontStyle.italic,
      );
    } else if (attribution == strikethroughAttribution) {
      newStyle = newStyle.copyWith(
        decoration: TextDecoration.lineThrough,
      );
    } else if (attribution is LinkAttribution) {
      newStyle = newStyle.copyWith(
        color: Colors.lightBlue,
        decoration: TextDecoration.underline,
      );
    }
  }
  return newStyle;
}
