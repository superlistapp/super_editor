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
      routes: {
        "/": (context) => Scaffold(
              resizeToAvoidBottomInset: false,
              body: MobileChatDemo(),
            ),
        // We include a 2nd screen with navigation so that we can verify
        // what happens to the keyboard safe area when navigating from an
        // open editor to another screen with a safe area, but no keyboard
        // scaffold. See issue #2419
        "/second": (context) => Scaffold(
              appBar: AppBar(),
              resizeToAvoidBottomInset: false,
              body: KeyboardScaffoldSafeArea(
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text("Item $index"),
                    );
                  },
                ),
              ),
            ),
      },
      debugShowCheckedModeBanner: false,
    ),
  );
}
