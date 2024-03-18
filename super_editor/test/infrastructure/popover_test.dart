import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:follow_the_leader/follow_the_leader.dart';

import 'package:super_editor/src/infrastructure/default_popovers.dart';
import 'package:super_editor/src/infrastructure/popover_scaffold.dart';

void main() {
  group('PopoverScaffold', () {
    testWidgetsOnAllPlatforms('opens and closes the popover when requested', (tester) async {
      final popoverController = PopoverController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopoverScaffold(
              controller: popoverController,
              buttonBuilder: (context) => const SizedBox(),
              popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                child: SizedBox(),
              ),
            ),
          ),
        ),
      );

      // Ensure the popover isn't displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

      // Show the popover.
      popoverController.open();
      await tester.pump();

      // Ensure the popover is displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

      // Close the popover.
      popoverController.close();
      await tester.pump();

      // Ensure the popover was closed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);
    });

    testWidgetsOnAllPlatforms('closes the popover when tapping outside', (tester) async {
      final popoverController = PopoverController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: PopoverScaffold(
                  controller: popoverController,
                  buttonBuilder: (context) => const SizedBox(),
                  popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                    child: SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Ensure the popover isn't displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

      // Show the popover.
      popoverController.open();
      await tester.pumpAndSettle();

      // Ensure the popover is displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

      // Taps outside of the popover.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Ensure the popover was closed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);
    });

    testWidgetsOnAllPlatforms('does not close popover when tapping a widget with the same tap region groupId',
        (tester) async {
      final popoverController = PopoverController();

      const tapRegionGroupId = 'popover_scaffold';

      /// Pumps a tree with a PopoverScaffold at the top and a Button at the bottom,
      /// with a space between them.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 500,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: PopoverScaffold(
                        tapRegionGroupId: tapRegionGroupId,
                        controller: popoverController,
                        buttonBuilder: (context) => const SizedBox(),
                        popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                          child: SizedBox(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    child: TapRegion(
                      groupId: tapRegionGroupId,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const SizedBox(
                          height: 200,
                          width: 200,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Ensure the popover isn't displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

      // Show the popover.
      popoverController.open();
      await tester.pump();

      // Ensure the popover is displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

      // Tap the button.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Ensure the popover is still displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);
    });

    testWidgetsOnAllPlatforms('enforces the given popover geometry', (tester) async {
      final buttonKey = GlobalKey();
      final popoverController = PopoverController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PopoverScaffold(
                controller: popoverController,
                popoverGeometry: PopoverGeometry(
                  constraints: const BoxConstraints(maxHeight: 300),
                  align: (globalLeaderRect, followerSize, screenSize, boundaryKey) => const FollowerAlignment(
                    leaderAnchor: Alignment.topRight,
                    followerAnchor: Alignment.topLeft,
                    followerOffset: Offset(10, 10),
                  ),
                ),
                buttonBuilder: (context) => SizedBox(key: buttonKey),
                popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                  child: SizedBox(height: 500),
                ),
              ),
            ),
          ),
        ),
      );

      // Ensure the popover isn't displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

      // Show the popover.
      popoverController.open();
      await tester.pumpAndSettle();

      // Ensure the popover is displayed.
      expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

      final buttonRect = tester.getRect(find.byKey(buttonKey));
      final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

      // Ensure the given geometry was honored.
      expect(popoverRect.height, 300);
      expect(popoverRect.top, buttonRect.top + 10);
      expect(popoverRect.left, buttonRect.right + 10);
    });

    group('default popover geometry', () {
      group('with a boundary key', () {
        testWidgetsOnAllPlatforms('positions the popover below button if there is room', (tester) async {
          final boundaryKey = GlobalKey();
          final buttonKey = GlobalKey();
          final popoverController = PopoverController();

          // Use a screen size bigger than the boundary widget
          // to make sure we use the widget size instead of the screen size
          // to size and position the popover.
          tester.view
            ..devicePixelRatio = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSize = const Size(1000, 2000);
          addTearDown(() => tester.platformDispatcher.clearAllTestValues());

          // Pump a tree with a popover that fits below the button.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  key: boundaryKey,
                  height: 300,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        child: PopoverScaffold(
                          controller: popoverController,
                          boundaryKey: boundaryKey,
                          buttonBuilder: (context) => SizedBox(
                            key: buttonKey,
                            height: 50,
                          ),
                          popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                            child: SizedBox(height: 200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Ensure the popover isn't displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

          // Show the popover.
          popoverController.open();
          await tester.pumpAndSettle();

          // Ensure the popover is displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

          final buttonRect = tester.getRect(find.byKey(buttonKey));
          final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

          // Ensure popover was displayed below the button.
          expect(popoverRect.top, greaterThan(buttonRect.bottom));
        });

        testWidgetsOnAllPlatforms('positions the popover above button if there is room above but not below',
            (tester) async {
          final boundaryKey = GlobalKey();
          final buttonKey = GlobalKey();
          final popoverController = PopoverController();

          // Use a screen size bigger than the boundary widget
          // to make sure we use the widget size instead of the screen size
          // to size and position the popover.
          tester.view
            ..devicePixelRatio = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSize = const Size(1000, 2000);
          addTearDown(() => tester.platformDispatcher.clearAllTestValues());

          // Pump a tree with a popover that fits above the button.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  key: boundaryKey,
                  height: 300,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 250,
                        child: PopoverScaffold(
                          controller: popoverController,
                          boundaryKey: boundaryKey,
                          buttonBuilder: (context) => SizedBox(
                            key: buttonKey,
                            height: 50,
                          ),
                          popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                            child: SizedBox(height: 200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Ensure the popover isn't displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

          // Show the popover.
          popoverController.open();
          await tester.pumpAndSettle();

          // Ensure the popover is displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

          final buttonRect = tester.getRect(find.byKey(buttonKey));
          final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

          // Ensure popover was displayed above the button.
          expect(popoverRect.bottom, lessThan(buttonRect.top));
        });

        testWidgetsOnAllPlatforms(
            'pins the popover to the bottom of boundary if there is not room below or above the button',
            (tester) async {
          final boundaryKey = GlobalKey();
          final buttonKey = GlobalKey();
          final popoverController = PopoverController();

          // Use a screen size bigger than the boundary widget
          // to make sure we use the widget size instead of the screen size
          // to size and position the popover.
          tester.view
            ..devicePixelRatio = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSize = const Size(1000, 2000);
          addTearDown(() => tester.platformDispatcher.clearAllTestValues());

          // Pump a tree with a popover that doesn't fit below or above the button.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  key: boundaryKey,
                  height: 500,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 400,
                        child: PopoverScaffold(
                          controller: popoverController,
                          boundaryKey: boundaryKey,
                          buttonBuilder: (context) => SizedBox(
                            key: buttonKey,
                            height: 50,
                          ),
                          popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                            child: SizedBox(height: 700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Ensure the popover isn't displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

          // Show the popover.
          popoverController.open();
          await tester.pumpAndSettle();

          // Ensure the popover is displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

          final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

          // Ensure popover was pinned of the bottom to the boundary widget
          // and did not exceeded the boundary size.
          expect(popoverRect.bottom, 500);
          expect(popoverRect.height, 500);
        });
      });

      group('without a boundary key', () {
        testWidgetsOnAllPlatforms('positions the popover below button if there is room', (tester) async {
          final buttonKey = GlobalKey();
          final popoverController = PopoverController();

          tester.view
            ..devicePixelRatio = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSize = const Size(1000, 600);

          addTearDown(() => tester.platformDispatcher.clearAllTestValues());

          // Pump a tree with a popover that fits below the button.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PopoverScaffold(
                  controller: popoverController,
                  buttonBuilder: (context) => SizedBox(
                    key: buttonKey,
                    height: 50,
                  ),
                  popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                    child: SizedBox(height: 500),
                  ),
                ),
              ),
            ),
          );

          // Ensure the popover isn't displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

          // Show the popover.
          popoverController.open();
          await tester.pumpAndSettle();

          // Ensure the popover is displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

          final buttonRect = tester.getRect(find.byKey(buttonKey));
          final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

          // Ensure popover was displayed below the button.
          expect(popoverRect.top, greaterThan(buttonRect.bottom));
        });

        testWidgetsOnAllPlatforms('positions the popover above button if there is room above but not below',
            (tester) async {
          final buttonKey = GlobalKey();
          final popoverController = PopoverController();

          tester.view
            ..devicePixelRatio = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSize = const Size(1000, 800);

          addTearDown(() => tester.platformDispatcher.clearAllTestValues());

          // Pump a tree with a popover that doesn't fit below the button, but fits above it.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Container(
                  alignment: Alignment.bottomCenter,
                  child: PopoverScaffold(
                    controller: popoverController,
                    buttonBuilder: (context) => SizedBox(
                      key: buttonKey,
                      height: 50,
                    ),
                    popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                      child: SizedBox(height: 500),
                    ),
                  ),
                ),
              ),
            ),
          );

          // Ensure the popover isn't displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

          // Show the popover.
          popoverController.open();
          await tester.pumpAndSettle();

          // Ensure the popover is displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

          final buttonRect = tester.getRect(find.byKey(buttonKey));
          final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

          // Ensure popover was displayed above the button.
          expect(popoverRect.bottom, lessThan(buttonRect.top));
        });

        testWidgetsOnAllPlatforms(
            'pins the popover to the bottom of screen if there is not room below or above the button', (tester) async {
          final buttonKey = GlobalKey();
          final popoverController = PopoverController();

          tester.view
            ..devicePixelRatio = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSize = const Size(1000, 600);

          addTearDown(() => tester.platformDispatcher.clearAllTestValues());

          // Pump a tree with a popover that doesn't fit below or above the button.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: PopoverScaffold(
                    controller: popoverController,
                    buttonBuilder: (context) => SizedBox(
                      key: buttonKey,
                      height: 50,
                    ),
                    popoverBuilder: (context) => const RoundedRectanglePopoverAppearance(
                      child: SizedBox(height: 500),
                    ),
                  ),
                ),
              ),
            ),
          );

          // Ensure the popover isn't displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsNothing);

          // Show the popover.
          popoverController.open();
          await tester.pumpAndSettle();

          // Ensure the popover is displayed.
          expect(find.byType(RoundedRectanglePopoverAppearance), findsOneWidget);

          final popoverRect = tester.getRect(find.byType(RoundedRectanglePopoverAppearance));

          // Ensure popover was displayed pinned to the bottom of the screen.
          expect(popoverRect.bottom, 600);
        });
      });
    });

    testWidgetsOnAllPlatforms('shares focus with widgets of a different subtree', (tester) async {
      // When PopoverScaffold is in a different subtree from the currently focused widget,
      // for example, an Overlay or OverlayPortal, it doesn't naturally shares focus with it.
      //
      // This test makes sure PopoverScaffold has the ability to setup focus sharing
      // with widgets of a different subtree, so the popover shares focus with a parent FocusNode.

      final parentFocusNode = FocusNode();
      final popoverFocusNode = FocusNode();

      final popoverController = PopoverController();
      final overLayControler = OverlayPortalController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(
              focusNode: parentFocusNode,
              child: OverlayPortal(
                controller: overLayControler,
                overlayChildBuilder: (context) => PopoverScaffold(
                  controller: popoverController,
                  parentFocusNode: parentFocusNode,
                  popoverFocusNode: popoverFocusNode,
                  buttonBuilder: (context) => const SizedBox(),
                  popoverBuilder: (context) => Focus(
                    focusNode: popoverFocusNode,
                    child: const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Focus the parent node.
      parentFocusNode.requestFocus();
      await tester.pump();
      expect(parentFocusNode.hasPrimaryFocus, true);

      // Show the overlay.
      overLayControler.show();
      await tester.pumpAndSettle();

      // Show the popover.
      popoverController.open();
      await tester.pumpAndSettle();

      // Ensure the parent node has non-primary focus.
      expect(parentFocusNode.hasFocus, true);
      expect(parentFocusNode.hasPrimaryFocus, isFalse);

      // Close the popover.
      popoverController.close();
      await tester.pump();

      // Ensure the parent node has primary focus again.
      expect(parentFocusNode.hasPrimaryFocus, true);
    });
  });
}
