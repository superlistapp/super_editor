import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'supereditor_test_tools.dart';

void main() {
  group('SuperEditor > single column layout >', () {
    testWidgetsOnAllPlatforms('updates component width after changing component styles', (tester) async {
      // Pump an editor with an arbitrary size, so we know
      // the maximum width a component can be.
      final context = await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withEditorSize(const Size(1000.0, 5000.0))
          .pump();

      // Hold the padding before running the command.
      final paddingBefore = tester
          .widget<Padding>(find
              .ancestor(
                of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
                matching: find.byType(Padding),
              )
              .first)
          .padding;

      // Ensure the component doesn't start taking all the available width.
      expect(
        SuperEditorInspector.findComponentSize('1').width,
        lessThan(1000.0 - paddingBefore.horizontal),
      );

      // Changes the width.
      context.editor.execute(
        const [
          ChangeSingleColumnLayoutComponentStylesRequest(
            nodeId: '1',
            styles: SingleColumnLayoutComponentStyles(
              width: double.infinity,
            ),
          ),
        ],
      );
      await tester.pump();

      // Ensure the component took all available width and the padding didn't chagne.
      final paddingAfter = tester
          .widget<Padding>(find
              .ancestor(
                of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
                matching: find.byType(Padding),
              )
              .first)
          .padding;
      expect(paddingAfter, paddingBefore);
      expect(SuperEditorInspector.findComponentSize('1').width, 1000.0 - paddingBefore.horizontal);
    });
  });

  testWidgetsOnAllPlatforms('updates component padding after changing component styles', (tester) async {
    final context = await tester
        .createDocument() //
        .withSingleEmptyParagraph()
        .pump();

    // Ensure the component started with some padding.
    final paddingBefore = tester.widget<Padding>(find
        .ancestor(
          of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
          matching: find.byType(Padding),
        )
        .first);
    expect(paddingBefore.padding.horizontal, greaterThan(0.0));

    // Changes the padding.
    context.editor.execute(
      const [
        ChangeSingleColumnLayoutComponentStylesRequest(
          nodeId: '1',
          styles: SingleColumnLayoutComponentStyles(
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    await tester.pump();

    // Ensure the padding was removed.
    final paddingAfter = tester.widget<Padding>(find
        .ancestor(
          of: find.byWidget(SuperEditorInspector.findWidgetForComponent('1')),
          matching: find.byType(Padding),
        )
        .first);
    expect(paddingAfter.padding.horizontal, 0.0);
  });
}
