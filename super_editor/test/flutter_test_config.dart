import 'dart:async';

import 'package:super_text_layout/super_text_layout.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable indeterminate animations
  BlinkController.indeterminateAnimationsEnabled = false;

  return testMain();
}
