import 'package:example/demos/example_editor/example_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';

/// A demo of a [SuperEditor] experience.
///
/// This demo only shows a single, typical [SuperEditor]. To see a variety of
/// demos, see the main demo experience in this project.
void main() {
  initLoggers(Level.FINEST, {
    // editorScrollingLog,
    // editorGesturesLog,
    // longPressSelectionLog,
    // editorImeLog,
    // editorImeDeltasLog,
    // editorIosFloatingCursorLog,
    // editorKeyLog,
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
        body: ExampleEditor(),
      ),
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    ),
  );
}
