import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperEditor', () {
    testWidgetsOnAllPlatforms('can layout with shrinkwrap in a column', (tester) async {
      final composer = MutableDocumentComposer();
      final docEditor = createDefaultDocumentEditor(
        document: MutableDocument.empty(),
        composer: composer,
      );
      // This must not fail with infinite height constraints.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SuperEditor(
                editor: docEditor,
                shrinkWrap: true,
              ),
            ],
          ),
        ),
      ));
    });
  });
}
