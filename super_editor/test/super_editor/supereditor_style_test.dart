import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnArbitraryDesktop('changes visual text style when attributions change', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleParagraph()
          .pump();

      // Double tap to select the first word.
      await tester.doubleTapInParagraph('1', 0);

      // Apply italic to the word.
      testContext.editContext.commonOps.toggleAttributionsOnSelection({italicsAttribution});
      await tester.pump();

      // Ensure italic was applied.
      expect(
        _findSpanAtOffset(tester, offset: 0).style!.fontStyle,
        FontStyle.italic,
      );
    });
  });
}

InlineSpan _findSpanAtOffset(
  WidgetTester tester, {
  required int offset,
}) {
  final superTextWithSelection = tester.widget<SuperTextWithSelection>(find.byType(SuperTextWithSelection));
  return superTextWithSelection.richText.getSpanForPosition(TextPosition(offset: offset))!;
}
