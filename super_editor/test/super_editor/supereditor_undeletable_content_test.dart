import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'supereditor_test_tools.dart';

void main() {
  group('SuperEditor > undeletable content > prevents deletion > ', () {
    group('with backspace', () {
      testWidgetsOnArbitraryDesktop('at the downstream edge of the node', (tester) async {
        await _pumpHrThenParagraphTestApp(tester);

        // Place the caret at the downstream edge of the horizontal rule.
        await tester.tapAtDocumentPosition(
          const DocumentPosition(
            nodeId: 'hr',
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        );

        // Ensure the selection is at the downstream edge of the horizontal ruler.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'hr',
              nodePosition: UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
        );

        // Press backspace a few times trying to delete the node.
        await tester.pressBackspace();
        await tester.pressBackspace();
        await tester.pressBackspace();

        // Ensure that the horizontal ruler was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('with an expanded downstream selection', (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select the whole hr.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press backspace a few times trying to delete the node.
        await tester.pressBackspace();
        await tester.pressBackspace();
        await tester.pressBackspace();

        // Ensure that the horizontal ruler was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('with an expanded upstream selection', (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select the whole hr.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press backspace a few times trying to delete the node.
        await tester.pressBackspace();
        await tester.pressBackspace();
        await tester.pressBackspace();

        // Ensure that the horizontal ruler was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnAllPlatforms('when multiple deletable and undeletable nodes are selected', (tester) async {
        final testContext = await _pumpMultipleDeletableAndUndeletableNodesTestApp(tester);

        // Select from "Para>graph 1" to "Paragraph <3".
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
              extent: DocumentPosition(
                nodeId: '3',
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
            SelectionChangeType.alteredContent,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press backspace to delete the selected nodes.
        await tester.pressBackspace();

        // Ensure that the deletable content was deleted and selection moved to upstream edge
        // of the first deletable node.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, 4);
        expect(SuperEditorInspector.findTextInComponent('1'), AttributedText('Para3'));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 4)),
            ),
          ),
        );

        // Ensure that the undeletable content was not deleted.
        expect(document.getNodeById('hr1'), isNotNull);
        expect(document.getNodeById('hr1'), isA<HorizontalRuleNode>());

        expect(document.getNodeById('hr2'), isNotNull);
        expect(document.getNodeById('hr2'), isA<HorizontalRuleNode>());

        expect(document.getNodeById('hr3'), isNotNull);
        expect(document.getNodeById('hr3'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('when selection starts at upstream edge and ends at a downstream deletable node',
          (tester) async {
        final testContext = await _pumpHrThenParagraphTestApp(tester);

        // Select from the upstream edge of the horizontal rule to "Para|graph 1".
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press backspace to delete the selected content.
        await tester.pressBackspace();

        // Ensure that the deletable content was deleted and selection moved to the beginning
        // of the selected paragraph.
        expect(
          SuperEditorInspector.findTextInComponent('1').text,
          'graph 1',
        );
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
            ),
          ),
        );

        // Ensure that the horizontal rule was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('when selection starts at downstream edge and ends at an upstream deletable node',
          (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select from the downstream edge of the horizontal rule to "Para|graph 1".
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press backspace to delete the selected content.
        await tester.pressBackspace();

        // Ensure that the deletable content was deleted and selection moved to the upstream edge
        // of the selection
        expect(
          SuperEditorInspector.findTextInComponent('1').text,
          'Para',
        );
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 4)),
            ),
          ),
        );

        // Ensure that the horizontal ruler was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop(
          'when selection starts at an upstream deletable node and ends at the downstream edge', (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select from the "Para|graph 1" to the downstream edge of the horizontal rule.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press backspace to delete the selected content.
        await tester.pressBackspace();

        // Ensure that the deletable content was deleted and selection moved to the beginning
        // of the selected paragraph.
        expect(SuperEditorInspector.findTextInComponent('1').text, 'Para');
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 4)),
            ),
          ),
        );

        // Ensure that the horizontal ruler was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop(
          'when selection starts at a downstream deletable node and ends at the upstream edge', (tester) async {
        final testContext = await _pumpHrThenParagraphTestApp(tester);

        // Select from the "Para|graph 2" to the upstream edge of the second horizontal ruler.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press backspace to delete the selected content.
        await tester.pressBackspace();

        // Ensure that the deletable content was deleted and selection moved to the beginning
        // of the selected paragraph.
        expect(SuperEditorInspector.findTextInComponent('1').text, 'graph 1');
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
            ),
          ),
        );

        // Ensure that the horizontal ruler was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });
    });

    group('with delete', () {
      testWidgetsOnArbitraryDesktop('at the upstream edge of the node', (tester) async {
        await _pumpParagraphThenHrTestApp(tester);

        // Place the caret at the upstream edge of the horizontal rule.
        await tester.tapAtDocumentPosition(
          const DocumentPosition(
            nodeId: 'hr',
            nodePosition: UpstreamDownstreamNodePosition.upstream(),
          ),
        );

        // Ensure the selection is at the beginning of the horizontal rule.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'hr',
              nodePosition: UpstreamDownstreamNodePosition.upstream(),
            ),
          ),
        );

        // Press delete a few times trying to delete the node.
        await tester.pressDelete();
        await tester.pressDelete();
        await tester.pressDelete();

        // Ensure that the horizontal rule was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('with an expanded downstream selection', (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select the whole hr.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press delete a few times trying to delete the node.
        await tester.pressDelete();
        await tester.pressDelete();
        await tester.pressDelete();

        // Ensure that the horizontal rule was not deleted and not converted to a paragraph.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('with an expanded upstream selection', (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select the whole hr.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press delete a few times trying to delete the node.
        await tester.pressDelete();
        await tester.pressDelete();
        await tester.pressDelete();

        // Ensure that the horizontal rule was not deleted.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('when multiple deletable and undeletable nodes are selected', (tester) async {
        final testContext = await _pumpMultipleDeletableAndUndeletableNodesTestApp(tester);

        // Select from "Para>graph 1" to "Paragraph <3".
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
              extent: DocumentPosition(
                nodeId: '3',
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press delete to delete the selected nodes.
        await tester.pressDelete();

        // Ensure that the deletable content was deleted and selection moved to upstream edge
        // of the first deletable node.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, 4);
        expect(SuperEditorInspector.findTextInComponent('1'), AttributedText('Para3'));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 4)),
            ),
          ),
        );

        // Ensure that the undeletable content was not deleted.
        expect(document.getNodeById('hr1'), isNotNull);
        expect(document.getNodeById('hr1'), isA<HorizontalRuleNode>());

        expect(document.getNodeById('hr2'), isNotNull);
        expect(document.getNodeById('hr2'), isA<HorizontalRuleNode>());

        expect(document.getNodeById('hr3'), isNotNull);
        expect(document.getNodeById('hr3'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('when selection starts at upstream edge and ends at a downstream deletable node',
          (tester) async {
        final testContext = await _pumpHrThenParagraphTestApp(tester);

        // Select from the upstream edge of the horizontal rule to "Para|graph 1".
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press delete to remove the selected content.
        await tester.pressDelete();

        // Ensure that the deletable content was deleted and selection moved to the beginning
        // of the selected paragraph.
        expect(
          SuperEditorInspector.findTextInComponent('1').text,
          'graph 1',
        );
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
            ),
          ),
        );

        // Ensure that the horizontal rule was not deleted.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop('when selection starts at downstream edge and ends at an upstream deletable node',
          (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select from the downstream edge of the horizontal rule to "Para|graph 1".
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press delete to remove the selected content.
        await tester.pressDelete();

        // Ensure that the deletable content was deleted and selection moved to the upstream edge
        // of the selection
        expect(
          SuperEditorInspector.findTextInComponent('1').text,
          'Para',
        );
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 4)),
            ),
          ),
        );

        // Ensure that the horizontal ruler was not deleted.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop(
          'when selection starts at an upstream deletable node and ends at the downstream edge', (tester) async {
        final testContext = await _pumpParagraphThenHrTestApp(tester);

        // Select from the "Para|graph 1" to the downstream edge of the horizontal rule.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.downstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press delete to remove the selected content.
        await tester.pressDelete();

        // Ensure that the deletable content was deleted and selection moved to the beginning
        // of the selected paragraph.
        expect(SuperEditorInspector.findTextInComponent('1').text, 'Para');
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 4)),
            ),
          ),
        );

        // Ensure that the horizontal rule was not deleted.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });

      testWidgetsOnArbitraryDesktop(
          'when selection starts at a downstream deletable node and ends at the upstream edge', (tester) async {
        final testContext = await _pumpHrThenParagraphTestApp(tester);

        // Select from the "Para|graph 2" to the upstream edge of the second horizontal ruler.
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
              extent: DocumentPosition(
                nodeId: 'hr',
                nodePosition: UpstreamDownstreamNodePosition.upstream(),
              ),
            ),
            SelectionChangeType.expandSelection,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Press delete to remove the selected content.
        await tester.pressDelete();

        // Ensure that the deletable content was deleted and selection moved to the beginning
        // of the selected paragraph.
        expect(SuperEditorInspector.findTextInComponent('1').text, 'graph 1');
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
            ),
          ),
        );

        // Ensure that the horizontal rule was not deleted.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.getNodeById('hr'), isNotNull);
        expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());
      });
    });

    group('when typing', () {
      testWidgetsOnArbitraryDesktop('when typing with multiple nodes selected', (tester) async {
        final testContext = await _pumpMultipleDeletableAndUndeletableNodesTestApp(tester);

        // Select from "Para>graph 1" to "Paragraph <3".
        testContext.editor.execute([
          const ChangeSelectionRequest(
            DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 4),
              ),
              extent: DocumentPosition(
                nodeId: '3',
                nodePosition: TextNodePosition(offset: 10),
              ),
            ),
            SelectionChangeType.alteredContent,
            SelectionReason.userInteraction,
          )
        ]);
        await tester.pump();

        // Type a character to replace the selected nodes.
        await tester.typeImeText('X');

        // Ensure that the deletable content was deleted and the text was inserted at the upstream
        // edge of the selection.
        final document = SuperEditorInspector.findDocument()!;
        expect(document.nodeCount, 4);
        expect(SuperEditorInspector.findTextInComponent('1'), AttributedText('ParaX3'));
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 5)),
            ),
          ),
        );

        // Ensure that the undeletable content was not deleted.
        expect(document.getNodeById('hr1'), isNotNull);
        expect(document.getNodeById('hr1'), isA<HorizontalRuleNode>());

        expect(document.getNodeById('hr2'), isNotNull);
        expect(document.getNodeById('hr2'), isA<HorizontalRuleNode>());

        expect(document.getNodeById('hr3'), isNotNull);
        expect(document.getNodeById('hr3'), isA<HorizontalRuleNode>());
      });
    });

    // group('with backspace in software keyboard', () {
    //   testWidgetsOnMobile('at the downstream edge of the node', (tester) async {
    //     await _pumpHrThenParagraphTestApp(tester);

    //     // Place the caret at the downstream edge of the horizontal rule.
    //     await tester.tapAtDocumentPosition(
    //       const DocumentPosition(
    //         nodeId: 'hr',
    //         nodePosition: UpstreamDownstreamNodePosition.downstream(),
    //       ),
    //     );
    //     await tester.pump();

    //     // Simulate pressing backspace.
    //     await tester.ime.sendDeltas([
    //       const TextEditingDeltaNonTextUpdate(
    //         oldText: '. ~',
    //         selection: TextSelection.collapsed(offset: 3),
    //         composing: TextRange(start: -1, end: -1),
    //       ),
    //       const TextEditingDeltaDeletion(
    //         oldText: '. ~',
    //         deletedRange: TextRange.collapsed(2),
    //         selection: TextSelection.collapsed(offset: 2),
    //         composing: TextRange(start: -1, end: -1),
    //       ),
    //     ], getter: imeClientGetter);

    //     // Ensure that the horizontal ruler was not deleted and not converted to a paragraph.
    //     final document = SuperEditorInspector.findDocument()!;
    //     expect(document.getNodeById('hr'), isNotNull);
    //     expect(document.getNodeById('hr'), isA<HorizontalRuleNode>());

    //     // Ensure the selection was kept where it was.
    //     expect(
    //       SuperEditorInspector.findDocumentSelection(),
    //       const DocumentSelection.collapsed(
    //         position: DocumentPosition(
    //           nodeId: 'hr',
    //           nodePosition: UpstreamDownstreamNodePosition.downstream(),
    //         ),
    //       ),
    //     );
    //   });
    // });
  });
}

