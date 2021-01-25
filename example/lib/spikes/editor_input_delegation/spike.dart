import 'package:flutter/material.dart';

import 'editor.dart';

/// Spike:
/// How should we delegate input so that keys like arrows, backspace,
/// delete, page-up, page-down, and others can select and interact
/// with multiple document widgets?
///
/// Conclusion:
/// TODO:
///
/// Thoughts:
///  - We can't allow individual document widgets to respond to user
///    input because individual widgets won't have the document-level
///    awareness to understand and process actions that impact multiple
///    document nodes. For example: the user selects a paragraph, a list item,
///    and an image and then presses "delete". It can't be the job of
///    any of those individual widgets to handle the "delete" key press.
///
///  - We should try to completely separate painting concerns from input
///    concerns. The framework has not done a great job of this when it
///    comes to EditableText, which prevented us from using existing widgets.
///    We should see if we can create more highly composable text selection
///    and editing tools to achieve grater versatility.
///
/// Known Issues:
///  - empty line selection isn't quite right. When selecting empty lines,
///    there should be a concept of an invisible newline. The invisible
///    newlines should receive a small selection. Of course, the newlines
///    aren't real, so this an explicit effect that's added. When selecting
///    multiple empty lines, the last line should not show a selection because
///    the hypothetical newline happens after the selection. However, the
///    current implementation shows a selection on every empty line that
///    participates in the selection.
///
///  - when drag-selecting text within a single line, the y-position is
///    used to determine direction. Instead, the x-position should be
///    used when selecting within a single line.
///
///  - there is some weird measurement glitch with the SingleChildScrollView
///    and IntrinsicHeight where we overflow the bottom sometimes.

void main() {
  runApp(
    MaterialApp(
      home: EditorSpike(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class EditorSpike extends StatefulWidget {
  @override
  _EditorSpikeState createState() => _EditorSpikeState();
}

class _EditorSpikeState extends State<EditorSpike> {
  bool _showDebugPaint = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Editor(
        showDebugPaint: _showDebugPaint,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        Switch(
          value: _showDebugPaint,
          onChanged: (newValue) {
            setState(() {
              _showDebugPaint = newValue;
            });
          },
        ),
      ],
    );
  }
}
