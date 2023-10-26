import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../test_runners.dart';
import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

void main() {
  group('SuperTextField', () {
    testWidgetsOnAllPlatforms('single-line jumps scroll position horizontally as the user types', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("ABCDEFG"),
      );

      // Pump the widget tree with a SuperTextField with a maxWidth smaller
      // than the text width
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 1,
        maxWidth: 50,
      );

      // Move selection to the end of the text
      // TODO: change to simulate user input when IME simulation is available
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pumpAndSettle();

      // Position at the end of the viewport
      final viewportRight = tester.getBottomRight(find.byType(SuperTextField)).dx;

      // Position at the end of the text
      final textRight = tester.getBottomRight(find.byType(SuperText)).dx;

      // Ensure the text field scrolled its content horizontally
      expect(textRight, lessThanOrEqualTo(viewportRight));
    });

    testWidgetsOnAllPlatforms('multi-line jumps scroll position vertically as the user types', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("A\nB\nC\nD"),
      );

      // Pump the widget tree with a SuperTextField with a maxHeight smaller
      // than the text heght
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 2,
        maxHeight: 20,
      );

      // Move selection to the end of the text
      // TODO: change to simulate user input when IME simulation is available
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pumpAndSettle();

      // Position at the end of the viewport
      final viewportBottom = tester.getBottomRight(find.byType(SuperTextField)).dy;

      // Position at the end of the text
      final textBottom = tester.getBottomRight(find.byType(SuperText)).dy;

      // Ensure the text field scrolled its content vertically
      expect(textBottom, lessThanOrEqualTo(viewportBottom));
    });

    testWidgetsOnAllPlatforms(
        "multi-line jumps scroll position vertically when selection extent moves above or below the visible viewport area",
        (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("First line\nSecond Line\nThird Line\nFourth Line"),
      );

      // Pump the widget tree with a SuperTextField which is two lines tall.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 2,
        maxHeight: 40,
      );

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      // Ensure the text field has scrolled.
      expect(
        SuperTextFieldInspector.findScrollOffset(),
        greaterThan(0.0),
      );

      // Place the caret at the beginning of the text.
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();

      // Ensure the text field scrolled to the top.
      expect(
        SuperTextFieldInspector.findScrollOffset(),
        0.0,
      );
    });

    testWidgetsOnAllPlatforms("multi-line doesn't jump scroll position vertically when selection extent is visible",
        (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText("First line\nSecond Line\nThird Line\nFourth Line"),
      );

      // Pump the widget tree with a SuperTextField which is two lines tall.
      await _pumpTestApp(
        tester,
        textController: controller,
        minLines: 1,
        maxLines: 2,
        maxHeight: 40,
      );

      // Move selection to the end of the text.
      // This will scroll the text field to the end.
      controller.selection = const TextSelection.collapsed(offset: 45);
      await tester.pumpAndSettle();

      final scrollOffsetBefore = SuperTextFieldInspector.findScrollOffset();

      // Place the caret at "Third| Line".
      // As we have room for two lines, this line is already visible,
      // and thus shouldn't cause the text field to scroll.
      controller.selection = const TextSelection.collapsed(offset: 28);
      await tester.pumpAndSettle();

      // Ensure the content didn't scrolled.
      expect(
        SuperTextFieldInspector.findScrollOffset(),
        scrollOffsetBefore,
      );
    });

    testWidgetsOnDesktop("doesn't scroll vertically when maxLines is null", (tester) async {
      // With the Ahem font the estimated line height is equal to the true line height
      // so we need to use a custom font.
      await loadAppFonts();

      // We use some padding because it affects the viewport height calculation.
      const verticalPadding = 6.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 300),
              child: SuperDesktopTextField(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
                minLines: 1,
                maxLines: null,
                textController: AttributedTextEditingController(
                  text: AttributedText("SuperTextField"),
                ),
                textStyleBuilder: (_) => const TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // In the running app, the estimated line height and actual line height differ.
      // This test ensures that we account for that. Ideally, this test would check that the scrollview doesn't scroll.
      // However, in test suites, the estimated and actual line heights are always identical.
      // Therefore, this test ensures that we add up the appropriate dimensions,
      // rather than verify the scrollview's max scroll extent.

      final viewportHeight = tester.getRect(find.byType(SuperTextFieldScrollview)).height;

      final layoutState =
          (find.byType(SuperDesktopTextField).evaluate().single as StatefulElement).state as SuperDesktopTextFieldState;
      final contentHeight = layoutState.textLayout.getLineHeightAtPosition(const TextPosition(offset: 0));

      // Vertical padding is added to both top and bottom
      final totalHeight = contentHeight + (verticalPadding * 2);

      // Ensure the viewport is big enough so the text doesn't scroll vertically
      expect(viewportHeight, greaterThanOrEqualTo(totalHeight));
    });

    group("textfield scrolling", () {
      testWidgetsOnDesktopAndWeb(
        'PAGE DOWN scrolls down by the viewport height',
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find textfield scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we scrolled down by the viewport height.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.viewportDimension),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnDesktopAndWeb(
        'PAGE DOWN does not scroll past bottom of the viewport',
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we didn't scroll past the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnDesktopAndWeb(
        'PAGE UP scrolls up by the viewport height',
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we scrolled up by the viewport height.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.maxScrollExtent - scrollState.position.viewportDimension),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnDesktopAndWeb(
        'PAGE UP does not scroll past top of the viewport',
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure we didn't scroll past the top of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnDesktopAndWeb(
        'CMD + HOME on mac, HOME on mac/web and CTRL + HOME on other platforms scrolls to top of viewport',
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;
          final useHomeOnMacOrWeb = currentVariant!.useHomeEndToScrollOnMacOrWeb;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);

          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to the top of the viewport.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.minScrollExtent),
          );
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnDesktopAndWeb(
        "CMD + HOME on mac, HOME on mac/web and CTRL + HOME on other platforms does not scroll past top of the viewport",
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;
          final useHomeOnMacOrWeb = currentVariant!.useHomeEndToScrollOnMacOrWeb;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);

          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we didn't scroll past the top of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnDesktopAndWeb(
        "CMD + END on mac, END on mac/web and CTRL + END on other platforms scrolls to bottom of viewport",
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;
          final useHomeOnMacOrWeb = currentVariant!.useHomeEndToScrollOnMacOrWeb;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          await _pressScrollToEndCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );

      testWidgetsOnDesktopAndWeb(
        "CMD + END on mac, END on mac/web and CTRL + END on other platforms does not scroll past bottom of the viewport",
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;
          final useHomeOnMacOrWeb = currentVariant!.useHomeEndToScrollOnMacOrWeb;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);

          await _pressScrollToEndCombo(useHomeOnMacOrWeb, tester);

          // Ensure we didn't scroll past the bottom of the viewport.
          expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
        },
        variant: _scrollingVariant,
      );
    });

    group("textfield scrolling within ancestor scrollable", () {
      testWidgetsOnDesktopAndWeb(
        '''scrolls from top->bottom of textfiled and then towards bottom of 
        the page and back to the top of the page''',
        (tester) async {
          final currentVariant = _scrollTextFieldPlacedAtTopVariant.currentValue;
          final useHomeOnMacOrWeb = currentVariant!.useHomeEndToScrollOnMacOrWeb;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            currentVariant.textInputSource,
            currentVariant.placement,
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperTextField),
            matching: find.byType(Scrollable),
          ));

          // Find the textfield's  ancestor scrollable
          final ancestorScrollState = tester.state<ScrollableState>(
            find.descendant(
              of: find.byKey(textfieldsAncestorScrollableKey),
              matching: find.byType(Scrollable).first,
            ),
          );

          // Scrolls to textfield's bottom.
          await _pressScrollToEndCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to textfield's bottom.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.maxScrollExtent),
          );

          // Scrolls to ancestor scrollable's bottom.
          await _pressScrollToEndCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to ancestor scrollable's bottom.
          expect(
            ancestorScrollState.position.pixels,
            equals(ancestorScrollState.position.maxScrollExtent),
          );

          // Scrolls to textfield's top.
          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to textfield's top.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.minScrollExtent),
          );

          // Scrolls to ancestor scrollable's top.
          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to ancestor scrollable's top.
          expect(
            ancestorScrollState.position.pixels,
            equals(ancestorScrollState.position.minScrollExtent),
          );
        },
        variant: _scrollTextFieldPlacedAtTopVariant,
      );

      testWidgetsOnDesktopAndWeb(
        '''when placed at bottom of page, scrolls all the way from top of the textfield to 
        bottom of the page and back to the top of the page''',
        (tester) async {
          final currentVariant = _scrollTextfieldPlacedAtBottomVariant.currentValue;
          final useHomeOnMacOrWeb = currentVariant!.useHomeEndToScrollOnMacOrWeb;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            currentVariant.textInputSource,
            currentVariant.placement,
          );

          // Find the textfield's ancestor scrollable
          final ancestorScrollState = tester.state<ScrollableState>(
            find.descendant(
              of: find.byKey(textfieldsAncestorScrollableKey),
              matching: find.byType(Scrollable).first,
            ),
          );

          ancestorScrollState.position.jumpTo(ancestorScrollState.position.maxScrollExtent);
          await tester.pump();

          // Ensure we are at the bottom of the page.
          expect(
            ancestorScrollState.position.pixels,
            equals(ancestorScrollState.position.maxScrollExtent),
          );

          // Find SuperTextField scrollable
          final scrollState = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ),
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Scroll all the way to the bottom of the textfield.
          await _pressScrollToEndCombo(useHomeOnMacOrWeb, tester);

          expect(
            scrollState.position.pixels,
            equals(scrollState.position.maxScrollExtent),
          );

          // Scrolls to textfield's top.
          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to textfield's top.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.minScrollExtent),
          );

          // Scrolls to ancestor scrollable's top.
          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to ancestor scrollable's top.
          expect(
            ancestorScrollState.position.pixels,
            equals(ancestorScrollState.position.minScrollExtent),
          );
        },
        variant: _scrollTextfieldPlacedAtBottomVariant,
      );

      testWidgetsOnDesktopAndWeb(
        '''when placed at the center of page, scrolls all the way from top to bottom of 
        textfield and page, and then back to the top of the page''',
        (tester) async {
          final currentVariant = _scrollTextFieldPlacedAtCenter.currentValue;
          final useHomeOnMacOrWeb = currentVariant!.useHomeEndToScrollOnMacOrWeb;

          // Pump the widget tree with a SuperTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            currentVariant.textInputSource,
            currentVariant.placement,
          );

          // Find the textfield's ancestor scrollable.
          final ancestorScrollState = tester.state<ScrollableState>(
            find.descendant(
              of: find.byKey(textfieldsAncestorScrollableKey),
              matching: find.byType(Scrollable).first,
            ),
          );

          // Tap on the page to focus it.
          await tester.tap(find.byKey(textfieldsAncestorScrollableKey));
          await tester.pump();

          // Scroll untill textfield is visible.
          await tester.scrollUntilVisible(
            find.byType(SuperTextField),
            200,
          );
          await tester.pump();

          // Find SuperTextField scrollable.
          final scrollState = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(SuperTextField),
              matching: find.byType(Scrollable),
            ),
          );

          // Tap on the textfield to focus it.
          await tester.placeCaretInSuperTextField(0);

          // Ensure we are at the top of the textfiled.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.minScrollExtent),
          );

          // Scrolls to textfield's bottom.
          await _pressScrollToEndCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to textfield's bottom.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.maxScrollExtent),
          );

          // Scrolls to ancestor scrollable's bottom.
          await _pressScrollToEndCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to ancestor scrollable's bottom.
          expect(
            ancestorScrollState.position.pixels,
            equals(ancestorScrollState.position.maxScrollExtent),
          );

          // Scrolls to textfield's top.
          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to textfield's top.
          expect(
            scrollState.position.pixels,
            equals(scrollState.position.minScrollExtent),
          );

          // Scrolls to ancestor scrollable's top.
          await _pressScrollToTopCombo(useHomeOnMacOrWeb, tester);

          // Ensure we scrolled to ancestor scrollable's top.
          expect(
            ancestorScrollState.position.pixels,
            equals(ancestorScrollState.position.minScrollExtent),
          );
        },
        variant: _scrollTextFieldPlacedAtCenter,
      );
    });
  });
}

