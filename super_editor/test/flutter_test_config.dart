import 'dart:async';

import 'package:super_editor/super_editor.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable indeterminate animations
  BlinkController.indeterminateAnimationsEnabled = false;

  return testMain();
}
