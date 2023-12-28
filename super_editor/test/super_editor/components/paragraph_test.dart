import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';

import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor > Paragraph Component >", () {
    testWidgetsOnAllPlatforms("visually updates alignment immediately after it is changed", (tester) async {
      final editorContext = await tester //
          .createDocument()
          .withSingleParagraph()
          .pump();

      // Ensure that we begin with a visually left-aligned paragraph widget.
      var paragraphComponent = find.byType(TextComponent).evaluate().first.widget as TextComponent;
      expect(paragraphComponent.textAlign, TextAlign.left);

      // Change the paragraph to right-alignment.
      editorContext.editor.execute([
        ChangeParagraphAlignmentRequest(nodeId: "1", alignment: TextAlign.right),
      ]);
      await tester.pump();

      // Ensure that the paragraph's associated widget is now right-aligned.
      //
      // This is as close as we can get to verifying visual text alignment without either
      // inspecting the render object, or generating a golden file.
      paragraphComponent = find.byType(TextComponent).evaluate().first.widget as TextComponent;
      expect(paragraphComponent.textAlign, TextAlign.right);
    });
  });
}