/// Sends a scrollToEnd event using platform appropriate shortcuts.
///
/// On macOS and web, (CMD + END) and END shortcuts are performed. On all other platforms,
/// (CTRL + END) is used.
///
/// [useHomeOnMacOrWeb] is used to toggle between using (CMD + END) and END on macOS
/// and web.
Future<void> _pressScrollToEndCombo(bool useHomeOnMacOrWeb, WidgetTester tester) async {
  if (useHomeOnMacOrWeb && (defaultTargetPlatform == TargetPlatform.macOS || isWeb)) {
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
  } else {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _pressCmdEnd(tester);
    } else {
      await _pressCtrlEnd(tester);
    }
  }
}

/// Sends a scrollToHome event using platform appropriate shortcuts.
///
/// On macOS and web, (CMD + HOME) and HOME shortcuts are performed. On all other platforms,
/// (CTRL + HOME) is used.
///
/// [useHomeOnMacOrWeb] is used to toggle between using (CMD + HOME) and HOME on macOS
/// and web.
Future<void> _pressScrollToTopCombo(bool useHomeOnMacOrWeb, WidgetTester tester) async {
  if (useHomeOnMacOrWeb && (defaultTargetPlatform == TargetPlatform.macOS || isWeb)) {
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
  } else {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await _pressCmdHome(tester);
    } else {
      await _pressCtrlHome(tester);
    }
  }
}

