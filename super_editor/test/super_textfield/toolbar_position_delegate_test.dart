import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/toolbar_position_delegate.dart';

void main() {
  group('SuperTextField', () {
    group('toolbar delegate', () {
      const fakeScreenSize = Size(750, 1334);
      const fakeToolbarSize = Size(200, 48);
      final fakeTextFieldBoundingBox = Rect.fromCenter(
        center: fakeScreenSize.center(Offset.zero),
        width: fakeScreenSize.width - 48 - 48,
        height: 300,
      );

      test('positions itself above focal point and horizontally centered', () {
        // The top anchor point simulates an offset at the top
        // of a line of text.
        final fakeToolbarAnchorTop = fakeTextFieldBoundingBox.size.center(const Offset(0, -16));
        // The bottom anchor point simulates an offset at the bottom
        // of a line of text.
        final fakeToolbarAnchorBottom = fakeTextFieldBoundingBox.size.center(const Offset(0, 16));

        final delegate = ToolbarPositionDelegate(
          textFieldGlobalOffset: fakeTextFieldBoundingBox.topLeft,
          desiredTopAnchorInTextField: fakeToolbarAnchorTop,
          desiredBottomAnchorInTextField: fakeToolbarAnchorBottom,
        );

        final toolbarTopLeft = delegate.getPositionForChild(fakeScreenSize, fakeToolbarSize);

        // The toolbar has enough space to appear where it wants. We expect it
        // above the top anchor point and horizontally centered.
        expect(toolbarTopLeft, const Offset(275, 603));
      });

      test('constrains itself to the left side of the screen', () {
        // The top anchor point simulates an offset at the top
        // of a line of text.
        final fakeToolbarAnchorTop = Offset(50, fakeTextFieldBoundingBox.height / 2) + const Offset(0, -16);
        // The bottom anchor point simulates an offset at the bottom
        // of a line of text.
        final fakeToolbarAnchorBottom = Offset(50, fakeTextFieldBoundingBox.height / 2) + const Offset(0, 16);

        final delegate = ToolbarPositionDelegate(
          textFieldGlobalOffset: fakeTextFieldBoundingBox.topLeft,
          desiredTopAnchorInTextField: fakeToolbarAnchorTop,
          desiredBottomAnchorInTextField: fakeToolbarAnchorBottom,
        );

        final toolbarTopLeft = delegate.getPositionForChild(fakeScreenSize, fakeToolbarSize);

        // The toolbar's desired left edge is offscreen to the left.
        // We expect the left edge of the toolbar to be forced to the
        // left edge of the screen.
        expect(toolbarTopLeft, const Offset(0, 603));
      });

      test('constrains itself to the right side of the screen', () {
        // The top anchor point simulates an offset at the top
        // of a line of text.
        final fakeToolbarAnchorTop = Offset(700, fakeTextFieldBoundingBox.height / 2) + const Offset(0, -16);
        // The bottom anchor point simulates an offset at the bottom
        // of a line of text.
        final fakeToolbarAnchorBottom = Offset(700, fakeTextFieldBoundingBox.height / 2) + const Offset(0, 16);

        final delegate = ToolbarPositionDelegate(
          textFieldGlobalOffset: fakeTextFieldBoundingBox.topLeft,
          desiredTopAnchorInTextField: fakeToolbarAnchorTop,
          desiredBottomAnchorInTextField: fakeToolbarAnchorBottom,
        );

        final toolbarTopLeft = delegate.getPositionForChild(fakeScreenSize, fakeToolbarSize);

        // The toolbar's desired right edge is offscreen to the right.
        // We expect the right edge of the toolbar to be forced to the
        // right edge of the screen.
        expect(toolbarTopLeft, const Offset(750 - 200, 603));
      });

      test('positions itself below the content when it exceeds safe space above the content', () {
        // The top anchor point simulates an offset at the top
        // of a line of text.
        final fakeToolbarAnchorTop = Offset(fakeTextFieldBoundingBox.width / 2, 0);
        // The bottom anchor point simulates an offset at the bottom
        // of a line of text.
        final fakeToolbarAnchorBottom = Offset(fakeTextFieldBoundingBox.width / 2, 0) + const Offset(0, 32);

        final delegate = ToolbarPositionDelegate(
          // The text field global offset needs to be positioned near the top
          // of the screen so that the top anchor point pushes the toolbar
          // above the top of the screen.
          textFieldGlobalOffset: const Offset(48, 24),
          desiredTopAnchorInTextField: fakeToolbarAnchorTop,
          desiredBottomAnchorInTextField: fakeToolbarAnchorBottom,
        );

        final toolbarTopLeft = delegate.getPositionForChild(fakeScreenSize, fakeToolbarSize);

        // The toolbar's desired position places it above the top of the screen.
        // We expect the toolbar to switch to its bottom anchor point.
        expect(toolbarTopLeft, const Offset(275, 24 + 32));
      });
    });
  });
}
