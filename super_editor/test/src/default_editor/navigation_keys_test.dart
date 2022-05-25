import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

enum Extent { top, bottom, pgDown, pgUp }

enum ScrollTo { bottom }

void main() {
  group('Navigation Keys', () {
    double screenWidth = 640.0;

    double screenHeight = 120.0;

    Future<void> _testExtent(WidgetTester tester, Extent extent,
        {required LogicalKeyboardKey key, bool scrollToBottom = false}) async {
      final testDocument = TestDocument(tester, screenWidth: screenWidth, screenHeight: screenHeight);

      await testDocument.buildDoc(tester);

      //caret is at begining of doc
      expect(testDocument.textNodePosition.offset == 0, true);

      if (scrollToBottom) {
        testDocument.scrollController.jumpTo(testDocument.extentBottom);
      }

      //activate key press
      await tester.sendKeyEvent(key);

      await tester.pumpAndSettle();

      final offset = testDocument.scrollController.offset;

      switch (extent) {
        case Extent.top:
          //confirm no scroll beyond top
          expect(offset, equals(testDocument.extentTop));
          break;

        case Extent.bottom:
          //confirm no scroll beyond bottom
          expect(offset, equals(testDocument.extentBottom));
          break;

        case Extent.pgDown:
          //confirm scroll down by screenHeight
          expect(offset, equals(screenHeight));
          break;

        case Extent.pgUp:
          //confirm scroll up one page
          expect(offset, equals(testDocument.extentBottom - screenHeight));
          break;
      }

      //caret should not move
      expect(testDocument.textNodePosition.offset == 0, true);
    }

    group('navigation', () {
      testWidgets('pageDown key press at bottom of viewport',
          (tester) async => _testExtent(tester, Extent.bottom, key: LogicalKeyboardKey.pageDown, scrollToBottom: true));

      testWidgets(
          'pageDown key press at top of viewport',
          (tester) async => _testExtent(
                tester,
                Extent.pgDown,
                key: LogicalKeyboardKey.pageDown,
              ));

      testWidgets('pageUp key press at top of viewport',
          (tester) async => _testExtent(tester, Extent.top, key: LogicalKeyboardKey.pageUp));

      testWidgets('pageUp key press at bottom of viewport',
          (tester) async => _testExtent(tester, Extent.pgUp, key: LogicalKeyboardKey.pageUp, scrollToBottom: true));

      testWidgets('home key press at top of viewport',
          (tester) async => _testExtent(tester, Extent.top, key: LogicalKeyboardKey.home));

      testWidgets('home key press at bottom of viewport',
          (tester) async => _testExtent(tester, Extent.top, key: LogicalKeyboardKey.home, scrollToBottom: true));

      testWidgets('end key press at bottom of viewport',
          (tester) async => _testExtent(tester, Extent.bottom, key: LogicalKeyboardKey.end, scrollToBottom: true));

      testWidgets(
          'end key press at top of viewport',
          (tester) async => _testExtent(
                tester,
                Extent.bottom,
                key: LogicalKeyboardKey.end,
              ));
    });
  });
}

class TestDocument {
  final WidgetTester tester;

  final double screenWidth;

  final double screenHeight;

  final scrollController = ScrollController();

  final composer = DocumentComposer(
    initialSelection: const DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: '1',
        nodePosition: TextNodePosition(offset: 0),
      ),
    ),
  );

  //get caret offset
  TextNodePosition get textNodePosition => composer.selection!.extent.nodePosition as TextNodePosition;

  double get extentTop => scrollController.position.minScrollExtent;

  double get extentBottom => scrollController.position.maxScrollExtent;

  TestDocument(this.tester, {required this.screenWidth, required this.screenHeight}) {
    tester.binding.window
      ..physicalSizeTestValue = Size(screenWidth, screenHeight)
      ..platformDispatcher.textScaleFactorTestValue = 1.0
      ..devicePixelRatioTestValue = 1.0;
  }

  Future<void> buildDoc(WidgetTester tester) async {
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
            composer: composer,
            autofocus: true,
          ),
        ),
      ),
    );
  }
}
