import 'dart:async';

import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text_layout/super_text_layout.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable indeterminate animations
  BlinkController.indeterminateAnimationsEnabled = false;

  // We load fonts, even for non-golden tests, so that text layout and
  // line-wrapping is more predictable.
  await loadAppFonts();
  return testMain();
}
