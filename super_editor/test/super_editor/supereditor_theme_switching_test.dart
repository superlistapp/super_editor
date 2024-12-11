import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'test_documents.dart';

void main() {
  group('SuperEditor > theme switching', () {
    testWidgetsOnArbitraryDesktop('switches caret color', (tester) async {
      final brightnessNotifier = ValueNotifier<Brightness>(Brightness.light);

      await _pumpThemeSwitchingTestApp(tester, brightnessNotifier: brightnessNotifier);

      // Place the caret at the beginning of the paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Ensure the caret is green, because the theme is light.
      expect(_findDesktopCaretColor(tester), Colors.green.shade500);

      // Switch the theme to dark.
      brightnessNotifier.value = Brightness.dark;
      await tester.pumpAndSettle();

      // Ensure the caret is red, because the theme is dark.
      expect(_findDesktopCaretColor(tester), Colors.red.shade500);
    });

    testWidgetsOnArbitraryDesktop('switches caret color after typing', (tester) async {
      final brightnessNotifier = ValueNotifier<Brightness>(Brightness.light);

      await _pumpThemeSwitchingTestApp(tester, brightnessNotifier: brightnessNotifier);

      // Place the caret at the beginning of the paragraph.
      await tester.placeCaretInParagraph('1', 0);

      // Ensure the caret is green, because the theme is light.
      expect(_findDesktopCaretColor(tester), Colors.green.shade500);

      // Switch the theme to dark.
      brightnessNotifier.value = Brightness.dark;
      await tester.pumpAndSettle();

      // Type a character to trigger a re-layout.
      await tester.typeImeText('a');

      // Ensure the caret is red, because the theme is dark.
      expect(_findDesktopCaretColor(tester), Colors.red.shade500);
    });
  });
}

/// Pumps a widget tree that rebuilds when the [brightnessNotifier] changes.
///
/// The widget tree contains a [SuperEditor] with a custom caret overlay that
/// changes color based on the brightness of the theme.
Future<void> _pumpThemeSwitchingTestApp(
  WidgetTester tester, {
  required ValueNotifier<Brightness> brightnessNotifier,
}) async {
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(
    document: singleParagraphDoc(),
    composer: composer,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: brightnessNotifier,
          builder: (context, brightness, child) {
            return Theme(
              data: ThemeData(
                brightness: brightness,
              ),
              child: SuperEditor(
                editor: editor,
                documentOverlayBuilders: [
                  // Copy all default overlay builders except the caret overlay builder.
                  ...defaultSuperEditorDocumentOverlayBuilders.where(
                    (builder) => builder is! DefaultCaretOverlayBuilder,
                  ),
                  DefaultCaretOverlayBuilder(
                    caretStyle: CaretStyle(
                      color: brightness == Brightness.light ? Colors.green : Colors.red,
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

Color _findDesktopCaretColor(WidgetTester tester) {
  final caret = tester.widget<Container>(find.byKey(DocumentKeys.caret));
  return (caret.decoration as BoxDecoration).color!;
}
