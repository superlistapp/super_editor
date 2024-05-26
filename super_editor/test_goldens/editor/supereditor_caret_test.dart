import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test/super_editor/supereditor_test_tools.dart';
import '../test_tools_goldens.dart';

void main() {
  group('SuperEditor > caret rendering >', () {
    testGoldensOnMac('shows caret at right side of an image', (tester) async {
      await _pumpCaretTestApp(tester);

      // Tap close to the right edge of the editor to place the caret
      // downstream on the image.
      await tester.tapAt(
        tester.getTopRight(find.byType(SuperEditor)) + const Offset(-20, 20),
      );
      await tester.pump();

      await screenMatchesGolden(tester, 'super-editor-image-caret-downstream-mac');
    });

    testGoldensOniOS('shows caret at right side of an image', (tester) async {
      await _pumpCaretTestApp(tester);

      // Tap close to the right edge of the editor to place the caret
      // downstream on the image.
      await tester.tapAt(
        tester.getTopRight(find.byType(SuperEditor)) + const Offset(-20, 20),
      );
      await tester.pump();

      await screenMatchesGolden(tester, 'super-editor-image-caret-downstream-ios');
    });

    testGoldensOnAndroid(
      'shows caret at right side of an image',
      (tester) async {
        await _pumpCaretTestApp(tester);

        // Tap close to the right edge of the editor to place the caret
        // downstream on the image.
        await tester.tapAt(
          tester.getTopRight(find.byType(SuperEditor)) + const Offset(-20, 20),
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'super-editor-image-caret-downstream-android');
      },
      // TODO: find out why this test fails on CI only.
      skip: true,
    );

    testGoldensOnMac('shows caret at left side of an image', (tester) async {
      await _pumpCaretTestApp(tester);

      // Tap close to the left edge of the editor to place the caret upstream
      // on the image.
      await tester.tapAt(
        tester.getTopLeft(find.byType(SuperEditor)) + const Offset(20, 20),
      );
      await tester.pump();

      await screenMatchesGolden(tester, 'super-editor-image-caret-upstream-mac');
    });

    testGoldensOniOS('shows caret at left side of an image', (tester) async {
      await _pumpCaretTestApp(tester);

      // Tap close to the left edge of the editor to place the caret upstream
      // on the image.
      await tester.tapAt(
        tester.getTopLeft(find.byType(SuperEditor)) + const Offset(20, 20),
      );
      await tester.pump();

      await screenMatchesGolden(tester, 'super-editor-image-caret-upstream-ios');
    });

    testGoldensOnAndroid(
      'shows caret at left side of an image',
      (tester) async {
        await _pumpCaretTestApp(tester);

        // Tap close to the left edge of the editor to place the caret upstream
        // on the image.
        await tester.tapAt(
          tester.getTopLeft(find.byType(SuperEditor)) + const Offset(20, 20),
        );
        await tester.pump();

        await screenMatchesGolden(tester, 'super-editor-image-caret-upstream-android');
      },
      // TODO: find out why this test fails on CI only.
      skip: true,
    );

    testGoldensOniOS('allows customizing the caret width', (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withIosCaretStyle(width: 4.0)
          .pump();

      // Place caret at "Lorem ip|sum"
      await tester.placeCaretInParagraph('1', 8);

      await screenMatchesGolden(tester, 'super-editor-ios-custom-caret-width');
    });

    testGoldensOniOS('allows customizing the expanded handle width', (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withIosCaretStyle(width: 4.0)
          .pump();

      // Double tap to select the word ipsum.
      await tester.doubleTapInParagraph('1', 8);

      await screenMatchesGolden(tester, 'super-editor-ios-custom-handle-width');
    });

    testGoldensOniOS('allows customizing the expanded handle ball diameter', (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withIosCaretStyle(handleBallDiameter: 16.0)
          .pump();

      // Double tap to select the word ipsum.
      await tester.doubleTapInParagraph('1', 8);

      await screenMatchesGolden(tester, 'super-editor-ios-custom-handle-ball-diameter');
    });

    testGoldensOnAndroid('allows customizing the caret width', (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withAndroidCaretStyle(width: 4)
          .pump();

      // Place caret at "Lorem ip|sum"
      await tester.placeCaretInParagraph('1', 8);

      await screenMatchesGolden(tester, 'super-editor-android-custom-caret-width');
    });
  });
}

// Pumps an editor with a single image that takes all the available width.
Future<void> _pumpCaretTestApp(WidgetTester tester) async {
  await tester //
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ImageNode(
              id: '1',
              imageUrl: 'https://this.is.a.fake.image',
              metadata: const SingleColumnLayoutComponentStyles(
                width: double.infinity,
              ).toMetadata(),
            ),
          ],
        ),
      )
      .withCaretStyle(
        caretStyle: const CaretStyle(color: Colors.red),
      )
      .useStylesheet(
        defaultStylesheet.copyWith(addRulesAfter: [
          StyleRule(
            BlockSelector.all,
            (doc, docNode) => {
              // Zeroes the padding so the component takes all
              // the editor width.
              Styles.padding: const CascadingPadding.all(0.0),
            },
          )
        ]),
      )
      .withAddedComponents(
    [
      const FakeImageComponentBuilder(
        size: Size(double.infinity, 100),
        fillColor: Colors.yellow,
      ),
    ],
  ).pump();
}
