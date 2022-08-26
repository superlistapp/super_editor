import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("SuperEditor mobile drag handles", () {
    testWidgetsOnAndroid("with caret change colors (on Android)", (tester) async {
      final testContext = await tester //
          .createDocument() //
          .fromMarkdown("This is some text to select.") //
          .useAppTheme(ThemeData(primaryColor: Colors.red)) //
          .pump();
      final nodeId = testContext.editContext.editor.document.nodes.first.id;

      await tester.placeCaretInParagraph(nodeId, 15);

      expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile("goldens/mobile/supereditor_android_collapsed_handle_color.png"),
      );
    });

    testWidgetsOnAndroid("with selection change colors (on Android)", (tester) async {
      final testContext = await tester //
          .createDocument() //
          .fromMarkdown("This is some text to select.") //
          .useAppTheme(ThemeData(primaryColor: Colors.red)) //
          .pump();
      final nodeId = testContext.editContext.editor.document.nodes.first.id;

      await tester.doubleTapInParagraph(nodeId, 15);

      expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile("goldens/mobile/supereditor_android_expanded_handle_color.png"),
      );
    });

    testWidgetsOnIos("with caret change colors (on iOS)", (tester) async {
      final testContext = await tester //
          .createDocument() //
          .fromMarkdown("This is some text to select.") //
          .useAppTheme(ThemeData(primaryColor: Colors.red)) //
          .pump();
      final nodeId = testContext.editContext.editor.document.nodes.first.id;

      await tester.placeCaretInParagraph(nodeId, 15);

      expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile("goldens/mobile/supereditor_ios_collapsed_handle_color.png"),
      );
    });

    testWidgetsOnIos("with selection change colors (on iOS)", (tester) async {
      final testContext = await tester //
          .createDocument() //
          .fromMarkdown("This is some text to select.") //
          .useAppTheme(ThemeData(primaryColor: Colors.red)) //
          .pump();
      final nodeId = testContext.editContext.editor.document.nodes.first.id;

      await tester.doubleTapInParagraph(nodeId, 15);

      expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile("goldens/mobile/supereditor_ios_expanded_handle_color.png"),
      );
    });
  });
}
