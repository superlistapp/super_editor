import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A scaffold to be used by all feature demos, to align the visual styles of
/// all feature demos.
class FeatureDemoScaffold extends StatelessWidget {
  const FeatureDemoScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: const Color(0xFF222222),
            body: child,
          );
        },
      ),
    );
  }
}

// Makes text light, for use during dark mode styling.
final darkModeStyles = [
  StyleRule(
    BlockSelector.all,
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 32,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header1"),
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFF888888),
          fontSize: 48,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header2"),
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFF888888),
          fontSize: 42,
        ),
      };
    },
  ),
  StyleRule(
    const BlockSelector("header3"),
    (doc, docNode) {
      return {
        "textStyle": const TextStyle(
          color: Color(0xFF888888),
          fontSize: 36,
        ),
      };
    },
  ),
];
