import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

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
