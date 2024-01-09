import 'package:flutter/painting.dart';
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