/// Variant for an [SuperTextField] experience with/without ancestor scrollable.
final _scrollingVariant = ValueVariant<_SuperTextFieldScrollSetup>({
  const _SuperTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperTextFieldTestApp,
    textInputSource: TextInputSource.ime,
  ),
  const _SuperTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperTextFieldTestApp,
    textInputSource: TextInputSource.keyboard,
  ),
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
  ),
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
  ),
  const _SuperTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperTextFieldTestApp,
    textInputSource: TextInputSource.ime,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperTextFieldTestApp,
    textInputSource: TextInputSource.keyboard,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollTextFieldPlacedAtTopVariant = ValueVariant<_SuperTextFieldScrollSetup>({
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
  ),
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
  ),
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollTextfieldPlacedAtBottomVariant = ValueVariant<_SuperTextFieldScrollSetup>({
  const _SuperTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.bottom,
  ),
  const _SuperTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.bottom,
  ),
  const _SuperTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.bottom,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.bottom,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollTextFieldPlacedAtCenter = ValueVariant<_SuperTextFieldScrollSetup>({
  const _SuperTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.center,
  ),
  const _SuperTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.center,
  ),
  const _SuperTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.center,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.center,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Pumps a [SuperTextField].
Future<void> _pumpSuperTextFieldTestApp(
  WidgetTester tester,
  TextInputSource textInputSource, [
  _,
]) async {
  return await _pumpTestApp(
    tester,
    textController: AttributedTextEditingController(
      text: AttributedText(_scrollableTextFieldText),
    ),
    minLines: 1,
    maxLines: 4,
    textInputSource: textInputSource,
  );
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  double? maxWidth,
  double? maxHeight,
  EdgeInsets? padding,
  TextInputSource? textInputSource,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: SuperTextField(
            textController: textController,
            lineHeight: 20,
            textStyleBuilder: (_) => const TextStyle(fontSize: 20),
            minLines: minLines,
            maxLines: maxLines,
            padding: padding,
            inputSource: textInputSource,
          ),
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for the final viewport size.
  await tester.pump();
}

