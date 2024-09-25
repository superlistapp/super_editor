import 'package:example/demos/mobile_chat/demo_mobile_chat.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

/// A demo of a chat experience that uses [SuperEditor].
void main() {
  initLoggers(Level.FINEST, {
    // editorScrollingLog,
    // editorGesturesLog,
    // longPressSelectionLog,
    // editorImeLog,
    // editorImeDeltasLog,
    // editorIosFloatingCursorLog,
    // editorKeyLog,
    // editorEditsLog,
    // editorOpsLog,
    // editorLayoutLog,
    // editorDocLog,
    // editorStyleLog,
    // textFieldLog,
    // editorUserTagsLog,
    // contentLayersLog,
  });

  runApp(
    MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: MobileChatDemo(),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}
