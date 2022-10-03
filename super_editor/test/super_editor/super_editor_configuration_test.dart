import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnAndroid('configures default gesture mode (on Android)', (tester) async {
      final toolbarKey = GlobalKey();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withAndroidToolbarBuilder((_) => SizedBox(key: toolbarKey))
          .pump();

      // Double tap to show the toolbar.
      await tester.doubleTapInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 0);

      // Ensure the toolbar is displayed.
      expect(find.byKey(toolbarKey), findsOneWidget);
    });

    testWidgetsOnIos('configures default gesture mode (on iOS)', (tester) async {
      final toolbarKey = GlobalKey();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withiOSToolbarBuilder((_) => SizedBox(key: toolbarKey))
          .pump();

      // Double tap to show the toolbar.
      await tester.doubleTapInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 0);

      // Ensure the toolbar is displayed.
      expect(find.byKey(toolbarKey), findsOneWidget);
    });

    testWidgetsOnDesktop('configures default gesture mode', (tester) async {
      final androidToolbarKey = GlobalKey();
      final iOSToolbarKey = GlobalKey();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withAndroidToolbarBuilder((_) => SizedBox(key: androidToolbarKey))
          .withiOSToolbarBuilder((_) => SizedBox(key: iOSToolbarKey))
          .pump();

      await tester.doubleTapInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 0);

      // Ensure no toolbar is displayed.
      expect(find.byKey(androidToolbarKey), findsNothing);
      expect(find.byKey(iOSToolbarKey), findsNothing);
    });
  });
}
