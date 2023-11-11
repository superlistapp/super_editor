import 'dart:js_util';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

import '../test_runners.dart';
import 'super_textfield_robot.dart';

void main() {
  group("SuperDesktopTextField", () {
    group("text field scrolling", () {
      testWidgetsOnDesktopAndWeb(
        'PAGE DOWN scrolls down by the viewport height',
        (tester) async {
          final currentVariant = _scrollingVariant.currentValue;

          // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
          await currentVariant!.pumpEditor(
            tester,
            textInputSource: currentVariant.textInputSource,
            placement: currentVariant.placement,
          );

          // Tap on the text field to focus it.
          await tester.placeCaretInSuperDesktopTextField(0);

          // Find text field scrollable.
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
            textInputSource: currentVariant.textInputSource,
            placement: currentVariant.placement,
          );

          // Tap on the text field to focus it.
          await tester.placeCaretInSuperDesktopTextField(0);

          // Find text field scrollable.
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
            textInputSource: currentVariant.textInputSource,
            placement: currentVariant.placement,
          );

          // Tap on the text field to focus it.
          await tester.placeCaretInSuperDesktopTextField(0);

          // Find text field scrollable.
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
            textInputSource: currentVariant.textInputSource,
            placement: currentVariant.placement,
          );

          // Tap on the text field to focus it.
          await tester.placeCaretInSuperDesktopTextField(0);

          // Find text field scrollable.
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

      group("scrolls to top of viewport", () {
        testWidgetsOnDesktop(
          'using CMD + HOME on mac and CTRL + HOME on other platforms',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to the bottom of the viewport.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
            await tester.pump();

            // Scroll to viewport's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to the viewport's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnMac(
          'using HOME on mac',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to the bottom of the viewport.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
            await tester.pump();

            // Scroll to viewport's top.
            await tester.pressHome();

            // Ensure we scrolled to the viewport's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );
          },
          variant: _scrollingVariant,
        );
        testWidgetsOnWebDesktop(
          'using HOME on web desktop',
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to the bottom of the viewport.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
            await tester.pump();

            // Scroll to viewport's top.
            await tester.pressHome();

            // Ensure we scrolled to the viewport's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );
          },
          variant: _scrollingVariant,
        );
      });

      group("does not scroll past top of the viewport", () {
        testWidgetsOnDesktop(
          "using CMD + HOME on mac and CTRL + HOME on other platforms ",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the top but not all the way to avoid explicit
            // checks comparing scroll offset directly against `minScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
            await tester.pump();

            // Scroll to viewport's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we didn't scroll past the viewport's top.
            expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnMac(
          "using HOME on mac",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the top but not all the way to avoid explicit
            // checks comparing scroll offset directly against `minScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
            await tester.pump();

            // Scroll to viewport's top.
            await tester.pressHome();

            // Ensure we didn't scroll past the viewport's top.
            expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
          },
          variant: _scrollingVariant,
        );
        testWidgetsOnWebDesktop(
          "using HOME on web desktop",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the top but not all the way to avoid explicit
            // checks comparing scroll offset directly against `minScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.minScrollExtent + 10);
            await tester.pump();

            // Scroll to viewport's top.
            await tester.pressHome();

            // Ensure we didn't scroll past the viewport's top.
            expect(scrollState.position.pixels, equals(scrollState.position.minScrollExtent));
          },
          variant: _scrollingVariant,
        );
      });

      group("scrolls to bottom of viewport", () {
        testWidgetsOnDesktop(
          "using CMD + END on mac and CTRL + END on other platforms ",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to viewport's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            // Ensure we scrolled to the viewport's bottom.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnMac(
          "using END on mac",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to viewport's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to the viewport's bottom.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnWebDesktop(
          "using END on web desktop",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll to viewport's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to the viewport's bottom.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );
      });

      group("does not scroll past bottom of the viewport", () {
        testWidgetsOnDesktop(
          "using CMD + END on mac and CTRL + END on other platforms ",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the bottom but not all the way to avoid explicit
            // checks comparing scroll offset directly against `maxScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
            await tester.pump();

            // Scroll to viewport's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }
            // Ensure we didn't scroll past the viewport's bottom.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnMac(
          "using END on mac",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the bottom but not all the way to avoid explicit
            // checks comparing scroll offset directly against `maxScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
            await tester.pump();

            // Scroll to viewport's bottom.
            await tester.pressEnd();
            // Ensure we didn't scroll past the viewport's bottom.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );

        testWidgetsOnWebDesktop(
          "using END on web desktop",
          (tester) async {
            final currentVariant = _scrollingVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await currentVariant!.pumpEditor(
              tester,
              textInputSource: currentVariant.textInputSource,
              placement: currentVariant.placement,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Scroll very close to the bottom but not all the way to avoid explicit
            // checks comparing scroll offset directly against `maxScrollExtent`
            // and test scrolling behaviour in more realistic manner.
            scrollState.position.jumpTo(scrollState.position.maxScrollExtent - 10);
            await tester.pump();

            // Scroll to viewport's bottom.
            await tester.pressEnd();

            // Ensure we didn't scroll past the viewport's bottom.
            expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
          },
          variant: _scrollingVariant,
        );
      });
    });

    group("text field scrolling within ancestor scrollable", () {
      group('''scrolls from top->bottom of textfiled and then towards bottom of 
        the page and back to the top of the page''', () {
        testWidgetsOnDesktop(
          "using CMD + HOME/END on mac and CTRL + HOME/END on other platforms",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.top,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Find the text field's  ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Scrolls to text field's bottom.

            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }
            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.

            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );
        testWidgetsOnMac(
          "using HOME and END on mac",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.top,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Find the text field's  ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Scrolls to text field's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        testWidgetsOnWebDesktop(
          "using HOME and END on web desktop",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.top,
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SuperDesktopTextField),
              matching: find.byType(Scrollable),
            ));

            // Find the text field's  ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Scrolls to text field's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );
      });

      group('''when placed at bottom of page, scrolls all the way from top of the text field to 
        bottom of the page and back to the top of the page''', () {
        testWidgetsOnDesktop(
          "using CMD + HOME/END on mac and CTRL + HOME/END on other platforms",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.bottom,
            );

            // Find the text field's ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            ancestorScrollState.position.jumpTo(ancestorScrollState.position.maxScrollExtent);
            await tester.pump();

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

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Scroll all the way to the text field's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        testWidgetsOnMac(
          "using HOME and END on mac",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.bottom,
            );

            // Find the text field's ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
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

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Scroll all the way to the text field's bottom.
            await tester.pressEnd();

            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        testWidgetsOnWebDesktop(
          "using HOME and END on web desktop",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.bottom,
            );

            // Find the text field's ancestor scrollable
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
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

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Scroll all the way to the text field's bottom.
            await tester.pressEnd();

            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );
      });

      group('''when placed at the center of page, scrolls all the way from top to bottom of 
        text field and page, and then back to the top of the page''', () {
        testWidgetsOnDesktop(
          "using CMD + HOME/END on mac and CTRL + HOME/END on other platforms",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.center,
            );

            // Find the text field's ancestor scrollable.
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(SuperDesktopTextField),
                matching: find.byType(Scrollable),
              ),
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Ensure we are at the top of the textfiled.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to text field's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdEnd(tester);
            } else {
              await tester.pressCtrlEnd(tester);
            }

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            if (defaultTargetPlatform == TargetPlatform.macOS) {
              await tester.pressCmdHome(tester);
            } else {
              await tester.pressCtrlHome(tester);
            }

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        testWidgetsOnMac(
          "using HOME and END on mac",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.center,
            );

            // Find the text field's ancestor scrollable.
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(SuperDesktopTextField),
                matching: find.byType(Scrollable),
              ),
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Ensure we are at the top of the textfiled.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to text field's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );

        testWidgetsOnWebDesktop(
          "using HOME and END on web desktop",
          (tester) async {
            final currentVariant = _textFieldInputSourceVariant.currentValue;

            // Pump the widget tree with a SuperDesktopTextField which is four lines tall.
            await _pumpSuperDesktopTextFieldScrollSliverApp(
              tester,
              textInputSource: currentVariant!,
              placement: _TextFieldPlacementWithinScrollable.center,
            );

            // Find the text field's ancestor scrollable.
            final ancestorScrollState = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );

            // Find text field scrollable.
            final scrollState = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(SuperDesktopTextField),
                matching: find.byType(Scrollable),
              ),
            );

            // Tap on the text field to focus it.
            await tester.placeCaretInSuperDesktopTextField(0);

            // Ensure we are at the top of the textfiled.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to text field's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to text field's bottom.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.maxScrollExtent),
            );

            // Scrolls to ancestor scrollable's bottom.
            await tester.pressEnd();

            // Ensure we scrolled to ancestor scrollable's bottom.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.maxScrollExtent),
            );

            // Scrolls to text field's top.
            await tester.pressHome();

            // Ensure we scrolled to text field's top.
            expect(
              scrollState.position.pixels,
              equals(scrollState.position.minScrollExtent),
            );

            // Scrolls to ancestor scrollable's top.
            await tester.pressHome();

            // Ensure we scrolled to ancestor scrollable's top.
            expect(
              ancestorScrollState.position.pixels,
              equals(ancestorScrollState.position.minScrollExtent),
            );
          },
          variant: _textFieldInputSourceVariant,
        );
      });
    });
  });
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
    pumpEditor: _pumpSuperDesktopTextFieldScrollSliverApp,
    textInputSource: TextInputSource.ime,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldScrollSliverApp,
    textInputSource: TextInputSource.keyboard,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldScrollSliverApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.center,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldScrollSliverApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.center,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldScrollSliverApp,
    textInputSource: TextInputSource.ime,
    placement: _TextFieldPlacementWithinScrollable.bottom,
  ),
  const _SuperDesktopTextFieldScrollSetup(
    description: "inside scrollable",
    pumpEditor: _pumpSuperDesktopTextFieldScrollSliverApp,
    textInputSource: TextInputSource.keyboard,
    placement: _TextFieldPlacementWithinScrollable.bottom,
  ),
});

