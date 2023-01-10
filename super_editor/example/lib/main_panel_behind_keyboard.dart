import 'package:example/demos/experiments/demo_panel_behind_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

/// Demo with a panel that appears behind the keyboard.
///
/// Initially, the panel isn't visible. Then the user opens the keyboard, and the
/// panel is hidden behind the keyboard. Then the user closes the keyboard, and
/// exposes the panel.
///
/// This demo sits in its own entrypoint because it needs to alter the standard
/// `Scaffold` behavior for insets, which is hard-coded for all demos in the
/// regular example entrypoint.
void main() {
  initLoggers(Level.FINEST, {
    editorGesturesLog,
    editorImeLog,
  });

  runApp(MaterialApp(
    home: PanelBehindKeyboardDemo(),
  ));
}