/// Pumps a widget tree with a paragraph followed by a horizontal rule.
Future<TestDocumentContext> _pumpParagraphThenHrTestApp(WidgetTester tester) async {
  return await tester
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ParagraphNode(
              id: '1',
              text: AttributedText('Paragraph 1'),
            ),
            HorizontalRuleNode(id: 'hr', metadata: {
              NodeMetadata.isDeletable: false,
            }),
          ],
        ),
      )
      .withInputSource(TextInputSource.ime)
      .autoFocus(true)
      .pump();
}

/// Pumps a widget tree with a horizontal rule followed by a paragraph.
Future<TestDocumentContext> _pumpHrThenParagraphTestApp(WidgetTester tester) async {
  return await tester
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            HorizontalRuleNode(id: 'hr', metadata: {
              NodeMetadata.isDeletable: false,
            }),
            ParagraphNode(
              id: '1',
              text: AttributedText('Paragraph 1'),
            ),
          ],
        ),
      )
      .withInputSource(TextInputSource.ime)
      .autoFocus(true)
      .pump();
}

/// Pumps a widget tree containing:
///
/// - Paragraph.
/// - Horizontal rule.
/// - Horizontal rule.
/// - Paragraph.
/// - Horizontal rule.
/// - Paragraph.
Future<TestDocumentContext> _pumpMultipleDeletableAndUndeletableNodesTestApp(WidgetTester tester) async {
  return await tester
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ParagraphNode(
              id: '1',
              text: AttributedText('Paragraph 1'),
            ),
            HorizontalRuleNode(id: 'hr1', metadata: {
              NodeMetadata.isDeletable: false,
            }),
            HorizontalRuleNode(id: 'hr2', metadata: {
              NodeMetadata.isDeletable: false,
            }),
            ParagraphNode(
              id: '2',
              text: AttributedText('Paragraph 2'),
            ),
            HorizontalRuleNode(id: 'hr3', metadata: {
              NodeMetadata.isDeletable: false,
            }),
            ParagraphNode(
              id: '3',
              text: AttributedText('Paragraph 3'),
            ),
          ],
        ),
      )
      .withInputSource(TextInputSource.ime)
      .autoFocus(true)
      .pump();
}