/// Variant for [SuperDesktopTextField]'s text input source.
final _textFieldInputSourceVariant = ValueVariant<TextInputSource>({
  TextInputSource.keyboard,
  TextInputSource.ime,
});

/// Pumps a [SuperDesktopTextField].
Future<void> _pumpSuperDesktopTextFieldTestApp(
  WidgetTester tester, {
  TextInputSource textInputSource = TextInputSource.keyboard,
  _TextFieldPlacementWithinScrollable placement = _TextFieldPlacementWithinScrollable.top,
}) async {
  final textController = AttributedTextEditingController(
    text: AttributedText(_textFieldInput),
  );

  return await _pumpTestApp(
    tester,
    textController: textController,
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

/// Pumps a [SuperDesktopTextField] wrapped within [Scrollable].
Future<void> _pumpSuperDesktopTextFieldScrollSliverApp(
  WidgetTester tester, {
  TextInputSource textInputSource = TextInputSource.keyboard,
  _TextFieldPlacementWithinScrollable placement = _TextFieldPlacementWithinScrollable.top,
}) async {
  final textController = AttributedTextEditingController(
    text: AttributedText(_textFieldInput),
  );

  final slivers = [
    if (placement == _TextFieldPlacementWithinScrollable.bottom ||
        placement == _TextFieldPlacementWithinScrollable.center)
      SliverToBoxAdapter(
        // Occupy 95% of the vertical space to avoid pushing text field off-screen.
        child: Builder(builder: (context) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            width: double.infinity,
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
        // Force the text field to be tall enough to easily see content scrolling by,
        // but short enough to ensure that the content is scrollable.
        minLines: 4,
        maxLines: 4,
        inputSource: textInputSource,
      ),
    ),
    if (placement == _TextFieldPlacementWithinScrollable.top || placement == _TextFieldPlacementWithinScrollable.center)
      SliverToBoxAdapter(
        child: Builder(builder: (context) {
          return SizedBox(
            height: MediaQuery.of(context).size.height,
            width: double.infinity,
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
          slivers: slivers,
        ),
      ),
    ),
  );

  // The first frame might have a zero viewport height. Pump a second frame to account for
  // the final viewport size.
  await tester.pump();
}

/// An arbitrary input, long enough to introduce scrollable content
/// within text field.
final String _textFieldInput = List.generate(10, (index) => "Line $index").join("\n");

/// Defines [SuperDesktopTextField] test configurations for a test variant.
///
/// Specificed configurations alter the conditions under which we test
/// [SuperDesktopTextField] scrolling on scroll actions invoked through shortcuts.
///
/// If [useHomeEndShortcutsOnMacAndWeb] is true, tests use 'HOME/END' to scroll
/// to top/bottom of the text field respectively, else 'CMD' + 'HOME/END' or
/// 'CTRL' + 'HOME/END' shortcuts are used depending on the platform tests are running on.
class _SuperDesktopTextFieldScrollSetup {
  const _SuperDesktopTextFieldScrollSetup({
    required this.description,
    required this.pumpEditor,
    required this.textInputSource,
    this.placement = _TextFieldPlacementWithinScrollable.top,
  });
  final String description;
  final _PumpSuperDesktopTextFieldWidget pumpEditor;
  final TextInputSource textInputSource;
  final _TextFieldPlacementWithinScrollable placement;

  @override
  String toString() {
    return '''SuperDesktopTextFieldScrollSetup: $description, placed at ${placement.name},  ${textInputSource.toString()}''';
  }
}

/// Pumps a [SuperDesktopTextField] experience with the given [textInputSource].
///
/// Optionally takes in [placement] which can be used to decide on the text field's placement
/// within parent.
typedef _PumpSuperDesktopTextFieldWidget = Future<void> Function(
  WidgetTester tester, {
  TextInputSource textInputSource,
  _TextFieldPlacementWithinScrollable placement,
});

/// Defines the placement of [SuperDesktopTextField] within ancestor
/// scrollable.
///
/// Testing against different layouts helps verify that the text field's scrolling
/// through scroll shortcuts remains same irrespective of the text field's placement
/// within ancestor scrollable.
enum _TextFieldPlacementWithinScrollable {
  top,
  center,
  bottom;
}
