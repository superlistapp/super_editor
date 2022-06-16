import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Inspects that state of a [SuperTextField] in a test.
class SuperTextFieldInspector {
  /// Finds and returns the [ProseTextLayout] within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static ProseTextLayout findProseTextLayout([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final element = finder.evaluate().single as StatefulElement;
    return (element.state as SuperTextFieldState).textLayout;
  }

  /// Finds and returns the [AttributedText] within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static AttributedText findText([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final element = finder.evaluate().single as StatefulElement;
    final state = element.state as SuperTextFieldState;
    return state.controller.text;
  }

  /// Finds and returns the [TextSelection] within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static TextSelection? findSelection([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final element = finder.evaluate().single as StatefulElement;
    final state = element.state as SuperTextFieldState;
    return state.controller.selection;
  }

  SuperTextFieldInspector._();
}
