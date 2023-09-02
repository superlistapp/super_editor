import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'supereditor_test_tools.dart';

void main() {
  group("SuperEditor > multiple editors >", () {
    testWidgetsOnAllPlatforms("can select both editors", (tester) async {
      final editor1Key = GlobalKey();
      final editor2Key = GlobalKey();

      await _buildTextScaleScaffold(
        tester,
        editor1: _buildSuperEditor(tester, key: editor1Key),
        editor2: _buildSuperEditor(tester, key: editor2Key),
      );

      // Select different text in each editor.
      // Text starts with: "Lorem ipsum dolor sit amet, consectetur adipiscing...."
      await tester.placeCaretInParagraph("1", 6, superEditorFinder: find.byKey(editor1Key));
      await tester.placeCaretInParagraph("1", 12, superEditorFinder: find.byKey(editor2Key));

      // Ensure that both editors have the expected selections.
      expect(
        SuperEditorInspector.findDocumentSelection(find.byKey(editor1Key)),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 6)),
        ),
      );
      expect(
        SuperEditorInspector.findDocumentSelection(find.byKey(editor2Key)),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 12)),
        ),
      );
    });
  });
}

Widget _buildSuperEditor(
  WidgetTester tester, {
  Key? key,
}) {
  return tester //
      .createDocument()
      .withSingleParagraph()
      .withKey(key)
      // Testing concurrent selections across multiple editors requires
      // that each editor leave their selection alone when losing focus
      // or closing the IME.
      .withSelectionPolicies(
        const SuperEditorSelectionPolicies(
          clearSelectionWhenEditorLosesFocus: false,
          clearSelectionWhenImeConnectionCloses: false,
        ),
      )
      .build()
      .widget;
}

/// Pumps a widget tree containing two editors side by side.
Future<void> _buildTextScaleScaffold(
  WidgetTester tester, {
  required Widget editor1,
  required Widget editor2,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: editor1,
            ),
            Expanded(
              child: editor2,
            ),
          ],
        ),
      ),
    ),
  );
}
