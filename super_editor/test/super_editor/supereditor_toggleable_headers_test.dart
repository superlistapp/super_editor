import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';

Future<void> main() async {
  await loadAppFonts();
  group('SuperEditor > Toggleable Headers > ', () {
    group('creates groups', () {
      testWidgetsOnArbitraryDesktop('upon initialization', (tester) async {
        await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('')),
            ParagraphNode(id: '2', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
            ParagraphNode(id: '3', text: AttributedText('')),
            ParagraphNode(id: '4', text: AttributedText('')),
            ParagraphNode(id: '5', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
            ParagraphNode(id: '6', text: AttributedText('')),
          ]),
        );

        // Ensure the groups were created.
        final firstGroupNodes = SuperEditorInspector.findAllNodesInGroup('2');
        expect(firstGroupNodes, collectionEqualsTo(['2', '3', '4']));
        final secondGroupNodes = SuperEditorInspector.findAllNodesInGroup('5');
        expect(secondGroupNodes, collectionEqualsTo(['5', '6']));
      });

      testWidgetsOnArbitraryDesktop('upon node insertion at the end', (tester) async {
        final editor = await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText()),
          ]),
        );

        // Insert the paragraph already as a header.
        editor.execute([
          InsertNodeAfterNodeRequest(
            existingNodeId: '1',
            newNode: ParagraphNode(
              id: '2',
              text: AttributedText(),
              metadata: {NodeMetadata.blockType: header1Attribution},
            ),
          ),
        ]);
        await tester.pump();

        // Place the caret at the end of the header and add a new node
        // so we will have a group with two nodes.
        await tester.placeCaretInParagraph('2', 0);
        await tester.pressEnter();

        // Ensure the group was created.
        final allNodes = SuperEditorInspector.findAllNodesInGroup('2');
        expect(allNodes, collectionEqualsTo(['2', editor.document.last.id]));
      });

      testWidgetsOnArbitraryDesktop('upon node insertion between nodes', (tester) async {
        final editor = await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText()),
            ParagraphNode(id: '3', text: AttributedText()),
          ]),
        );

        // Insert the paragraph already as a header.
        editor.execute([
          InsertNodeAfterNodeRequest(
            existingNodeId: '1',
            newNode: ParagraphNode(
              id: '2',
              text: AttributedText(),
              metadata: {NodeMetadata.blockType: header1Attribution},
            ),
          ),
        ]);
        await tester.pump();

        // Ensure the group was created.
        final allNodes = SuperEditorInspector.findAllNodesInGroup('2');
        expect(allNodes, collectionEqualsTo(['2', '3']));
      });

      testWidgetsOnArbitraryDesktop('when converting a node to a header', (tester) async {
        final editor = await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('')),
            ParagraphNode(id: '2', text: AttributedText('')),
            ParagraphNode(id: '3', text: AttributedText('')),
          ]),
        );

        // Ensure there are no groups.
        expect(SuperEditorInspector.findAllNodesInGroup('1'), []);
        expect(SuperEditorInspector.findAllNodesInGroup('2'), []);
        expect(SuperEditorInspector.findAllNodesInGroup('3'), []);

        // Place the caret at the beginning of the first paragraph.
        await tester.placeCaretInParagraph('1', 0);

        // Type "# " to convert the paragraph to a header.
        await tester.typeImeText('# ');

        // Ensure the paragraph was converted to a header.
        expect(editor.document.first.getMetadataValue('blockType'), header1Attribution);

        // Ensure the nodes were grouped.
        expect(SuperEditorInspector.findAllNodesInGroup('1'), collectionEqualsTo(['1', '2', '3']));
      });
    });

    group('removes groups', () {
      testWidgetsOnArbitraryDesktop('when deleting the root node', (tester) async {
        final editor = await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('')),
            ParagraphNode(id: '2', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
            ParagraphNode(id: '3', text: AttributedText('')),
            ParagraphNode(id: '4', text: AttributedText('')),
            ParagraphNode(id: '5', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
          ]),
        );

        // Ensure the nodes are grouped.
        expect(SuperEditorInspector.findGroupHeaderNode('3'), '2');
        expect(SuperEditorInspector.findGroupHeaderNode('4'), '2');

        // Delete the root of the group.
        //
        // Use a delete request to ensure we are deleting, because pressing
        // backspace will first convert the header into a regular paragraph.
        editor.execute([DeleteNodeRequest(nodeId: '2')]);
        await tester.pump();

        // Ensure the nodes are not grouped anymore.
        expect(SuperEditorInspector.findGroupHeaderNode('3'), isNull);
        expect(SuperEditorInspector.findGroupHeaderNode('4'), isNull);
      });

      testWidgetsOnArbitraryDesktop('when converting the root node to a regular paragraph', (tester) async {
        await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText('')),
            ParagraphNode(id: '2', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
            ParagraphNode(id: '3', text: AttributedText('')),
            ParagraphNode(id: '4', text: AttributedText('')),
            ParagraphNode(id: '5', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
          ]),
        );

        // Ensure the nodes are grouped.
        expect(SuperEditorInspector.findGroupHeaderNode('3'), '2');
        expect(SuperEditorInspector.findGroupHeaderNode('4'), '2');

        // Place the caret at the beginning of the header.
        await tester.placeCaretInParagraph('2', 0);

        // Press backspace to convert the header to a regular paragraph.
        await tester.pressBackspace();

        // Ensure the nodes are not grouped anymore.
        expect(SuperEditorInspector.findGroupHeaderNode('3'), isNull);
        expect(SuperEditorInspector.findGroupHeaderNode('4'), isNull);
      });
    });

    group('splits groups', () {
      testWidgetsOnArbitraryDesktop('when inserting a header of same level', (tester) async {
        final editor = await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
            ParagraphNode(id: '2', text: AttributedText('')),
            ParagraphNode(id: '3', text: AttributedText('')),
            ParagraphNode(id: '4', text: AttributedText('')),
          ]),
        );

        // Ensure all nodes are in the same group.
        expect(SuperEditorInspector.findAllNodesInGroup('1'), collectionEqualsTo(['1', '2', '3', '4']));

        // Place the caret at the end of the second node.
        await tester.placeCaretInParagraph('2', 0);

        // Create a new node and convert it to a header.
        await tester.pressEnter();
        await tester.typeImeText('# ');

        // Ensure the nodes were split into two groups.
        expect(SuperEditorInspector.findAllNodesInGroup('1'), collectionEqualsTo(['1', '2']));
        final newNodeId = editor.document.getNodeAt(2)!.id;
        expect(SuperEditorInspector.findAllNodesInGroup(newNodeId), collectionEqualsTo([newNodeId, '3', '4']));
      });
    });

    group('preserves expanded state', () {
      testWidgetsOnArbitraryDesktop('when adding an item to the group', (tester) async {
        final editor = await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
            ParagraphNode(id: '2', text: AttributedText('')),
            ParagraphNode(id: '3', text: AttributedText('')),
          ]),
        );

        // Ensure the group is expanded uppon initialization.
        expect(SuperEditorInspector.isGroupExpanded('1'), isTrue);

        // Place the caret at the last child of the header.
        await tester.placeCaretInParagraph('3', 0);

        // Press enter to add a new node to the group.
        await tester.pressEnter();

        // Ensure the group is still expanded.
        expect(SuperEditorInspector.isGroupExpanded('1'), isTrue);

        // Ensure the node was added to the group.
        expect(
          SuperEditorInspector.findAllNodesInGroup('1'),
          collectionEqualsTo(['1', '2', '3', editor.document.last.id]),
        );
      });
    });

    group('preserves collapsed state', () {
      testWidgetsOnArbitraryDesktop('when removing items from the group', (tester) async {
        final editor = await _buildToggleableTestApp(
          tester,
          document: MutableDocument(nodes: [
            ParagraphNode(id: '1', text: AttributedText(''), metadata: {NodeMetadata.blockType: header1Attribution}),
            ParagraphNode(id: '2', text: AttributedText('')),
            ParagraphNode(id: '3', text: AttributedText('')),
          ]),
        );

        // Ensure the group is expanded uppon initialization.
        expect(SuperEditorInspector.isGroupExpanded('1'), isTrue);

        // Collapse the group.
        await pressToggleButton(tester, '1');

        // Ensure the group was collapsed.
        expect(SuperEditorInspector.isGroupExpanded('1'), isFalse);

        // Remove the last child of the group. Since the group is collapsed,
        // we cannot delete just the child node with an user interaction.
        editor.execute([DeleteNodeRequest(nodeId: '3')]);
        await tester.pump();

        // Ensure the group is still collapsed.
        expect(SuperEditorInspector.isGroupExpanded('1'), isFalse);
      });
    });

    group('selection', () {
      group('does not select a collapsed component', () {
        testWidgetsOnArbitraryDesktop('when placing caret', (tester) async {
          await _buildToggleableTestApp(tester);

          // Store the offset of the level two header. This component will be hidden
          // when the group collapses.
          final hiddenComponentOffset = SuperEditorInspector.findComponentOffset('2', Alignment.center);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Tap where the level two header was positioned before being hidden.
          await tester.tapAt(hiddenComponentOffset);
          await tester.pump(kDoubleTapTimeout);

          // Ensure the caret was placed at the downstream level one header.
          final selection = SuperEditorInspector.findDocumentSelection();
          expect(selection, isNotNull);
          expect(selection!.isCollapsed, isTrue);
          expect(selection.extent.nodeId, equals('4'));
        });

        testWidgetsOnArbitraryDesktop('at extent (dragging downstream)', (tester) async {
          await _buildToggleableTestApp(tester);

          // Store the offset of the first child component. This component will be hidden
          // when the group collapses.
          final offset = SuperEditorInspector.findComponentOffset('1.1', Alignment.center);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Start dragging from the beginning of the first header.
          final testGesture = await tester.startDocumentDragFromPosition(
            from: const DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: 0),
            ),
          );

          // Drag down to the position where the hidden component was.
          await testGesture.moveTo(offset);
          await tester.pump();
          await testGesture.up();
          await tester.pump(kDoubleTapTimeout);

          // Ensure only the first header is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
            ),
          );
        });

        testWidgetsOnArbitraryDesktop('at extent (dragging upstream)', (tester) async {
          await _buildToggleableTestApp(tester);

          // Store the offset of the first child component. This component will be hidden
          // when the group collapses.
          final hiddenComponentOffset = SuperEditorInspector.findComponentOffset('1.1', Alignment.center);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Start dragging from the end of the last level one header.
          final testGesture = await tester.startDocumentDragFromPosition(
            from: const DocumentPosition(
              nodeId: '4',
              nodePosition: TextNodePosition(offset: 16),
            ),
          );

          // Drag up to the position where the hidden component was.
          await testGesture.moveTo(hiddenComponentOffset);
          await tester.pump();
          await testGesture.up();
          await tester.pump(kDoubleTapTimeout);

          // Ensure only the last header is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 16),
                ),
                extent: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );
        });

        testWidgetsOnArbitraryDesktop('at base (dragging downstream)', (tester) async {
          await _buildToggleableTestApp(tester);

          // Store the offset of the first child component. This component will be hidden
          // when the group collapses.
          final hiddenComponentOffset = SuperEditorInspector.findComponentOffset('1.1', Alignment.topLeft);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Start dragging from the position where the hidden component was.
          final testGesture = await tester.startGesture(
            hiddenComponentOffset,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump();

          // Move a tiny amount to start the pan gesture.
          await testGesture.moveBy(const Offset(2, 2));
          await tester.pump();

          // Drag to the end of the last header.
          await testGesture.moveTo(
            SuperEditorInspector.findComponentOffset('4', Alignment.bottomRight),
          );
          await tester.pump();
          await testGesture.up();
          await tester.pump(kDoubleTapTimeout);

          // Ensure only the last header is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 16),
                ),
              ),
            ),
          );
        });

        testWidgetsOnArbitraryDesktop('at base (dragging upstream)', (tester) async {
          await _buildToggleableTestApp(tester);

          // Store the offset of last child component. This component will be hidden
          // when the group collapses.
          final hiddenComponentOffset = SuperEditorInspector.findComponentOffset('4.1', Alignment.bottomRight);

          // Collapse the last header.
          await pressToggleButton(tester, '4');

          // Start dragging from the position where the hidden component was.
          final testGesture = await tester.startGesture(
            hiddenComponentOffset,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump();

          // Move a tiny amount to start the pan gesture.
          await testGesture.moveBy(const Offset(2, 2));
          await tester.pump();

          // Drag to beginning end of the last header.
          await testGesture.moveTo(
            SuperEditorInspector.findComponentOffset('4', Alignment.topLeft),
          );
          await tester.pump();
          await testGesture.up();
          await tester.pump(kDoubleTapTimeout);

          // Ensure only the last header is selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 16),
                ),
                extent: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );
        });
      });

      group('selects a collapsed component', () {
        testWidgetsOnArbitraryDesktop('when selecting surrounding components (dragging downstream)', (tester) async {
          await _buildToggleableTestApp(tester);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Start dragging from the beginning of the document.
          final testGesture = await tester.startDocumentDragFromPosition(
            from: const DocumentPosition(
              nodeId: '0',
              nodePosition: TextNodePosition(offset: 0),
            ),
          );

          // Drag down to the end of the last header.
          await testGesture.moveTo(SuperEditorInspector.findComponentOffset('4', Alignment.bottomRight));
          await tester.pump();
          await testGesture.up();
          await tester.pump(kDoubleTapTimeout);

          // Ensure the whole range was selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '0',
                  nodePosition: TextNodePosition(offset: 0),
                ),
                extent: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 16),
                ),
              ),
            ),
          );
        });

        testWidgetsOnArbitraryDesktop('when selecting surrounding components (dragging upstream)', (tester) async {
          await _buildToggleableTestApp(tester);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Start dragging from the end of the last header.
          final testGesture = await tester.startDocumentDragFromPosition(
            from: const DocumentPosition(
              nodeId: '4',
              nodePosition: TextNodePosition(offset: 16),
            ),
          );

          // Drag up to the beginning of the document.
          await testGesture.moveTo(SuperEditorInspector.findComponentOffset('0', Alignment.topLeft));
          await tester.pump();
          await testGesture.up();
          await tester.pump(kDoubleTapTimeout);

          // Ensure the whole range was selected.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 16),
                ),
                extent: DocumentPosition(
                  nodeId: '0',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );
        });
      });
    });

    group('keyboard navigation', () {
      group('skips collapsed components', () {
        testWidgetsOnDesktop('when moving down with ARROW DOWN', (tester) async {
          await _buildToggleableTestApp(tester);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Place the caret at the beginning of the first header.
          await tester.placeCaretInParagraph('1', 0);

          // Move the caret down.
          await tester.pressDownArrow();

          // Ensure the caret skipped the collapsed components and
          // was placed at the beginning of the next header.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('when moving down with ARROW RIGHT at the end of a node', (tester) async {
          await _buildToggleableTestApp(tester);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Place the caret at the end of the first header.
          await tester.placeCaretInParagraph('1', 8);

          // Move the caret down.
          await tester.pressRightArrow();

          // Ensure the caret skipped the collapsed components and
          // was placed at the beginning of the next header.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '4',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('when moving up with ARROW UP', (tester) async {
          await _buildToggleableTestApp(tester);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Place the caret at the beginning of the last header.
          await tester.placeCaretInParagraph('4', 0);

          // Move the caret up.
          await tester.pressUpArrow();

          // Ensure the caret skipped the collapsed components and
          // was placed at the beginning of the first header.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );
        });

        testWidgetsOnDesktop('when moving up with ARROW LEFT at the beginning of a node', (tester) async {
          await _buildToggleableTestApp(tester);

          // Collapse the first header.
          await pressToggleButton(tester, '1');

          // Place the caret at the beginning of the last header.
          await tester.placeCaretInParagraph('4', 0);

          // Move the caret up.
          await tester.pressLeftArrow();

          // Ensure the caret skipped the collapsed components and
          // was placed at the beginning of the first header.
          expect(
            SuperEditorInspector.findDocumentSelection(),
            selectionEquivalentTo(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 8),
                ),
              ),
            ),
          );
        });
      });
    });

    group('is adjusted when toggled > ', () {
      testWidgetsOnArbitraryDesktop('when extent is collapsed (downstream)', (tester) async {
        await _buildToggleableTestApp(tester);

        await tester.dragSelectDocumentFromPositionToPosition(
          from: const DocumentPosition(
            nodeId: '1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          to: const DocumentPosition(
            nodeId: '3',
            nodePosition: TextNodePosition(offset: 8),
          ),
        );

        // Collapse the first header.
        await pressToggleButton(tester, '1');

        // Ensure the extent moved to the end of the header.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          ),
        );
      });

      testWidgetsOnArbitraryDesktop('when extent is collapsed (upstream)', (tester) async {
        await _buildToggleableTestApp(tester);

        // Select the text from the end of the last header to the beginning of the last
        // child node which will be collapsed.
        await tester.dragSelectDocumentFromPositionToPosition(
          from: const DocumentPosition(
            nodeId: '4',
            nodePosition: TextNodePosition(offset: 16),
          ),
          to: const DocumentPosition(
            nodeId: '3.2',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        // Collapse the first header.
        await pressToggleButton(tester, '1');

        // Ensure the extent moved to the beginning of the last header.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '4',
                nodePosition: TextNodePosition(offset: 16),
              ),
              extent: DocumentPosition(
                nodeId: '4',
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
          ),
        );
      });

      testWidgetsOnArbitraryDesktop('when base is collapsed (downstream)', (tester) async {
        await _buildToggleableTestApp(tester);

        // Select from the first child of the first header to the end of the last header.
        await tester.dragSelectDocumentFromPositionToPosition(
          from: const DocumentPosition(
            nodeId: '1.1',
            nodePosition: TextNodePosition(offset: 0),
          ),
          to: const DocumentPosition(
            nodeId: '4',
            nodePosition: TextNodePosition(offset: 16),
          ),
        );

        // Collapse the first header.
        await pressToggleButton(tester, '1');

        // Ensure the base moved to the beginning of the last header.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '4',
                nodePosition: TextNodePosition(offset: 0),
              ),
              extent: DocumentPosition(
                nodeId: '4',
                nodePosition: TextNodePosition(offset: 16),
              ),
            ),
          ),
        );
      });

      testWidgetsOnArbitraryDesktop('when base is collapsed (upstream)', (tester) async {
        await _buildToggleableTestApp(tester);

        // Select from the end of the first child of the first header to the beginning of
        // the first regular paragraph.
        await tester.dragSelectDocumentFromPositionToPosition(
          from: const DocumentPosition(
            nodeId: '1.1',
            nodePosition: TextNodePosition(offset: 9),
          ),
          to: const DocumentPosition(
            nodeId: '0',
            nodePosition: TextNodePosition(offset: 0),
          ),
        );

        // Collapse the first header.
        await pressToggleButton(tester, '1');

        // Ensure the base moved to the end of the group header.
        expect(
          SuperEditorInspector.findDocumentSelection(),
          selectionEquivalentTo(
            const DocumentSelection(
              base: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
              extent: DocumentPosition(
                nodeId: '0',
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
          ),
        );
      });
    });
  });
}

