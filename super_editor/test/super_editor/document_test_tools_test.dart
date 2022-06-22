import 'package:flutter_test/flutter_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';
import 'supereditor_inspector.dart';

void main() {
  group("SuperEditor test tools", () {
    group("configures document from markdown", () {
      testWidgetsOnMac("when the document is empty", (tester) async {
        await tester //
            .createDocument() //
            .fromMarkdown("") //
            .forDesktop() //
            .pump();

        expect(
          SuperEditorInspector.findDocument(),
          equalsMarkdown(""),
        );
      });

      testWidgetsOnMac("when the document has a single paragraph", (tester) async {
        await tester //
            .createDocument() //
            .fromMarkdown("Hello, **world!**") //
            .forDesktop() //
            .pump();

        expect(
          SuperEditorInspector.findDocument()!,
          equalsMarkdown("Hello, **world!**"),
        );
      });

      testWidgetsOnMac("when the document has multiple paragraphs", (tester) async {
        await tester //
            .createDocument() //
            .fromMarkdown('''This is **paragraph 1**.
This is *paragraph 2*.
This is [paragraph 3](https://flutter.dev).''') //
            .forDesktop() //
            .pump();

        expect(
          SuperEditorInspector.findDocument()!,
          equalsMarkdown('''This is **paragraph 1**.
This is *paragraph 2*.
This is [paragraph 3](https://flutter.dev).'''),
        );
      });
    });
  });
}
