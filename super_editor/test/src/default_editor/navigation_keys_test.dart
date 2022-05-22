import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('Navigation Keys', () {
    group('navigation', () {
      double pageHeight = 120.0;

      double _realOffset(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

      void _setScreensize(WidgetTester tester) {
        final screenSizeWithoutKeyboard = Size(640.0, pageHeight);

        tester.binding.window
          ..physicalSizeTestValue = screenSizeWithoutKeyboard
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..devicePixelRatioTestValue = 1.0;
      }

      Future<void> _testTopExtent(WidgetTester tester, LogicalKeyboardKey key) async {
        _setScreensize(tester);

        final scrollController = ScrollController();

        final composer = _testComposer();

        await _buildDoc(tester, scrollController: scrollController, documentComposer: composer);

        final extentTop = scrollController.position.minScrollExtent;

        //get caret offset
        var textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret is at begining of doc
        expect(textNodePosition.offset == 0, true);

        //confirm start from top of viewport
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //activate pageUp key
        await tester.sendKeyEvent(key);

        await tester.pumpAndSettle();

        //confirm no scroll beyond bottom
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //caret should not move
        expect(textNodePosition.offset == 0, true);

        //get caret offset
        textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret hasn't moved
        expect(textNodePosition.offset == 0, true);
      }

      Future<void> _testBottomExtent(WidgetTester tester, LogicalKeyboardKey key) async {
        _setScreensize(tester);

        final scrollController = ScrollController();

        final composer = _testComposer();

        await _buildDoc(tester, scrollController: scrollController, documentComposer: composer);

        final extentTop = scrollController.position.minScrollExtent;

        final extentBottom = scrollController.position.maxScrollExtent;

        //get caret offset
        var textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret is at begining of doc
        expect(textNodePosition.offset == 0, true);

        //confirm start from top of viewport
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //scroll to bottom of doc
        scrollController.jumpTo(extentBottom);

        //check for scroll to bottom
        expect(scrollController.offset, equals(extentBottom));

        expect(_realOffset(tester), equals(scrollController.offset));

        //activate pageDown key
        await tester.sendKeyEvent(key);

        await tester.pumpAndSettle();

        //confirm no scroll beyond bottom
        expect(scrollController.offset, equals(extentBottom));

        expect(_realOffset(tester), equals(scrollController.offset));

        //caret should not move
        expect(textNodePosition.offset == 0, true);

        //get caret offset
        textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret hasn't moved
        expect(textNodePosition.offset == 0, true);
      }

      testWidgets('pageDown key press at bottom of viewport',
          (tester) async => _testBottomExtent(tester, LogicalKeyboardKey.pageDown));

      testWidgets('pageDown key press at top of viewport', (tester) async {
        _setScreensize(tester);

        final scrollController = ScrollController();

        final composer = _testComposer();

        await _buildDoc(tester, scrollController: scrollController, documentComposer: composer);

        //get caret offset
        final extentTop = scrollController.position.minScrollExtent;

        var textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret is at begining of doc
        expect(textNodePosition.offset == 0, true);

        //confirm start at top of viewport
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //activate pageDown key
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

        await tester.pumpAndSettle();

        //confirm no scroll beyond bottom
        expect(scrollController.offset, equals(pageHeight));

        expect(_realOffset(tester), equals(scrollController.offset));

        //caret should not move
        expect(textNodePosition.offset == 0, true);

        //get caret offset
        textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret hasn't moved
        expect(textNodePosition.offset == 0, true);
      });

      testWidgets(
          'pageUp key press at top of viewport', (tester) async => _testTopExtent(tester, LogicalKeyboardKey.pageUp));

      testWidgets('pageUp key press at bottom of viewport', (tester) async {
        _setScreensize(tester);

        final scrollController = ScrollController();

        final composer = _testComposer();

        await _buildDoc(tester, scrollController: scrollController, documentComposer: composer);

        final extentTop = scrollController.position.minScrollExtent;

        final extentBottom = scrollController.position.maxScrollExtent;

        //get caret offset
        var textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret is at begining of doc
        expect(textNodePosition.offset == 0, true);

        //confirm start from top of viewport
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //scroll to bottom of doc
        scrollController.jumpTo(extentBottom);

        //check for scroll to bottom
        expect(scrollController.offset, equals(extentBottom));

        expect(_realOffset(tester), equals(scrollController.offset));

        //activate pageUp key
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);

        await tester.pumpAndSettle();

        //confirm scroll up one page
        expect(scrollController.offset, equals(extentBottom - pageHeight));

        expect(_realOffset(tester), equals(scrollController.offset));

        //caret should not move
        expect(textNodePosition.offset == 0, true);

        //get caret offset
        textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret hasn't moved
        expect(textNodePosition.offset == 0, true);
      });

      testWidgets(
          'home key press at top of viewport', (tester) async => _testTopExtent(tester, LogicalKeyboardKey.home));

      testWidgets('home key press at bottom of viewport', (tester) async {
        _setScreensize(tester);

        final scrollController = ScrollController();

        final composer = _testComposer();

        await _buildDoc(tester, scrollController: scrollController, documentComposer: composer);

        final extentTop = scrollController.position.minScrollExtent;

        final extentBottom = scrollController.position.maxScrollExtent;

        //get caret offset
        var textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret is at begining of doc
        expect(textNodePosition.offset == 0, true);

        //confirm start from top of viewport
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //scroll to bottom of doc
        scrollController.jumpTo(extentBottom);

        //check for scroll to bottom
        expect(scrollController.offset, equals(extentBottom));

        expect(_realOffset(tester), equals(scrollController.offset));

        //activate home key
        await tester.sendKeyEvent(LogicalKeyboardKey.home);

        await tester.pumpAndSettle();

        //confirm scroll to top of page
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //caret should not move
        expect(textNodePosition.offset == 0, true);

        //get caret offset
        textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret hasn't moved
        expect(textNodePosition.offset == 0, true);
      });

      testWidgets(
          'end key press at end of viewport', (tester) async => _testBottomExtent(tester, LogicalKeyboardKey.end));

      testWidgets('end key press at top of viewport', (tester) async {
        _setScreensize(tester);

        final scrollController = ScrollController();

        final composer = _testComposer();

        await _buildDoc(tester, scrollController: scrollController, documentComposer: composer);

        //get caret offset
        final extentTop = scrollController.position.minScrollExtent;

        final extentBottom = scrollController.position.maxScrollExtent;

        var textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret is at begining of doc
        expect(textNodePosition.offset == 0, true);

        //confirm start at top of viewport
        expect(scrollController.offset, equals(extentTop));

        expect(_realOffset(tester), equals(scrollController.offset));

        //activate pageDown key
        await tester.sendKeyEvent(LogicalKeyboardKey.end);

        await tester.pumpAndSettle();

        //confirm no scroll beyond bottom
        expect(scrollController.offset, equals(extentBottom));

        expect(_realOffset(tester), equals(scrollController.offset));

        //caret should not move
        expect(textNodePosition.offset == 0, true);

        //get caret offset
        textNodePosition = composer.selection!.extent.nodePosition as TextNodePosition;

        //caret hasn't moved
        expect(textNodePosition.offset == 0, true);
      });
    });
  });
}

DocumentComposer _testComposer() => DocumentComposer(
      initialSelection: const DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: '1',
          nodePosition: TextNodePosition(offset: 0),
        ),
      ),
    );

Future<void> _buildDoc(WidgetTester tester,
    {required ScrollController scrollController, required DocumentComposer documentComposer}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          scrollController: scrollController,
          editor: DocumentEditor(
              document: MutableDocument(
            nodes: [
              ParagraphNode(
                  id: '1',
                  text: AttributedText(
                      text:
                          '1. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.')),
              ParagraphNode(
                  id: '2',
                  text: AttributedText(
                      text:
                          '2. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.')),
            ],
          )),
          inputSource: DocumentInputSource.keyboard,
          focusNode: FocusNode()..requestFocus(),
          composer: documentComposer,
          autofocus: true,
        ),
      ),
    ),
  );
}
