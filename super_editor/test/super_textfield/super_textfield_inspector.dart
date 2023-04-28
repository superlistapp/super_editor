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

  /// Finds and returns the scroll offset within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static double? findScrollOffset([Finder? superTextFieldFinder]) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);

    final fieldFinder = findInnerPlatformTextField(finder);
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperDesktopTextField) {
      final textScrollViewElement = find
          .descendant(
            of: finder,
            matching: find.byType(SuperTextFieldScrollview),
          )
          .evaluate()
          .single as StatefulElement;
      final textScrollView = textScrollViewElement.widget as SuperTextFieldScrollview;

      return textScrollView.scrollController.offset;
    }

    // Both mobile textfields use TextScrollView.
    final textScrollViewElement = find
        .descendant(
          of: finder,
          matching: find.byType(TextScrollView),
        )
        .evaluate()
        .single as StatefulElement;
    final textScrollView = textScrollViewElement.widget as TextScrollView;

    return textScrollView.textScrollController.scrollOffset;
  }

  /// Finds and returns the platform textfield within a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static Finder findInnerPlatformTextField([Finder? superTextFieldFinder]) {
    final rootFieldFinder = superTextFieldFinder ?? find.byType(SuperTextField);

    final rootMatches = rootFieldFinder.evaluate();
    if (rootMatches.isEmpty) {
      throw Exception("Couldn't find a super text field variant with the given finder: $rootFieldFinder");
    }
    if (rootMatches.length > 1) {
      throw Exception("Found more than 1 super text field match with finder: $rootFieldFinder");
    }

    final rootMatch = rootMatches.single.widget;
    if (rootMatch is! SuperTextField) {
      // The match isn't a generic SuperTextField. Assume that it's a platform
      // specific super text field, which is what we're looking for. Return it.
      return rootFieldFinder;
    }

    final desktopFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperDesktopTextField)).evaluate();
    if (desktopFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperDesktopTextField));
    }

    final androidFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperAndroidTextField)).evaluate();
    if (androidFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperAndroidTextField));
    }

    final iosFieldCandidates =
        find.descendant(of: rootFieldFinder, matching: find.byType(SuperIOSTextField)).evaluate();
    if (iosFieldCandidates.isNotEmpty) {
      return find.descendant(of: rootFieldFinder, matching: find.byType(SuperIOSTextField));
    }

    throw Exception(
        "Couldn't find the platform-specific super text field within the root SuperTextField. Root finder: $rootFieldFinder");
  }

  SuperTextFieldInspector._();
}
