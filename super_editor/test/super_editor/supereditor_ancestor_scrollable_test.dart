import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';
import 'supereditor_robot.dart';

void main() {
  group('SuperEditor', () {
    group('inside a TabBar', () {
      testWidgetsOnAllPlatforms("doesn't change TabBar index", (tester) async {
        final tabController = TabController(length: 2, vsync: tester);

        await tester
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(DocumentInputSource.ime)
            .withCustomSubtree(
              (superEditor) => ConstrainedBox(
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
            )
            .pump();

        // Ensure SuperEditor added its own Scrollview.
        // If the Scrollview wasn't added, the content will overflow
        // the editor bounds.
        expect(find.byType(SingleChildScrollView), findsOneWidget);

        // Select the editor.
        await tester.placeCaretInParagraph('1', 0);

        // Add new lines so the content will cause editor to scroll
        await _addNewLines(tester, count: 20);

        // Ensure that scrolling didn't cause a tab change
        expect(tabController.index, equals(0));
      });
    });

    group('inside a horizontal ListView', () {
      testWidgetsOnAllPlatforms("doesn't scroll the ListView", (tester) async {
        final scrollController = ScrollController();

        await tester
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(DocumentInputSource.ime)
            .withCustomSubtree(
              (superEditor) => Scaffold(
                body: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 300,
                    maxHeight: 100,
                    maxWidth: 300,
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    controller: scrollController,
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
            )
            .pump();

        // Ensure SuperEditor added its own Scrollview.
        // If the Scrollview wasn't added, the content will overflow
        // the editor bounds.
        expect(find.byType(SingleChildScrollView), findsOneWidget);

        // Select the editor.
        await tester.placeCaretInParagraph('1', 0);

        // Add new lines so the content will cause editor to scroll
        await _addNewLines(tester, count: 20);

        // Ensure that scrolling didn't scroll the ListView
        expect(scrollController.position.pixels, equals(0));
      });
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
