import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/infrastructure/blinking_caret.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("SuperEditor selection", () {
    testWidgetsOnArbitraryDesktop("calculates upstream document selection within a single node", (tester) async {
      await tester //
          .createDocument() //
          .fromMarkdown("This all fits on one line.") //
          .pump();

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Drag from upper-right to lower-left.
      //
      // By dragging in this exact direction, we're purposefully introducing contrary
      // directions: right-to-left is upstream for a single line, and up-to-down is
      // downstream for multi-node. This test ensures that the single-line direction is
      // honored by the document layout, rather than the more common multi-node calculation.
      final selection = layout.getDocumentSelectionInRegion(const Offset(200, 35), const Offset(150, 45));
      expect(selection, isNotNull);

      // Ensure that the document selection is upstream.
      final base = selection!.base.nodePosition as TextNodePosition;
      final extent = selection.extent.nodePosition as TextNodePosition;
      expect(base.offset > extent.offset, isTrue);
    });

    testWidgetsOnArbitraryDesktop("calculates downstream document selection within a single node", (tester) async {
      await tester //
          .createDocument() //
          .fromMarkdown("This all fits on one line.") //
          .pump();

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Drag from lower-left to upper-right.
      //
      // By dragging in this exact direction, we're purposefully introducing contrary
      // directions: left-to-right is downstream for a single line, and down-to-up is
      // upstream for multi-node. This test ensures that the single-line direction is
      // honored by the document layout, rather than the more common multi-node calculation.
      final selection = layout.getDocumentSelectionInRegion(const Offset(150, 45), const Offset(200, 35));
      expect(selection, isNotNull);

      // Ensure that the document selection is downstream.
      final base = selection!.base.nodePosition as TextNodePosition;
      final extent = selection.extent.nodePosition as TextNodePosition;
      expect(base.offset < extent.offset, isTrue);
    });

    testWidgetsOnArbitraryDesktop("calculates downstream document selection within a single node", (tester) async {
      final testContext = await tester //
          .createDocument() //
          .fromMarkdown("This is paragraph one.\nThis is paragraph two.") //
          .pump();
      final nodeId = testContext.editContext.editor.document.nodes.first.id;

      /// Triple tap on the first line in the paragraph node.
      await tester.tripleTapInParagraph(nodeId, 10);

      /// Ensure that only the first line is selected.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 22)),
        ),
      );

      /// Triple tap on the second line in the paragraph node.
      await tester.tripleTapInParagraph(nodeId, 25);

      /// Ensure that only the second line is selected.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 23)),
          extent: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 45)),
        ),
      );
    });

    testWidgetsOnArbitraryDesktop("doesn't select an unselectable component at base (dragging upstream)",
        (tester) async {
      final testContext = await _pumpUnselectableComponentTestApp(tester);

      final firstParagraphId = testContext.editContext.editor.document.nodes.first.id;

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Attempt to select from the horizontal rule to the beginning of the first paragraph
      final selection = layout.getDocumentSelectionInRegion(
        tester.getBottomRight(find.byType(Divider)),
        tester.getTopLeft(find.text('First Paragraph', findRichText: true)),
      );

      // Ensure we don't select the horizontal rule
      expect(
        selection,
        DocumentSelection(
          base: DocumentPosition(nodeId: firstParagraphId, nodePosition: const TextNodePosition(offset: 15)),
          extent: DocumentPosition(nodeId: firstParagraphId, nodePosition: const TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgetsOnArbitraryDesktop("doesn't select an unselectable component at extent (dragging upstream)",
        (tester) async {
      final testContext = await _pumpUnselectableComponentTestApp(tester);

      final secondParagraphId = testContext.editContext.editor.document.nodes.last.id;

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Attempt to select from the end of the second paragraph to the horizontal rule
      final selection = layout.getDocumentSelectionInRegion(
        tester.getBottomRight(find.text('Second Paragraph', findRichText: true)),
        tester.getTopLeft(find.byType(Divider)),
      );

      // Ensure we don't select the horizontal rule
      expect(
        selection,
        DocumentSelection(
          base: DocumentPosition(
              nodeId: secondParagraphId,
              nodePosition: const TextNodePosition(
                offset: 16,
                affinity: TextAffinity.upstream,
              )),
          extent: DocumentPosition(nodeId: secondParagraphId, nodePosition: const TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgetsOnArbitraryDesktop("doesn't select an unselectable component at base (dragging downstream)",
        (tester) async {
      final testContext = await _pumpUnselectableComponentTestApp(tester);

      final secondParagraphId = testContext.editContext.editor.document.nodes.last.id;

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Attempt to select from the horizontal rule to the end of the second paragraph
      final selection = layout.getDocumentSelectionInRegion(
        tester.getTopLeft(find.byType(Divider)),
        tester.getBottomRight(find.text('Second Paragraph', findRichText: true)),
      );

      // Ensure we don't select the horizontal rule
      expect(
        selection,
        DocumentSelection(
          base: DocumentPosition(nodeId: secondParagraphId, nodePosition: const TextNodePosition(offset: 0)),
          extent: DocumentPosition(
              nodeId: secondParagraphId,
              nodePosition: const TextNodePosition(
                offset: 16,
                affinity: TextAffinity.upstream,
              )),
        ),
      );
    });

    testWidgetsOnArbitraryDesktop("doesn't select an unselectable component at extent (dragging downstream)",
        (tester) async {
      final testContext = await _pumpUnselectableComponentTestApp(tester);

      final firstParagraphId = testContext.editContext.editor.document.nodes.first.id;

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Attempt to select from first paragraph to the horizontal rule
      final selection = layout.getDocumentSelectionInRegion(
        tester.getTopLeft(find.text('First Paragraph', findRichText: true)),
        tester.getBottomRight(find.byType(Divider)),
      );

      // Ensure we don't select the horizontal rule
      expect(
        selection,
        DocumentSelection(
          base: DocumentPosition(nodeId: firstParagraphId, nodePosition: const TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: firstParagraphId, nodePosition: const TextNodePosition(offset: 15)),
        ),
      );
    });

    testWidgetsOnArbitraryDesktop("selects paragraphs surrounding an unselectable component (dragging upstream)",
        (tester) async {
      final testContext = await _pumpUnselectableComponentTestApp(tester);

      final firstParagraphId = testContext.editContext.editor.document.nodes.first.id;
      final secondParagraphId = testContext.editContext.editor.document.nodes.last.id;

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Attempt to select from the end of the second paragraph to the beginning of the first paragraph
      final selection = layout.getDocumentSelectionInRegion(
        tester.getBottomRight(find.text('Second Paragraph', findRichText: true)),
        tester.getTopLeft(find.text('First Paragraph', findRichText: true)),
      );

      // Ensure we select the whole document
      expect(
        selection,
        DocumentSelection(
          base: DocumentPosition(
            nodeId: secondParagraphId,
            nodePosition: const TextNodePosition(offset: 16, affinity: TextAffinity.upstream),
          ),
          extent: DocumentPosition(nodeId: firstParagraphId, nodePosition: const TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgetsOnArbitraryDesktop("selects paragraphs surrounding an unselectable component (dragging downstream)",
        (tester) async {
      final testContext = await _pumpUnselectableComponentTestApp(tester);

      final firstParagraphId = testContext.editContext.editor.document.nodes.first.id;
      final secondParagraphId = testContext.editContext.editor.document.nodes.last.id;

      // TODO: replace the following direct layout access with a simulated user
      // drag, once we've merged some new dragging tools in #645.
      final layoutState = (find.byType(SingleColumnDocumentLayout).evaluate().single as StatefulElement).state;
      final layout = layoutState as DocumentLayout;

      // Attempt to select from the beginning of the first paragraph to the end of the second paragraph
      final selection = layout.getDocumentSelectionInRegion(
        tester.getTopLeft(find.text('First Paragraph', findRichText: true)),
        tester.getBottomRight(find.text('Second Paragraph', findRichText: true)),
      );

      // Ensure we select the whole document
      expect(
        selection,
        DocumentSelection(
          base: DocumentPosition(nodeId: firstParagraphId, nodePosition: const TextNodePosition(offset: 0)),
          extent: DocumentPosition(
              nodeId: secondParagraphId,
              nodePosition: const TextNodePosition(
                offset: 16,
                affinity: TextAffinity.upstream,
              )),
        ),
      );
    });

    testWidgetsOnAllPlatforms("removes caret when it loses focus", (tester) async {
      await tester
          .createDocument()
          .withLongTextContent()
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const TextField(),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Place the caret in the document.
      await tester.placeCaretInParagraph("1", 0);

      // Focus the textfield.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Ensure that the document doesn't have focus, and isn't displaying a caret.
      expect(SuperEditorInspector.hasFocus(), isFalse);
      expect(SuperEditorInspector.findDocumentSelection(), isNull);
      expect(_caretFinder(), findsNothing); // TODO: move caret finding into inspector
    });

    testWidgetsOnAllPlatforms("places caret at end of document upon first editor focus with tab", (tester) async {
      await tester
          .createDocument()
          .withLongTextContent()
          .withAddedComponents([const _UnselectableHrComponentBuilder()])
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const TextField(),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Focus the textfield.
      await tester.tap(find.byType(TextField));

      // Press tab to focus the editor.
      await tester.pressTab();
      await tester.pumpAndSettle();

      final doc = SuperEditorInspector.findDocument();

      // Ensure selection is at the last character of the last paragraph.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: doc!.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 477),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms("places caret at end of document upon first editor focus with next", (tester) async {
      await tester
          .createDocument()
          .withLongTextContent()
          .withInputSource(DocumentInputSource.ime)
          .withAddedComponents([const _UnselectableHrComponentBuilder()])
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const TextField(),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Focus the textfield.
      await tester.tap(find.byType(TextField));

      // Simulate a tap at the action button on the text field.
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      final doc = SuperEditorInspector.findDocument();

      // Ensure selection is at the last character of the last paragraph.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: doc!.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 477),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms("places caret at end of document upon first editor focus when requesting focus",
        (tester) async {
      final focusNode = FocusNode();

      await tester //
          .createDocument()
          .withLongTextContent()
          .withFocusNode(focusNode)
          .withAddedComponents([const _UnselectableHrComponentBuilder()]).pump();

      // Ensure the editor doesn't have a selection.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);

      // Focus the editor.
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final doc = SuperEditorInspector.findDocument();

      // Ensure selection is at the last character of the second paragraph.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: doc!.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 477),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms("places caret at end of document upon first editor focus on autofocus", (tester) async {
      await tester //
          .createDocument()
          .withLongTextContent()
          .autoFocus(true)
          .withAddedComponents([const _UnselectableHrComponentBuilder()]).pump();

      await tester.pumpAndSettle();

      final doc = SuperEditorInspector.findDocument();

      // Ensure selection is at the last character of the last paragraph.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: doc!.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 477),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms("ignores unselectable components upon first editor focus", (tester) async {
      await tester
          .createDocument()
          .fromMarkdown("""
First Paragraph

Second Paragraph

---
""")
          .withAddedComponents([const _UnselectableHrComponentBuilder()])
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const TextField(),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Focus the textfield.
      await tester.tap(find.byType(TextField));

      // Press tab to focus the editor.
      await tester.pressTab();
      await tester.pumpAndSettle();

      final doc = SuperEditorInspector.findDocument();
      final secondParagraphNodeId = doc!.nodes[1].id;

      // Ensure selection is at the last character of the second paragraph.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: secondParagraphNodeId,
            nodePosition: const TextNodePosition(offset: 16),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms("places caret at the previous selection when re-focusing by tab", (tester) async {
      await tester
          .createDocument()
          .withSingleParagraph()
          .withInputSource(DocumentInputSource.ime)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const TextField(),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Place caret in the middle of a word.
      await tester.placeCaretInParagraph('1', 8);
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );

      // Focus the textfield.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Ensure selection was cleared.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);

      // Press tab to focus the editor.
      await tester.pressTab();
      await tester.pumpAndSettle();

      // Ensure selection is restored.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms("places caret at the previous selection when re-focusing by next", (tester) async {
      await tester
          .createDocument()
          .withSingleParagraph()
          .withInputSource(DocumentInputSource.ime)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const TextField(),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Place caret in the middle of a word.
      await tester.placeCaretInParagraph('1', 8);
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );

      // Focus the textfield.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Ensure selection was cleared.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);

      // Simulate a tap at the action button.
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Ensure selection is restored.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms("places caret at the previous selection when re-focusing by requesting focus",
        (tester) async {
      final focusNode = FocusNode();

      await tester
          .createDocument()
          .withSingleParagraph()
          .withInputSource(DocumentInputSource.ime)
          .withFocusNode(focusNode)
          .withCustomWidgetTreeBuilder(
            (superEditor) => MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const TextField(),
                    Expanded(child: superEditor),
                  ],
                ),
              ),
            ),
          )
          .pump();

      // Place caret in the middle of a word.
      await tester.placeCaretInParagraph('1', 8);
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );

      // Focus the textfield.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Ensure selection was cleared.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);

      // Focus the editor.
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Ensure selection is restored.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    testWidgetsOnAllPlatforms('retains composer initial selection upon first editor focus', (tester) async {
      final focusNode = FocusNode();

      const initialSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: '1',
          nodePosition: TextNodePosition(offset: 6),
        ),
      );

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withFocusNode(focusNode)
          .withSelection(initialSelection)
          .pump();

      focusNode.requestFocus();

      await tester.pumpAndSettle();

      // Ensure initial selection was retained.
      expect(SuperEditorInspector.findDocumentSelection(), initialSelection);

      // Ensure caret is displayed.
      expect(_caretFinder(), findsOneWidget);
    });

    test("emits a DocumentSelectionChange when changing selection by the notifier", () async {
      final composer = DocumentComposer();

      const newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 0),
        ),
      );

      // Ensure the stream emits the DocumentSelectionChange.
      expectLater(
        composer.selectionChanges,
        emits(
          DocumentSelectionChange(
            selection: newSelection,
            reason: SelectionReason.userInteraction,
          ),
        ),
      );

      // Update the selection, which should cause the stream to emit a value.
      composer.selection = newSelection;
    }, timeout: const Timeout(Duration(milliseconds: 500)));

    test("notifies selectionNotifier when a new DocumentSelection is emitted", () {
      final composer = DocumentComposer();

      // Holds the selection emitted by the selectionNotifier.
      DocumentSelection? emittedSelection;

      const newSelection = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: "1",
          nodePosition: TextNodePosition(offset: 0),
        ),
      );

      composer.selectionNotifier.addListener(() {
        emittedSelection = composer.selectionNotifier.value;
      });

      // Emit a DocumentSelectionChange.
      composer.setSelectionWithReason(newSelection);

      // Ensure the listener was called and the selection in the selectionNotifier is correct.
      expect(emittedSelection, newSelection);
    });
  });
}

Future<TestDocumentContext> _pumpUnselectableComponentTestApp(WidgetTester tester) async {
  return await tester //
      .createDocument() //
      .fromMarkdown("""
First Paragraph

---

Second Paragraph
""")
      .withComponentBuilders([
        const _UnselectableHrComponentBuilder(),
        ...defaultComponentBuilders,
      ])
      .withEditorSize(const Size(300, 300))
      .pump();
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

Finder _caretFinder() {
  if (debugDefaultTargetPlatformOverride == TargetPlatform.iOS ||
      debugDefaultTargetPlatformOverride == TargetPlatform.android) {
    return find.byType(BlinkingCaret);
  }
  return find.byKey(primaryCaretKey);
}
