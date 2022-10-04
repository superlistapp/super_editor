import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';
import 'test_documents.dart';

/// This test suite illustrates the difference between interacting with
/// selectable non-text nodes and un-selectable non-text nodes.
///
/// Consider horizontal rules.
///
/// An editor might make HRs selectable so that the user can tap them, select
/// them with the keyboard, and delete them when selected.
///
/// Other editors (like Medium) might make HRs un-selectable. When the user
/// taps on an HR, it doesn't become selected. When the user presses arrow
/// keys that would ordinarily select an HR, the selection behaves as if
/// the HR isn't there.
void main() {
  group("Selectable component", () {
    testWidgetsOnDesktop("accepts selection when caret moves down from upstream node", (tester) async {
      await _pumpEditorWithSelectableHrs(tester);
      await tester.placeCaretInParagraph("1", 37);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("accepts selection when selection expands down from upstream node", (tester) async {
      await _pumpEditorWithSelectableHrs(tester);
      await tester.placeCaretInParagraph("1", 37);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection(
          base: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 37, affinity: TextAffinity.upstream),
          ),
          extent: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("accepts selection when caret moves up from downstream node", (tester) async {
      await _pumpEditorWithSelectableHrs(tester);
      await tester.placeCaretInParagraph("3", 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.upstream(),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("accepts selection when selection expands up from downstream node", (tester) async {
      await _pumpEditorWithSelectableHrs(tester);
      await tester.placeCaretInParagraph("3", 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection(
          base: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.upstream(),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("accepts selection when user taps on it", (tester) async {
      await _pumpEditorWithSelectableHrs(tester);

      await tester.tapAtDocumentPosition(
        const DocumentPosition(
          nodeId: "2",
          nodePosition: UpstreamDownstreamNodePosition.upstream(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.upstream(),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("moves selection to next node when delete pressed from upstream", (tester) async {
      await _pumpEditorWithSelectableHrs(tester);
      await tester.placeCaretInParagraph("1", 37);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.upstream(),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("moves selection to previous node when backspace pressed from downstream", (tester) async {
      await _pumpEditorWithSelectableHrs(tester);
      await tester.placeCaretInParagraph("3", 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
      );
    });
  });

  group("Unselectable component", () {
    testWidgetsOnDesktop("skips node when down arrow moves caret down from upstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);
      await tester.placeCaretInParagraph("1", 37);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 37, affinity: TextAffinity.upstream),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("skips node when right arrow moves caret down from upstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);
      await tester.placeCaretInParagraph("1", 37);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgetsOnDesktop("rejects selection when down arrow moves caret down from upstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester, customDocument: paragraphThenHrDoc());
      await tester.placeCaretInParagraph("1", 11);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
    });

    testWidgetsOnDesktop("rejects selection when right arrow moves caret down from upstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester, customDocument: paragraphThenHrDoc());
      await tester.placeCaretInParagraph("1", 11);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 11, affinity: TextAffinity.upstream),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("skips node when up arrow moves caret up from downstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);
      await tester.placeCaretInParagraph("3", 37);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 37, affinity: TextAffinity.upstream),
          ),
        ),
      );
    });

    testWidgetsOnDesktop("skips node when left arrow moves caret up from downstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);
      await tester.placeCaretInParagraph("3", 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 37)),
        ),
      );
    });

    testWidgetsOnDesktop("rejects selection when up arrow moves caret up from downstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester, customDocument: hrThenParagraphDoc());
      await tester.placeCaretInParagraph("2", 11);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgetsOnDesktop("rejects selection when left arrow moves caret up from downstream node", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester, customDocument: hrThenParagraphDoc());
      await tester.placeCaretInParagraph("2", 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgetsOnDesktop("deletes downstream node when delete pressed from upstream", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);
      await tester.placeCaretInParagraph("1", 37);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 37, affinity: TextAffinity.upstream),
          ),
        ),
      );
      expect(
        find.byType(SuperEditor),
        equalsMarkdown(
          "This is the first node in a document.\n\n"
          "This is the third node in a document.",
        ),
      );
    });

    testWidgetsOnDesktop("deletes upstream node when backspace pressed from downstream", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);
      await tester.placeCaretInParagraph("3", 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      expect(
        find.byType(SuperEditor),
        equalsMarkdown(
          "This is the first node in a document.\n\n"
          "This is the third node in a document.",
        ),
      );
    });

    testWidgetsOnAllPlatforms("rejects selection when user taps on it and it's the only node in document",
        (tester) async {
      await _pumpEditorWithUnselectableHrs(
        tester,
        customDocument: singleBlockDoc(),
      );

      await tester.tapAtDocumentPosition(const DocumentPosition(
        nodeId: "1",
        nodePosition: UpstreamDownstreamNodePosition.upstream(),
      ));
      await tester.pumpAndSettle();

      expect(SuperEditorInspector.findDocumentSelection(), isNull);
    });

    testWidgetsOnAllPlatforms("selects nearest selectable node when user taps on it", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);

      await tester.tapAtDocumentPosition(const DocumentPosition(
        nodeId: "2",
        nodePosition: UpstreamDownstreamNodePosition.upstream(),
      ));
      await tester.pumpAndSettle();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("selects nearest selectable node when user double taps on it", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);

      // Double tap the hr.
      const position = DocumentPosition(
        nodeId: "2",
        nodePosition: UpstreamDownstreamNodePosition.upstream(),
      );
      await tester.tapAtDocumentPosition(position);
      await tester.pump(kTapMinTime + const Duration(milliseconds: 1));
      await tester.tapAtDocumentPosition(position);

      await tester.pumpAndSettle();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("selects nearest selectable node when user triple taps on it", (tester) async {
      await _pumpEditorWithUnselectableHrs(tester);

      // Triple tap the hr.
      const position = DocumentPosition(
        nodeId: "2",
        nodePosition: UpstreamDownstreamNodePosition.upstream(),
      );
      await tester.tapAtDocumentPosition(position);
      await tester.pump(kTapMinTime + const Duration(milliseconds: 1));
      await tester.tapAtDocumentPosition(position);
      await tester.pump(kTapMinTime + const Duration(milliseconds: 1));
      await tester.tapAtDocumentPosition(position);

      await tester.pumpAndSettle();

      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnMobile("closes toolbar when user taps on it", (tester) async {
      final toolbarKey = GlobalKey();

      await _pumpEditorWithUnselectableHrsAndFakeToolbar(
        tester,
        toolbarKey: toolbarKey,
      );

      // Place the selection in the first paragraph.
      await tester.doubleTapInParagraph("1", 0);
      // Avoid triple tap.
      await tester.pump(kTapTimeout);
      await tester.pumpAndSettle();

      // Ensure the toolbar is displayed.
      expect(find.byKey(toolbarKey), findsOneWidget);

      // Tap the hr.
      await tester.tapAtDocumentPosition(const DocumentPosition(
        nodeId: "2",
        nodePosition: UpstreamDownstreamNodePosition.upstream(),
      ));

      await tester.pumpAndSettle();

      // Ensure the toolbar is closed.
      expect(find.byKey(toolbarKey), findsNothing);
    });

    testWidgetsOnMobile("closes toolbar when user double taps on it", (tester) async {
      final toolbarKey = GlobalKey();

      await _pumpEditorWithUnselectableHrsAndFakeToolbar(
        tester,
        toolbarKey: toolbarKey,
      );

      // Place the selection in the first paragraph.
      await tester.doubleTapInParagraph("1", 0);
      await tester.pumpAndSettle();

      // Ensure the toolbar is displayed.
      expect(find.byKey(toolbarKey), findsOneWidget);

      // Double tap the hr.
      const position = DocumentPosition(
        nodeId: "2",
        nodePosition: UpstreamDownstreamNodePosition.upstream(),
      );
      await tester.tapAtDocumentPosition(position);
      await tester.pump(kTapMinTime + const Duration(milliseconds: 1));
      await tester.tapAtDocumentPosition(position);

      await tester.pumpAndSettle();

      // Ensure the toolbar is closed.
      expect(find.byKey(toolbarKey), findsNothing);
    });

    testWidgetsOnMobile("closes toolbar when user triple taps on it", (tester) async {
      final toolbarKey = GlobalKey();

      await _pumpEditorWithUnselectableHrsAndFakeToolbar(
        tester,
        toolbarKey: toolbarKey,
      );

      // Place the selection in the first paragraph.
      await tester.doubleTapInParagraph("1", 0);
      await tester.pumpAndSettle();

      // Ensure the toolbar is displayed.
      expect(find.byKey(toolbarKey), findsOneWidget);

      // Triple tap the hr.
      const position = DocumentPosition(
        nodeId: "2",
        nodePosition: UpstreamDownstreamNodePosition.upstream(),
      );
      await tester.tapAtDocumentPosition(position);
      await tester.pump(kTapMinTime + const Duration(milliseconds: 1));
      await tester.tapAtDocumentPosition(position);
      await tester.pump(kTapMinTime + const Duration(milliseconds: 1));
      await tester.tapAtDocumentPosition(position);

      await tester.pumpAndSettle();

      // Ensure the toolbar is closed.
      expect(find.byKey(toolbarKey), findsNothing);
    });
  });
}

Future<TestDocumentContext> _pumpEditorWithSelectableHrs(WidgetTester tester) => tester //
    .createDocument() //
    .withCustomContent(paragraphThenHrThenParagraphDoc()) //
    .forDesktop() //
    .useStylesheet(_testStylesheet)
    .pump();

Future<TestDocumentContext> _pumpEditorWithUnselectableHrs(
  WidgetTester tester, {
  MutableDocument? customDocument,
}) =>
    tester //
        .createDocument() //
        .withCustomContent(customDocument ?? paragraphThenHrThenParagraphDoc()) //
        .useStylesheet(_testStylesheet)
        .withAddedComponents([const _UnselectableHrComponentBuilder()]) //
        .pump();

Future<void> _pumpEditorWithUnselectableHrsAndFakeToolbar(
  WidgetTester tester, {
  required GlobalKey toolbarKey,
}) async {
  final editor = DocumentEditor(
    document: paragraphThenHrThenParagraphDoc(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: editor,
          gestureMode: debugDefaultTargetPlatformOverride == TargetPlatform.android
              ? DocumentGestureMode.android
              : DocumentGestureMode.iOS,
          androidToolbarBuilder: (_) => SizedBox(key: toolbarKey),
          iOSToolbarBuilder: (_) => SizedBox(key: toolbarKey),
          componentBuilders: [
            const _UnselectableHrComponentBuilder(),
            ...defaultComponentBuilders,
          ],
        ),
      ),
    ),
  );
}

/// SuperEditor [ComponentBuilder] that builds a horizontal rule that is
/// not selectable.
class _UnselectableHrComponentBuilder implements ComponentBuilder {
  const _UnselectableHrComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    // This builder can work with the standard horizontal rule view model, so
    // we'll defer to the standard horizontal rule builder.
    return null;
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! HorizontalRuleComponentViewModel) {
      return null;
    }

    return _UnselectableHorizontalRuleComponent(
      componentKey: componentContext.componentKey,
    );
  }
}

class _UnselectableHorizontalRuleComponent extends StatelessWidget {
  const _UnselectableHorizontalRuleComponent({
    Key? key,
    required this.componentKey,
  }) : super(key: key);

  final GlobalKey componentKey;

  @override
  Widget build(BuildContext context) {
    return BoxComponent(
      key: componentKey,
      isVisuallySelectable: false,
      child: const Divider(
        color: Color(0xFF000000),
        thickness: 1.0,
      ),
    );
  }
}

final _testStylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) {
      return {
        "textStyle": const TextStyle(
          fontSize: 12,
        ),
      };
    })
  ],
);
