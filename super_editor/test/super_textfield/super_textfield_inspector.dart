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

  /// Finds and returns the [Rect] of a [SuperTextField].
  ///
  /// {@macro supertextfield_finder}
  static Rect findSuperTextFieldRect(
    WidgetTester tester, {
    Finder? superTextFieldFinder,
  }) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    return tester.getRect(finder);
  }

  /// Finds and returns the [Rect] of the child of [SuperTextField]'s [Padding].
  ///
  /// {@macro supertextfield_finder}
  static Rect findPaddingRect(
    WidgetTester tester, {
    Finder? superTextFieldFinder,
  }) {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);
    final padding = find.descendant(of: finder, matching: find.byType(Padding));
    return tester.getRect(padding);
  }

  /// Finds and returns an Iterable of [Rect]s for each inset of
  /// [SuperTextField]'s [Padding].
  ///
  /// {@macro supertextfield_finder}
  static Iterable<Rect> findPaddingInsetsRects(
    WidgetTester tester, {
    Finder? superTextFieldFinder,
    TextDirection? textDirection,
  }) sync* {
    final finder = superTextFieldFinder ?? find.byType(SuperTextField);

    late final Padding padding;

    try {
      final maybePadding = find.descendant(
        of: finder,
        matching: find.byType(Padding),
      );
      padding = maybePadding.evaluate().single.widget as Padding;
    } catch (_) {
      throw Exception('Padding not found');
    }

    final edgeInsets = padding.padding.resolve(textDirection);

    final insetsRelativeRects = [
      RelativeRect.fromLTRB(edgeInsets.left, 0, 0, 0),
      RelativeRect.fromLTRB(0, edgeInsets.top, 0, 0),
      RelativeRect.fromLTRB(0, 0, edgeInsets.right, 0),
      RelativeRect.fromLTRB(0, 0, 0, edgeInsets.bottom),
    ];

    final superTextFieldRect = tester.getRect(finder);

    for (final insetRelativeRect in insetsRelativeRects) {
      if (insetRelativeRect.hasInsets) {
        yield insetRelativeRect.toRect(superTextFieldRect);
      }
    }
  }

  SuperTextFieldInspector._();
}
