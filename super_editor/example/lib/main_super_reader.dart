import 'package:example/demos/super_reader/demo_super_reader.dart';
import 'package:flutter/material.dart';

/// A demo of a [SuperReader] experience.
///
/// This demo only shows a single, typical [SuperReader]. To see a variety of
/// demos, see the main demo experience in this project.
void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SuperReaderDemo(),
      ),
    ),
  );
}
