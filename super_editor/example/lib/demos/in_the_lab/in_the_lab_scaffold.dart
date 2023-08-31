import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// A scaffold to be used by all lab demos, to align the visual styles.
class InTheLabScaffold extends StatelessWidget {
  const InTheLabScaffold({
    super.key,
    this.supplemental,
    required this.child,
  });

  /// An (optional) supplemental control panel for the demo.
  final Widget? supplemental;

  /// Primary demo content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: const Color(0xFF222222),
            body: Row(
              children: [
                Expanded(
                  child: child,
                ),
                if (supplemental != null) //
                  _buildSupplementalPanel(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSupplementalPanel() {
    return Container(
      width: 250,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.biotech,
              color: Colors.white.withOpacity(0.05),
              size: 84,
            ),
          ),
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  child: supplemental!,
                ),
              ),
            ),
          ),
        ],
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
