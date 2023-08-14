import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

TextStyle demoTextStyleBuilder(Set<Attribution> attributions) {
  TextStyle textStyle = const TextStyle(
    color: Colors.black,
    fontSize: 14,
  );

  if (attributions.contains(brandAttribution)) {
    textStyle = textStyle.copyWith(
      color: Colors.red,
      fontWeight: FontWeight.bold,
    );
  }
  if (attributions.contains(flutterAttribution)) {
    textStyle = textStyle.copyWith(
      color: Colors.blue,
    );
  }

  return textStyle;
}

const brandAttribution = NamedAttribution('brand');
const flutterAttribution = NamedAttribution('flutter');
