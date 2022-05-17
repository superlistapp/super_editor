import 'dart:async';

import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable indeterminate animations
  BlinkController.indeterminateAnimationsEnabled = false;

  await loadAppFonts();
  return testMain();
}
