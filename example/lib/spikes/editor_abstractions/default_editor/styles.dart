import 'package:example/spikes/editor_abstractions/core/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

/// Wraps `defaultStyleBuilder` with adjustments on a per-block
/// basis, i.e., takes the standard style and increases the size
/// for a 'header1'.
AttributionStyleBuilder createBlockLevelStyleBuilder(String blockType) {
  return (Set<dynamic> attributions) {
    final baseStyle = defaultStyleBuilder(attributions);

    if (blockType == null) {
      return baseStyle;
    }

    switch (blockType) {
      case 'header1':
        return baseStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.0,
        );
      default:
        return baseStyle;
    }
  };
}

TextStyle defaultStyleBuilder(Set<dynamic> attributions) {
  TextStyle newStyle = TextStyle(
    color: Colors.black,
    height: 1.4,
  );

  for (final attribution in attributions) {
    if (attribution is! String) {
      continue;
    }

    switch (attribution) {
      case 'bold':
        newStyle = newStyle.copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      case 'italics':
        newStyle = newStyle.copyWith(
          fontStyle: FontStyle.italic,
        );
        break;
      case 'strikethrough':
        newStyle = newStyle.copyWith(
          decoration: TextDecoration.lineThrough,
        );
        break;
    }
  }
  return newStyle;
}
