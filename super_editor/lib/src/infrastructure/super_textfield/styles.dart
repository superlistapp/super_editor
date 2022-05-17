import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';

import '../../default_editor/attributions.dart';

const defaultSelectionColor = Color(0xFFACCEF7);
const defaultDesktopCaretColor = Color(0xFF000000);

const defaultAndroidControlsColor = Color(0xFFA4C639);

const defaultIOSControlsColor = Color(0xFF2196F3);

/// Default [TextStyles] for [SuperTextField].
TextStyle defaultTextFieldStyleBuilder(Set<Attribution> attributions) {
  TextStyle newStyle = const TextStyle(
    fontSize: 16,
    height: 1,
  );

  for (final attribution in attributions) {
    if (attribution == boldAttribution) {
      newStyle = newStyle.copyWith(
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == italicsAttribution) {
      newStyle = newStyle.copyWith(
        fontStyle: FontStyle.italic,
      );
    } else if (attribution == underlineAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.underline
            : TextDecoration.combine([TextDecoration.underline, newStyle.decoration!]),
      );
    } else if (attribution == strikethroughAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.lineThrough
            : TextDecoration.combine([TextDecoration.lineThrough, newStyle.decoration!]),
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
