import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

/// The background color of the window panes, such as the background of the
/// app header/ribbon.
const windowBackgroundColor = Color(0xFFf9fbfd);

/// The color of the icons that appear next to the document title.
const titleActionIconColor = Color(0xFF444746);

/// The horizontal padding of the primary app menu buttons, e.g., "File", "Edit".
const menuButtonHorizontalPadding = 8.0;

/// The background color of the app toolbar, i.e., the toolbar with options for font
/// family, font size, text alignment.
const toolbarBackgroundColor = Color(0xFFedf2fa);

/// The background color of a selected button on the toolbar, i.e., the color of a
/// bold button when the selection is bold.
const toolbarButtonSelectedColor = Color(0xFFd3e3fd);

/// The background color of a hovered button on the toolbar.
const toolbarButtonHoveredColor = Color(0xFFE1E6ED);

/// The background color of a pressed button on the toolbar.
const toolbarButtonPressedColor = Color(0xFFDAE0E6);

/// The color of the vertical divider of the toolbar.
const toolbarDividerColor = Color(0xFFC7C7C7);

/// Computes the background color for toolbar buttons.
Color? getButtonColor(Set<WidgetState> states) {
  if (states.contains(WidgetState.pressed)) {
    return toolbarButtonPressedColor;
  }

  if (states.contains(WidgetState.selected)) {
    return toolbarButtonSelectedColor;
  }

  if (states.contains(WidgetState.hovered)) {
    return toolbarButtonHoveredColor;
  }

  return Colors.transparent;
}

final defaultToolbarButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(getButtonColor),
  overlayColor: WidgetStateProperty.all(Colors.transparent),
  foregroundColor: WidgetStateProperty.all(Colors.black),
  fixedSize: WidgetStateProperty.all(const Size(30, 30)),
  minimumSize: WidgetStateProperty.all(const Size(30, 30)),
  maximumSize: WidgetStateProperty.all(const Size(30, 30)),
  iconSize: WidgetStateProperty.all(18),
  padding: WidgetStateProperty.all(EdgeInsets.zero),
  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4.0),
    ),
  ),
  shadowColor: WidgetStateProperty.all(Colors.transparent),
);

final docsStylesheet = [
  StyleRule(
    const BlockSelector("header1"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          height: 1.0,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header2"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          height: 1.0,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header3"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          height: 1.0,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header4"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          height: 1.0,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header5"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          height: 1.0,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header6"),
    (doc, docNode) {
      return {
        Styles.textStyle: const TextStyle(
          height: 1.0,
        ),
      };
    },
  ),
];

FollowerAlignment popoverAligner(Rect globalLeaderRect, Size followerSize, Size screenSize, GlobalKey? boundaryKey) {
  return const FollowerAlignment(
    leaderAnchor: Alignment.bottomLeft,
    followerAnchor: Alignment.topLeft,
    followerOffset: Offset(0, 1),
  );
}
