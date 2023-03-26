// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/widgets.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/src/super_text.dart';

/// Inspects a given [SuperText] in the widget tree.
class SuperTextInspector {
  /// Finds and returns the `textScaleFactor` that's applied to the [SuperText].
  ///
  /// {@template supertext_finder}
  /// By default, this method expects a single [SuperText] in the widget tree and
  /// finds it `byType`. To specify one [SuperText] among many, pass a [finder].
  /// {@endtemplate}
  static double findTextScaleFactor([Finder? finder]) {
    final element = (finder ?? find.byType(SuperText)).evaluate().single as StatefulElement;
    final superText = element.widget as SuperText;

    final renderLayoutAwareRichText = find
        .descendant(
          of: find.byWidget(superText),
          matching: find.byType(LayoutAwareRichText),
        )
        .evaluate()
        .first
        .widget as LayoutAwareRichText;

    return renderLayoutAwareRichText.textScaleFactor;
  }
}
