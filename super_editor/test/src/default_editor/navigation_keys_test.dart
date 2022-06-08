import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'test_documents.dart';

void main() {
  group('Keyboard based navigation', () {
    group('Page navigation keys', () {
      testWidgets('pageDown key press at bottom of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        // Set the ScollPostion to the bottom of the scrollable area
        scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(scrollState.position.maxScrollExtent));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });

      testWidgets('pageDown key press at top of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(screenHeight));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });

      testWidgets('pageUp key press at top of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(scrollState.position.minScrollExtent));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });

      testWidgets('pageUp key press at bottom of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        // Set the ScollPostion to the bottom of the scrollable area
        scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(scrollState.position.maxScrollExtent - screenHeight));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });

      testWidgets('home key press at top of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        await tester.sendKeyEvent(LogicalKeyboardKey.home);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(scrollState.position.minScrollExtent));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });

      testWidgets('home key press at bottom of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        // Set the ScollPostion to the bottom of the scrollable area
        scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

        await tester.sendKeyEvent(LogicalKeyboardKey.home);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(scrollState.position.minScrollExtent));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });

      testWidgets('end key press at bottom of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        // Set the ScollPostion to the bottom of the scrollable area
        scrollState.widget.controller!.jumpTo(scrollState.position.maxScrollExtent);

        await tester.sendKeyEvent(LogicalKeyboardKey.end);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(scrollState.position.maxScrollExtent));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });

      testWidgets('end key press at top of viewport', (tester) async {
        await _pumpDocumentLayout(tester);

        final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

        await tester.sendKeyEvent(LogicalKeyboardKey.end);

        // Let the scrolling system auto-scroll, as desired.
        await tester.pumpAndSettle();

        // Ensure that the scroll position is set to the expected position
        // after the key press action.
        expect(scrollState.widget.controller!.offset, equals(scrollState.position.maxScrollExtent));

        // Ensure that the caret has not move during the key press action.
        expect(textNodePosition.offset, equals(0));
      });
    });
  });
}

// Initial screen dimensions for test document
const double screenWidth = 640.0;
const double screenHeight = 120.0;

final composer = DocumentComposer(
  initialSelection: const DocumentSelection.collapsed(
    position: DocumentPosition(
      nodeId: '1',
      nodePosition: TextNodePosition(offset: 0),
    ),
  ),
);

TextNodePosition get textNodePosition => composer.selection!.extent.nodePosition as TextNodePosition;

Future<void> _pumpDocumentLayout(WidgetTester tester) async {
  tester.binding.window
    ..physicalSizeTestValue = const Size(screenWidth, screenHeight)
    ..platformDispatcher.textScaleFactorTestValue = 1.0
    ..devicePixelRatioTestValue = 1.0;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          scrollController: ScrollController(),
          editor: DocumentEditor(document: multipleParagraphDoc()),
          inputSource: DocumentInputSource.keyboard,
          focusNode: FocusNode()..requestFocus(),
          composer: composer,
          autofocus: true,
        ),
      ),
    ),
  );
}