Future<Editor> _buildToggleableTestApp(
  WidgetTester tester, {
  MutableDocument? document,
}) async {
  final effectiveDocument = document ??
      MutableDocument(nodes: [
        ParagraphNode(
          id: '0',
          text: AttributedText('Regular Paragraph'),
        ),
        ParagraphNode(
          id: '1',
          text: AttributedText('Header 1'),
          metadata: {NodeMetadata.blockType: header1Attribution},
        ),
        ParagraphNode(
          id: '1.1',
          text: AttributedText('Some text'),
        ),
        ParagraphNode(
          id: '2',
          text: AttributedText('Header 2'),
          metadata: {NodeMetadata.blockType: header2Attribution},
        ),
        ParagraphNode(
          id: '3',
          text: AttributedText('Header 3'),
          metadata: {NodeMetadata.blockType: header3Attribution},
        ),
        ParagraphNode(
          id: '3.1',
          text: AttributedText('Another text'),
        ),
        ParagraphNode(
          id: '3.2',
          text: AttributedText('Another text'),
        ),
        ParagraphNode(
          id: '4',
          text: AttributedText('Another Header 1'),
          metadata: {NodeMetadata.blockType: header1Attribution},
        ),
        ParagraphNode(
          id: '4.1',
          text: AttributedText('Another text'),
        ),
      ]);
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: effectiveDocument, composer: composer);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SuperEditor(
            editor: editor,
            groupBuilders: [
              HeaderGroupBuilder(
                editor: editor,
              )
            ],
          ),
        ),
      ),
    ),
  );

  return editor;
}

