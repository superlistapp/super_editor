import 'package:flutter/material.dart';

import 'editor.dart';

/// Spike:
/// How should we delegate input so that keys like arrows, backspace,
/// delete, page-up, page-down, and others can select and interact
/// with multiple document widgets?
///
/// Rationale:
///  - We can't allow individual document widgets to respond to user
///    input because individual widgets won't have the document-level
///    awareness to understand and process actions that impact multiple
///    document nodes. For example: the user selects a paragraph, a list item,
///    and an image and then presses "delete". It can't be the job of
///    any of those individual widgets to handle the "delete" key press.

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Editor(),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}
