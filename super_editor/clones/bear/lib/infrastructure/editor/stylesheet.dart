import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_editor/super_editor.dart';

final dashStylesheet = Stylesheet(
  rules: [
    ...defaultStylesheet.rules,
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.textStyle: const TextStyle(
            color: Color(0xFF444444),
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header1"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 40),
          Styles.textStyle: const TextStyle(
            fontSize: 24,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header2"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 16),
          Styles.textStyle: const TextStyle(
            fontSize: 18,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("listItem"),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 10),
          Styles.textStyle: const TextStyle(
            fontSize: 14,
          ),
        };
      },
    ),
  ],
  inlineTextStyler: defaultStylesheet.inlineTextStyler,
);