Future<void> pressToggleButton(
  WidgetTester tester,
  String nodeId, [
  Finder? superEditorFinder,
]) async {
  final documentLayout = SuperEditorInspector.findDocumentLayout(superEditorFinder);

  final componentState = documentLayout.getComponentByNodeId(nodeId) as State;

  // Find the group where the component is located.
  final groupFinder = find.ancestor(
    of: find.byKey(componentState.widget.key!),
    matching: find.byType(ToggleableGroup),
  );

  // Find the toggle button inside the group.
  //
  // For some reason, when there are nested groups, the last one
  // is the toggle for the group. Probably because the parent group
  // places the toggle button above all the other groups.
  final toggleButtonFinder = find
      .descendant(
        of: groupFinder,
        matching: find.byIcon(Icons.arrow_right),
      )
      .last;

  // Simulate the tap manually because we need to hover over the
  // button to make it visible.
  final testPointer = TestPointer(1, PointerDeviceKind.mouse);

  // Hover over the toggle button to make it visible.
  await tester.sendEventToBinding(
    testPointer.hover(tester.getCenter(toggleButtonFinder)),
  );
  await tester.pumpAndSettle();

  // Press the button.
  await tester.sendEventToBinding(
    testPointer.down(tester.getCenter(toggleButtonFinder)),
  );
  await tester.pumpAndSettle();

  // Release the button.
  await tester.sendEventToBinding(testPointer.up());
  await tester.pumpAndSettle();
}
