import 'dart:async';

import 'package:super_editor/src/test/test_globals.dart';
import 'package:super_text_layout/super_text_layout.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable indeterminate animations
  BlinkController.indeterminateAnimationsEnabled = false;

  Testing.isInTest = true;

  return testMain();
}