/// Wrapper around [_pumpSuperTextFieldScrollSliverApp] for
/// convenience.
Future<void> _pumpSuperTextFieldWithinScrollableTestApp(
  WidgetTester tester,
  TextInputSource textInputSource, [
  _TextFieldPlacementWithinScrollable placement = _TextFieldPlacementWithinScrollable.top,
]) async {
  return await _pumpSuperTextFieldScrollSliverApp(
    tester,
    textController: AttributedTextEditingController(
      text: AttributedText(_scrollableTextFieldText),
    ),
    minLines: 1,
    maxLines: 4,
    textInputSource: textInputSource,
    placement: placement,
  );
}

/// Pumps a [SuperTextField] wrapped within [Scrollable].
Future<void> _pumpSuperTextFieldScrollSliverApp(
  WidgetTester tester, {
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  EdgeInsets? padding,
  TextInputSource? textInputSource,
  _TextFieldPlacementWithinScrollable placement = _TextFieldPlacementWithinScrollable.top,
}) async {
  final slivers = [
    if (placement == _TextFieldPlacementWithinScrollable.center)
      SliverList.builder(
        itemCount: 100,
        itemBuilder: (context, index) {
          return ListTile(title: Text("Item $index"));
        },
      ),
    SliverToBoxAdapter(
      child: SuperTextField(
        textController: textController,
        lineHeight: 20,
        textStyleBuilder: (_) => const TextStyle(fontSize: 20),
        minLines: minLines,
        maxLines: maxLines,
        padding: padding,
        inputSource: textInputSource,
      ),
    ),
    SliverList.builder(
      itemCount: 100,
      itemBuilder: (context, index) {
        return ListTile(title: Text("Item $index"));
      },
    ),
  ];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          key: textfieldsAncestorScrollableKey,
          slivers: placement == _TextFieldPlacementWithinScrollable.top //
              ? slivers
              : slivers.reversed.toList(),
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for the final viewport size.
  await tester.pump();
}

