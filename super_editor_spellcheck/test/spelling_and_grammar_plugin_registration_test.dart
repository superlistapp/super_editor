import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

void main() {
  group("Spelling and grammar plugin > registration >", () {
    testWidgets("handles replacement of one Editor with another", (tester) async {
      // Create Editor and SpellingAndGrammarPlugin explicitly, so that we can be
      // sure about which instance is being used in a pump.
      var editor = createDefaultDocumentEditor(
        document: MutableDocument.empty(),
        composer: MutableDocumentComposer(),
      );
      final plugin = SpellingAndGrammarPlugin(
        androidControlsController: SuperEditorAndroidControlsController(),
      );

      // Pump the initial UI.
      await _pumpScaffold(tester, editor: editor, plugin: plugin);

      // Let things settle. We don't really care what's happening here.
      await tester.pumpAndSettle();

      // Replace the original Editor with a new one, which simulates something
      // like one document being replaced by another document in the same UI.
      editor = createDefaultDocumentEditor(
        document: MutableDocument.empty(),
        composer: MutableDocumentComposer(),
      );
      await _pumpScaffold(tester, editor: editor, plugin: plugin);

      // Let things settle. We don't really care what's happening here.
      await tester.pumpAndSettle();

      // If we got here without an error, it means that the `Editor` and the `EditContext`
      // were replaced without generating any errors in the `SpellingAndGrammarPlugin`.
    });
  });
}

Future<Editor> _pumpScaffold(
  WidgetTester tester, {
  Editor? editor,
  SpellingAndGrammarPlugin? plugin,
}) async {
  editor ??= createDefaultDocumentEditor(
    document: MutableDocument.empty(),
    composer: MutableDocumentComposer(),
  );

  plugin ??= SpellingAndGrammarPlugin();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          plugins: {plugin},
        ),
      ),
    ),
  );

  return editor;
}
