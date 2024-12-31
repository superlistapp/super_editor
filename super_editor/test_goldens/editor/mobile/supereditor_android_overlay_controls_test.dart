import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_bricks/golden_bricks.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../../test/super_editor/supereditor_test_tools.dart';
import '../../test_tools_goldens.dart';

void main() {
  group("SuperEditor > Android > overlay controls >", () {
    testGoldensOnAndroid("confines magnifier within screen bounds", (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..platformDispatcher.textScaleFactorTestValue = 1.0
        ..physicalSize = const Size(400.0, 500.0);

      addTearDown(() => tester.platformDispatcher.clearAllTestValues());

      // Pump a widget tree with an empty space above the editor, so we can see the
      // whole magnifier.
      await tester //
          .createDocument()
          .withCustomContent(
            MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText('Lorem ipsum dolor sit amet'),
                ),
              ],
            ),
          )
          .useStylesheet(
            Stylesheet(
              rules: defaultStylesheet.rules,
              inlineTextStyler: (attributions, style) => _textStyleBuilder(attributions),
            ),
          )
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Column(
                  children: [
                    const SizedBox(height: 200),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Place the caret at the end of the paragraph.
      await tester.tapInParagraph("1", 26);

      // Press and drag the caret to the beginning of the line.
      final gesture = await tester.pressDownOnCollapsedMobileHandle();
      for (int i = 1; i <= 26; i++) {
        await gesture.moveBy(const Offset(-12, 0));
        await tester.pump();
      }

      await screenMatchesGolden(tester, 'supereditor_android_magnifier_screen_edges');

      // Release the gesture.
      await gesture.up();
    });
  });
}

TextStyle _textStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle(
    color: Colors.black,
    fontFamily: goldenBricks,
    fontSize: 16,
    height: 1.4,
  );
}
