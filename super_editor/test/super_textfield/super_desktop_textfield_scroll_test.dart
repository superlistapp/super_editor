import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_runners.dart';

void main() {
  group("SuperDesktopTextField", () {
    group("textfield scrolling", () {
      testWidgetsOnDesktopAndWeb(
        'PAGE DOWN scrolls down by the viewport height',
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find textfield scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
          await tester.pump();

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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
          await tester.pump();

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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
          await tester.pump();

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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll to the bottom of the viewport.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
          await tester.pump();

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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the top but not all the way to avoid explicit
          // checks comparing scroll offset directly against `minScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
          await tester.pump();

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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            _scrollingVariant.currentValue!.textInputSource,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
            matching: find.byType(Scrollable),
          ));

          // Scroll very close to the bottom but not all the way to avoid explicit
          // checks comparing scroll offset directly against `maxScrollExtent`
          // and test scrolling behaviour in more realistic manner.
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
          await tester.pump();

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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant.pumpEditor(
            tester,
            currentVariant.textInputSource,
            currentVariant.placement,
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(find.descendant(
            of: find.byType(SuperDesktopTextField),
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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
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

          // Find SuperDesktopTextField scrollable
          final scrollState = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ),
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

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

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
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
            find.byType(SuperDesktopTextField),
            200,
          );
          await tester.pump();

          // Find SuperDesktopTextField scrollable.
          final scrollState = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ),
          );

          // Tap on the textfield to focus it.
          await tester.tap(find.byType(SuperDesktopTextField));

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

/// Variant for an [SuperDesktopTextField] experience with/without ancestor scrollable.
final _scrollingVariant = ValueVariant<_SuperDesktopTextFieldScrollSetup>({
  const _SuperDesktopTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldTestApp,
    textInputSource: TextInputSource.ime,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldTestApp,
    textInputSource: TextInputSource.keyboard,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldTestApp,
    textInputSource: TextInputSource.ime,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "without ancestor scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldTestApp,
    textInputSource: TextInputSource.keyboard,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollTextFieldPlacedAtTopVariant = ValueVariant<_SuperDesktopTextFieldScrollSetup>({
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollTextfieldPlacedAtBottomVariant = ValueVariant<_SuperDesktopTextFieldScrollSetup>({
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.bottom,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.bottom,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.bottom,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at botton inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.bottom,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Variant for an editor experience with an internal scrollable and
/// an ancestor scrollable.
final _scrollTextFieldPlacedAtCenter = ValueVariant<_SuperDesktopTextFieldScrollSetup>({
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.center,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.center,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.center,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "placed at center inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldWithinScrollableTestApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.center,
    useHomeEndToScrollOnMacOrWeb: true,
  ),
});

/// Pumps a [SuperDesktopTextField].
Future<void> _pumpSuperDesktopTextFieldTestApp(
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
  TextInputSource textInputSource = TextInputSource.keyboard,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: SuperDesktopTextField(
            textController: textController,
            textStyleBuilder: (_) => const TextStyle(fontSize: 20),
            minLines: minLines,
            maxLines: maxLines,
            inputSource: textInputSource,
          ),
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for the final viewport size.
  await tester.pump();
}

/// Wrapper around [_pumpSuperDesktopTextFieldScrollSliverApp] for
/// convenience.
Future<void> _pumpSuperDesktopTextFieldWithinScrollableTestApp(
  WidgetTester tester,
  TextInputSource textInputSource, [
  _TextFieldPlacementWithinScrollable placement = _TextFieldPlacementWithinScrollable.top,
]) async {
  return await _pumpSuperDesktopTextFieldScrollSliverApp(
    tester,
    textController: AttributedTextEditingController(
      text: AttributedText(_scrollableTextFieldText),
    ),
    minLines: 4, // Provides sufficient space to test out textfields scrolling behaviour
    // properly.
    maxLines: 4,
    textInputSource: textInputSource,
    placement: placement,
  );
}

/// Pumps a [SuperDesktopTextField] wrapped within [Scrollable].
Future<void> _pumpSuperDesktopTextFieldScrollSliverApp(
  WidgetTester tester, {
  required AttributedTextEditingController textController,
  required int minLines,
  required int maxLines,
  TextInputSource textInputSource = TextInputSource.keyboard,
  _TextFieldPlacementWithinScrollable placement = _TextFieldPlacementWithinScrollable.top,
}) async {
  final slivers = [
    if (placement == _TextFieldPlacementWithinScrollable.center)
      SliverToBoxAdapter(
        child: Builder(builder: (context) {
          return SizedBox(
            height: MediaQuery.of(context).size.height,
            width: double.maxFinite,
            child: const Placeholder(
              child: Center(
                child: Text("Content"),
              ),
            ),
          );
        }),
      ),
    SliverToBoxAdapter(
      child: SuperDesktopTextField(
        textController: textController,
        textStyleBuilder: (_) => const TextStyle(fontSize: 20),
        minLines: minLines,
        maxLines: maxLines,
        inputSource: textInputSource,
      ),
    ),
    SliverToBoxAdapter(
      child: Builder(builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height,
          width: double.maxFinite,
          child: const Placeholder(
            child: Center(
              child: Text("Content"),
            ),
          ),
        );
      }),
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

/// Key used by [SuperDesktopTextField]'s ancestor scrollable.
const textfieldsAncestorScrollableKey = ValueKey("AncestorScrollable");

final String _scrollableTextFieldText = List.generate(10, (index) => "Line $index").join("\n");

class _SuperDesktopTextFieldScrollSetup {
  const _SuperDesktopTextFieldScrollSetup({
    required this.description,
    required this.pumpEditor,
    required this.textInputSource,
    this.placement = _TextFieldPlacementWithinScrollable.top,
    this.useHomeEndToScrollOnMacOrWeb = false,
  });
  final String description;
  final _PumpSuperDesktopTextFieldWidget pumpEditor;
  final TextInputSource textInputSource;
  final _TextFieldPlacementWithinScrollable placement;
  final bool useHomeEndToScrollOnMacOrWeb;

  @override
  String toString() {
    return "SuperDesktopTextFieldScrollSetup: $description, at ${placement.name},  ${textInputSource.toString()}, ${useHomeEndToScrollOnMacOrWeb ? "uses HOME/END to scroll on mac/web" : ""}";
  }
}

/// Holds the setup for a text field scroll test.
typedef _PumpSuperDesktopTextFieldWidget = Future<void> Function(
  WidgetTester tester,
  TextInputSource textInputSource, [
  _TextFieldPlacementWithinScrollable placement,
]);

/// Defines the placement of [SuperDesktopTextField] within ancestor
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
