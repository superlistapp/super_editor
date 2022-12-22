import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor respects horizontal scrolling', () {
    testWidgetsOnAllPlatforms('inside a TabBar', (tester) async {
      final tabController = TabController(length: 2, vsync: tester);
      final scrollController = ScrollController();

      // Pump a SuperEditor with a small maxHeight, so adding lines
      // will cause the editor to scroll.
      await tester
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .withScrollController(scrollController)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 300,
                  maxHeight: 100,
                ),
                child: Scaffold(
                  appBar: AppBar(
                    bottom: TabBar(
                      controller: tabController,
                      tabs: const [
                        Tab(text: 'Tab 1'),
                        Tab(text: 'Tab 2'),
                      ],
                    ),
                  ),
                  body: TabBarView(
                    controller: tabController,
                    children: [
                      superEditor,
                      const SizedBox(),
                    ],
                  ),
                ),
              ),
            ),
          )
          .pump();

      // Select the editor.
      await tester.placeCaretInParagraph('1', 0);

      // Add new lines so the content will cause editor to scroll
      await _addNewLines(tester, count: 40);
      await tester.pumpAndSettle();

      // Ensure SuperEditor has scrolled
      expect(scrollController.offset, greaterThan(0));

      // Ensure that scrolling didn't cause a tab change
      expect(tabController.index, equals(0));
    });

    testWidgetsOnAllPlatforms('inside a horizontal ListView', (tester) async {
      final listScrollController = ScrollController();
      final editorScrollController = ScrollController();

      // Pump a SuperEditor with a small maxHeight, so adding lines
      // will cause the editor to scroll.
      await tester
          .createDocument()
          .withSingleEmptyParagraph()
          .withInputSource(TextInputSource.ime)
          .withScrollController(editorScrollController)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 300,
                    maxHeight: 100,
                    maxWidth: 300,
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    controller: listScrollController,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: superEditor,
                      ),
                      ...List.generate(20, (index) => Text('Text $index')),
                    ],
                  ),
                ),
              ),
            ),
          )
          .pump();

      // Select the editor.
      await tester.placeCaretInParagraph('1', 0);

      // Add new lines so the content will cause editor to scroll
      await _addNewLines(tester, count: 40);
      await tester.pumpAndSettle();

      // Ensure SuperEditor has scrolled
      expect(editorScrollController.offset, greaterThan(0));

      // Ensure that scrolling didn't scroll the ListView
      expect(listScrollController.position.pixels, equals(0));
    });
  });
}

/// Adds [count] new lines using IME actions
Future<void> _addNewLines(
  WidgetTester tester, {
  required int count,
}) async {
  for (int i = 0; i < count; i++) {
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
  }
}
