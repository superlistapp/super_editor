import 'package:flutter/material.dart';
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
                  align: (globalLeaderRect, followerSize, boundaryKey) => const FollowerAlignment(
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

    testWidgetsOnAllPlatforms('shares focus with other widgets', (tester) async {
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
