import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

const backgroundColor = Color(0xFF191E22);
const dividerColor = Color(0xFF292D32);
const borderColor = Color(0xFF36383E);

final messageListStyles = [
  StyleRule(
    BlockSelector.all,
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 14,
        ),
        Styles.padding: const CascadingPadding.symmetric(
          horizontal: 0,
          vertical: 0,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header1"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 16,
        ),
        Styles.padding: const CascadingPadding.symmetric(
          horizontal: 0,
          vertical: 0,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header2"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          color: Color(0xFF888888),
        ),
      };
    },
  ),
];

final messageEditorStylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    ...messageListStyles,
    StyleRule(
      BlockSelector.all.last(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 22),
        };
      },
    ),
  ],
  documentPadding: const EdgeInsets.symmetric(horizontal: 10),
  inlineTextStyler: (attributions, existingStyle) {
    TextStyle style = defaultInlineTextStyler(attributions, existingStyle);

    if (attributions.contains(stableTagComposingAttribution)) {
      // Style an user tag being composed.
      style = style.copyWith(color: Colors.blue);
    }

    if (attributions.whereType<CommittedStableTagAttribution>().isNotEmpty) {
      // Style an already composed user tag.
      style = style.copyWith(color: Colors.orange);
    }

    return style;
  },
);

Color makeSelectedTextBlack({required Color originalTextColor, required Color selectionHighlightColor}) {
  return Colors.black;
}
