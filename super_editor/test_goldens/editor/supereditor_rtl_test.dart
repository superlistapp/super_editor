import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/src/test/ime.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

import '../../test/super_editor/supereditor_test_tools.dart';
import '../test_tools_goldens.dart';

void main() {
  group('SuperEditor > RTL mode >', () {
    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of paragraph',
      (tester) async {
        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the paragraph.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example of text containing multiple lines.".
        await tester.ime.typeText(
          'مثال لنص يحتوي على عدة أسطر.',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(tester, 'super-editor-rtl-caret-paragraph-${defaultTargetPlatform.name}');
      },
      windowSize: const Size(800, 500),
    );

    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of unordered list item',
      (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ListItemNode.unordered(id: '1', text: AttributedText()),
                ],
              ),
            )
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the list item.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example of text containing multiple lines.".
        await tester.ime.typeText(
          'مثال لنص يحتوي على عدة أسطر.',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(tester, 'super-editor-rtl-caret-unordered-list-item-${defaultTargetPlatform.name}');
      },
      windowSize: const Size(800, 500),
    );

    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of ordered list item',
      (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  ListItemNode.ordered(id: '1', text: AttributedText()),
                ],
              ),
            )
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the list item.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example of text containing multiple lines.".
        await tester.ime.typeText(
          'مثال لنص يحتوي على عدة أسطر.',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(tester, 'super-editor-rtl-caret-ordered-list-item-${defaultTargetPlatform.name}');
      },
      windowSize: const Size(800, 500),
    );

    testGoldensOnAllPlatforms(
      'inserts text and paints caret on the left side of task',
      (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  TaskNode(id: '1', text: AttributedText(), isComplete: false),
                ],
              ),
            )
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place the caret at the beginning of the task.
        await tester.placeCaretInParagraph('1', 0);

        // Type the text "Example of text containing multiple lines.".
        await tester.ime.typeText(
          'مثال لنص يحتوي على عدة أسطر.',
          getter: imeClientGetter,
        );

        await screenMatchesGolden(tester, 'super-editor-rtl-caret-task-${defaultTargetPlatform.name}');
      },
      windowSize: const Size(800, 500),
    );
  });
}
