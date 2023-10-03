import 'package:example/demos/example_editor/example_editor.dart';
import 'package:flutter/material.dart';

/// A demo of a [SuperEditor] experience.
///
/// This demo only shows a single, typical [SuperEditor]. To see a variety of
/// demos, see the main demo experience in this project.
void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: ExampleEditor(),
      ),
    ),
  );
}
