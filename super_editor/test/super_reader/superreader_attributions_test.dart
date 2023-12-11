import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../super_editor/test_documents.dart';
import '../super_textfield/super_textfield_inspector.dart';
import 'reader_test_tools.dart';

void main() {
  group("SuperReader", () {
    group("applies color attributions", () {
      testWidgetsOnAllPlatforms("to full text", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              singleParagraphFullColor(),
            )
            .pump();

        // Ensure the text is colored orange.
        expect(
          SuperTextFieldInspector.findRichText().style!.color,
          Colors.orange,
        );
      });

      testWidgetsOnAllPlatforms("to partial text", (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              singleParagraphWithPartialColor(),
            )
            .pump();

        // Ensure the first span is colored black.
        expect(
          SuperTextFieldInspector.findRichText().getSpanForPosition(const TextPosition(offset: 0))!.style!.color,
          Colors.black,
        );

        // Ensure the second span is colored orange.
        expect(
          SuperTextFieldInspector.findRichText().getSpanForPosition(const TextPosition(offset: 5))!.style!.color,
          Colors.orange,
        );
      });
    });
  });
}
