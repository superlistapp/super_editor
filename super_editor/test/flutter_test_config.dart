import 'dart:async';

import 'package:super_editor/src/super_textfield/ios/ios_textfield.dart';
import 'package:super_editor/src/test/test_globals.dart';
import 'package:super_text_layout/super_text_layout.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable indeterminate animations
  BlinkController.indeterminateAnimationsEnabled = false;

  // Disable iOS selection heuristics.
  IOSTextFieldTouchInteractor.useIosSelectionHeuristics = false;

  Testing.isInTest = true;

  return testMain();
}
