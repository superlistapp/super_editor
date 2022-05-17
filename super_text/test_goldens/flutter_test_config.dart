import 'dart:async';

import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text/super_text.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable indeterminate animations
  // ignore: invalid_use_of_visible_for_testing_member
  BlinkController.indeterminateAnimationsEnabled = false;

  await loadAppFonts();
  return testMain();
}
