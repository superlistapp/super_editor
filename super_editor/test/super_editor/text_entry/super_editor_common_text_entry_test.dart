import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../test_tools.dart';
import '../../test_tools_user_input.dart';
import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor common text entry >", () {
    testWidgetsOnAllPlatforms("control keys don't impact content", (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withInputSource(inputSourceVariant.currentValue!)
          .pump();

      final initialParagraphText = SuperEditorInspector.findTextInParagraph("1");

      // Select some content -> "Lorem |ipsum| dolor sit..."
      await tester.doubleTapInParagraph("1", 8);
      const expectedSelection = DocumentSelection(
        base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 6)),
        extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
      );
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);

      // Press a control key.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);

      // Make sure the content and selection remains the same.
      expect(SuperEditorInspector.findTextInParagraph("1"), initialParagraphText);
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);
    }, variant: inputSourceVariant);
  });
}
