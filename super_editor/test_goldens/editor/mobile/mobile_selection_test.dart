import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

void main() {
  group('SuperEditor', () {
    group('mobile selection', () {
      group('Android', () {
        testParagraphSelection('single tap text', (tester, docKey) async {
          final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
          final docLayout = docKey.currentState as DocumentLayout;
          final characterBox = docLayout.getRectForPosition(
            const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
          );

          await tester.tapAt(
            docBox.localToGlobal(characterBox!.center),
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(tester, "mobile-selection_android_single-tap-text");
        });

        testParagraphSelection('double tap text', (tester, docKey) async {
          final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
          final docLayout = docKey.currentState as DocumentLayout;
          final characterBox = docLayout.getRectForPosition(
            const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
          );

          await tester.tapAt(
            docBox.localToGlobal(characterBox!.center),
          );
          await tester.pump(kDoubleTapMinTime);
          await tester.tapAt(
            docBox.localToGlobal(characterBox.center),
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(tester, "mobile-selection_android_double-tap-text");
        });

        testParagraphSelection('triple tap text', (tester, docKey) async {
          final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
          final docLayout = docKey.currentState as DocumentLayout;
          final characterBox = docLayout.getRectForPosition(
            const DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 34)),
          );

          await tester.tapAt(
            docBox.localToGlobal(characterBox!.center),
          );
          await tester.pump(kDoubleTapMinTime);
          await tester.tapAt(
            docBox.localToGlobal(characterBox.center),
          );
          await tester.pump(kDoubleTapMinTime);
          await tester.tapAt(
            docBox.localToGlobal(characterBox.center),
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(tester, "mobile-selection_android_trip-tap-text");
        });
      });
    });
  });
}

/// Pumps a single-paragraph document into the WidgetTester and then hands control
/// to the given [test] method.
void testParagraphSelection(String description, Future<void> Function(WidgetTester, GlobalKey docKey) test) {
  final docKey = GlobalKey();

  testGoldens(description, (tester) async {
    tester.binding.window
      ..physicalSizeTestValue = const Size(800, 200)
      ..textScaleFactorTestValue = 1.0
      ..devicePixelRatioTestValue = 1.0;

    await tester.pumpWidget(
      _buildScaffold(
        child: SuperEditor(
          documentLayoutKey: docKey,
          editor: _createSingleParagraphEditor(),
          gestureMode: DocumentGestureMode.touch,
          textStyleBuilder: _textStyleBuilder,
        ),
      ),
    );

    await test(tester, docKey);

    tester.binding.window.clearPhysicalSizeTestValue();
  });
}

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: IntrinsicHeight(
          child: child,
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  );
}

TextStyle _textStyleBuilder(attributions) {
  return const TextStyle(
    color: Colors.black,
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 1.4,
  );
}

DocumentEditor _createSingleParagraphEditor() {
  return DocumentEditor(document: _createSingleParagraphDoc());
}

MutableDocument _createSingleParagraphDoc() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText(
          text:
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        ),
      ),
    ],
  );
}