/// Key used by [SuperTextField]'s ancestor scrollable.
const textfieldsAncestorScrollableKey = ValueKey("AncestorScrollable");

final String _scrollableTextFieldText = List.generate(10, (index) => "Line $index").join("\n");

class _SuperTextFieldScrollSetup {
  const _SuperTextFieldScrollSetup({
    required this.description,
    required this.pumpEditor,
    required this.textInputSource,
    this.placement = _TextFieldPlacementWithinScrollable.top,
    this.useHomeEndToScrollOnMacOrWeb = false,
  });
  final String description;
  final _PumpEditorWidget pumpEditor;
  final TextInputSource textInputSource;
  final _TextFieldPlacementWithinScrollable placement;
  final bool useHomeEndToScrollOnMacOrWeb;

  @override
  String toString() {
    return "SuperTextFieldScrollSetup: $description, at ${placement.name},  ${textInputSource.toString()}, ${useHomeEndToScrollOnMacOrWeb ? "uses HOME/END to scroll on mac/web" : ""}";
  }
}

typedef _PumpEditorWidget = Future<void> Function(
  WidgetTester tester,
  TextInputSource textInputSource, [
  _TextFieldPlacementWithinScrollable placement,
]);

/// Defines the placement of [SuperTextField] within ancestor
/// scrollable.
enum _TextFieldPlacementWithinScrollable {
  top,
  center,
  bottom;
}

Future<void> _pressCmdHome(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.pumpAndSettle();
}

Future<void> _pressCmdEnd(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.pumpAndSettle();
}

Future<void> _pressCtrlHome(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.home, platform: 'macos');
  await tester.pumpAndSettle();
}

Future<void> _pressCtrlEnd(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control, platform: 'macos');
  await tester.sendKeyUpEvent(LogicalKeyboardKey.end, platform: 'macos');
  await tester.pumpAndSettle();
}
