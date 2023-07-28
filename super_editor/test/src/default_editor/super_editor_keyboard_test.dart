import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/test_documents.dart';
import 'test_documents.dart';

void main() {
  group('SuperEditor', () {
    group('on any desktop', () {
      group('page scrolling', () {
        // Initial screen dimensions for test document
        const screenSizeForTest = Size(640.0, 120.0);

        void setInitialWindowSize(WidgetTester tester) {
          tester.view
            ..physicalSize = screenSizeForTest
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..devicePixelRatio = 1.0;
        }

        testWidgets('PAGE DOWN does not scroll past bottom of the viewport', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Set the ScrollPosition to the bottom of the scrollable area
          scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset, equals(scrollState.position.maxScrollExtent));
        });

        testWidgets('PAGE DOWN scrolls down by the viewport height', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset, equals(tester.view.physicalSize.height));
        });

        testWidgets('PAGE UP does not scroll past top of the viewport', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset, equals(scrollState.position.minScrollExtent));
        });

        testWidgets('PAGE UP scrolls up by the viewport height', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Set the ScrollPosition to the bottom of the scrollable area
          scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pump();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset,
              equals(scrollState.position.maxScrollExtent - tester.view.physicalSize.height));
        });

        testWidgets('HOME does not scroll past top of the viewport', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          await tester.sendKeyEvent(LogicalKeyboardKey.home);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset, equals(scrollState.position.minScrollExtent));
        });

        testWidgets('HOME scrolls to top of viewport', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Set the ScrollPosition to the bottom of the scrollable area
          scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

          await tester.sendKeyEvent(LogicalKeyboardKey.home);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset, equals(scrollState.position.minScrollExtent));
        });

        testWidgets('END does not scroll past bottom of the viewport', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Set the ScrollPosition to the bottom of the scrollable area
          scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

          await tester.sendKeyEvent(LogicalKeyboardKey.end);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset, equals(scrollState.position.maxScrollExtent));
        });

        testWidgets('END scrolls to bottom of viewport', (tester) async {
          setInitialWindowSize(tester);

          await tester.pumpWidget(_buildDocumentMultipleParagraphs());

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          await tester.sendKeyEvent(LogicalKeyboardKey.end);

          // Let the scrolling system auto-scroll, as desired.
          await tester.pumpAndSettle();

          // Ensure that the scroll position is set to the expected position
          // after the key press action.
          expect(scrollState.widget.controller!.offset, equals(scrollState.position.maxScrollExtent));
        });
      });
    });
  });
}

Widget _buildDocumentMultipleParagraphs() {
  final doc = multipleParagraphDoc();
  final composer = MutableDocumentComposer(
    initialSelection: const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: '1',
        nodePosition: TextNodePosition(offset: 0),
      ),
    ),
  );
  final docEditor = createDefaultDocumentEditor(document: doc, composer: composer);
  return MaterialApp(
    home: Scaffold(
      body: SuperEditor(
        scrollController: ScrollController(),
        document: doc,
        editor: docEditor,
        inputSource: TextInputSource.ime,
        focusNode: FocusNode(),
        composer: composer,
        keyboardActions: defaultImeKeyboardActions,
        autofocus: true,
      ),
    ),
  );
}
