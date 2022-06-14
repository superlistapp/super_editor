import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

/// Extensions on [WidgetTester] for interacting with a [SuperTextField] the way
/// a user would.
extension SuperTextFieldRobot on WidgetTester {
  /// Taps to place a caret at the given [offset].
  ///
  /// {@template supertextfield_finder}
  /// By default, this method expects a single [SuperTextField] in the widget tree and
  /// finds it `byType`. To specify one [SuperTextField] among many, pass a [superTextFieldFinder].
  /// {@endtemplate}
  Future<void> placeCaretInSuperTextField(int offset, [Finder? superTextFieldFinder]) async {
    final fieldFinder = _findInnerPlatformTextField(superTextFieldFinder ?? find.byType(SuperTextField));
    final match = fieldFinder.evaluate().single.widget;

    if (match is SuperDesktopTextField) {
      final didTap = await _tapAtTextPositionOnDesktop(state<SuperDesktopTextFieldState>(fieldFinder), offset);
      if (!didTap) {
        throw Exception("The desired text offset wasn't tappable in SuperTextField: $offset");
      }
      return;
    }

    if (match is SuperAndroidTextField) {
      throw Exception("Entering text on an Android SuperTextField is not yet supported");
    }

    if (match is SuperIOSTextField) {
      throw Exception("Entering text on an iOS SuperTextField is not yet supported");
    }

    throw Exception("Couldn't find a SuperTextField with the given Finder: $superTextFieldFinder");
  }

  Future<bool> _tapAtTextPositionOnDesktop(SuperDesktopTextFieldState textField, int offset) async {
    final textPositionOffset = textField.textLayout.getOffsetForCaret(TextPosition(offset: offset));
    final textFieldBox = textField.context.findRenderObject() as RenderBox;

    // When upgrading Superlist to Flutter 3, some tests showed a caret offset
    // dy of -0.2. This didn't happen everywhere, but it did happen some places.
    // Until we get to the bottom of this issue, we'll add a constant offset to
    // make up for this.
    Offset adjustedOffset = textPositionOffset + const Offset(0, 0.2);

    // There's a problem on Windows and Linux where we get -0.0 instead of 0.0.
    // We adjust the offset to get rid of the -0.0, because a -0.0 fails the
    // Rect bounds check. (https://github.com/flutter/flutter/issues/100033)
    adjustedOffset = Offset(
      adjustedOffset.dx,
      // I tried checking "== -0.0" but it didn't catch the problem. This
      // approach looks for an arbitrarily small epsilon and then interprets
      // any such bounds as zero.
      adjustedOffset.dy.abs() < 1e-6 ? 0.0 : adjustedOffset.dy,
    );

    if (!textFieldBox.size.contains(adjustedOffset)) {
      return false;
    }

    final globalTapOffset = adjustedOffset + textFieldBox.localToGlobal(Offset.zero);
    await tapAt(globalTapOffset);
    return true;
  }

  Finder _findInnerPlatformTextField(Finder rootFieldFinder) {
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
}
