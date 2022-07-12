import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';
import 'supereditor_inspector.dart';

void main() {
  group('SuperEditor gestures', () {
    testWidgetsOnAllPlatforms('places caret at the beginning when tapping at an empty document', (tester) async {
      final testContext = await tester
          .createDocument() //
          .withSingleEmptyParagraph()
          .withEditorSize(const Size(300, 300))
          .pump();

      // Ensure editor is not focused
      expect(SuperEditorInspector.hasFocus(), isFalse);

      // Tap inside SuperEditor
      await tester.tapAt(tester.getCenter(find.byType(SuperEditor)));
      await tester.pump(kTapMinTime);

      // Ensure editor is focused
      expect(SuperEditorInspector.hasFocus(), isTrue);

      // Ensure selection is at the beginning of the document
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: testContext.editContext.editor.document.nodes.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });
  });
}
