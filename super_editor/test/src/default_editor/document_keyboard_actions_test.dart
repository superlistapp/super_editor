import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';
import 'package:super_editor/super_editor.dart';

import '../_document_test_tools.dart';
import '../_text_entry_test_tools.dart';
import '../infrastructure/_platform_test_tools.dart';
import '../../super_editor/test_documents.dart';

void main() {
  group(
    'Document keyboard actions',
    () {
      group('jumps to', () {
        testWidgets('beginning of line with CMD + LEFT ARROW', (tester) async {
          Platform.setTestInstance(MacPlatform());

          // Start the user's selection somewhere after the beginning of the first
          // line in the first node.
          final editContext = await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCmdLeftArrow();

          // Ensure that the caret moved to the beginning of the line.
          expect(
            editContext.composer.selection,
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });

        testWidgets('end of line with CMD + RIGHT ARROW', (tester) async {
          Platform.setTestInstance(MacPlatform());

          // Start the user's selection somewhere before the end of the first line
          // in the first node.
          final editContext = await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressCmdRightArrow();

          // Ensure that the caret moved to the end of the line. This value
          // is very fragile. If the text size or layout width changes, this value
          // will also need to change.
          expect(
            editContext.composer.selection,
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 27),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });

        testWidgets('beginning of word with ALT + LEFT ARROW', (tester) async {
          Platform.setTestInstance(MacPlatform());

          // Start the user's selection somewhere in the middle of a word.
          final editContext = await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltLeftArrow();

          // Ensure that the caret moved to the beginning of the word.
          expect(
            editContext.composer.selection,
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 6),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });

        testWidgets('end of word with ALT + RIGHT ARROW', (tester) async {
          Platform.setTestInstance(MacPlatform());

          // Start the user's selection somewhere in the middle of a word.
          final editContext = await _pumpCaretMovementTestSetup(tester, textOffsetInFirstNode: 8);

          await tester.pressAltRightArrow();

          // Ensure that the caret moved to the beginning of the word.
          expect(
            editContext.composer.selection,
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 11),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });
      });

      group(
        'CMD + A to select all',
        () {
          test(
            'it does nothing when meta key is pressed but A-key is not pressed',
            () {
              Platform.setTestInstance(MacPlatform());

              final editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyC,
                    physicalKey: PhysicalKeyboardKey.keyC,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'c',
                ),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);

              Platform.setTestInstance(null);
            },
          );

          test(
            'it does nothing when A-key is pressed but meta key is not pressed',
            () {
              Platform.setTestInstance(MacPlatform());

              final editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: false,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);

              Platform.setTestInstance(null);
            },
          );

          test(
            'it does nothing when CMD+A is pressed but the document is empty',
            () {
              Platform.setTestInstance(MacPlatform());

              final editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyEvent(
                    data: FakeRawKeyEventData(
                      logicalKey: LogicalKeyboardKey.keyA,
                      physicalKey: PhysicalKeyboardKey.keyA,
                      isMetaPressed: true,
                      isModifierKeyPressed: false,
                    ),
                    character: 'a'),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);

              Platform.setTestInstance(null);
            },
          );

          test(
            'it selects all when CMD+A is pressed with a single-node document',
            () {
              Platform.setTestInstance(MacPlatform());

              final editContext = createEditContext(
                document: MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: 'paragraph',
                      text: AttributedText(text: 'This is some text'),
                    ),
                  ],
                ),
              );
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              expect(result, ExecutionInstruction.haltExecution);
              expect(
                editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              );
              expect(
                editContext.composer.selection!.extent,
                const DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextNodePosition(offset: 'This is some text'.length),
                ),
              );

              Platform.setTestInstance(null);
            },
          );
          test(
            'it selects all when CMD+A is pressed with a two-node document',
            () {
              Platform.setTestInstance(MacPlatform());

              final editContext = createEditContext(
                document: MutableDocument(
                  nodes: [
                    ParagraphNode(
                      id: 'paragraph_1',
                      text: AttributedText(text: 'This is some text'),
                    ),
                    ParagraphNode(
                      id: 'paragraph_2',
                      text: AttributedText(text: 'This is some text'),
                    ),
                  ],
                ),
              );
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              expect(result, ExecutionInstruction.haltExecution);
              expect(
                editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'paragraph_1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              );
              expect(
                editContext.composer.selection!.extent,
                const DocumentPosition(
                  nodeId: 'paragraph_2',
                  nodePosition: TextNodePosition(offset: 'This is some text'.length),
                ),
              );

              Platform.setTestInstance(null);
            },
          );
          test(
            'it selects all when CMD+A is pressed with a three-node document',
            () {
              Platform.setTestInstance(MacPlatform());

              final editContext = createEditContext(
                document: MutableDocument(
                  nodes: [
                    ImageNode(
                      id: 'image_1',
                      imageUrl: 'https://fake.com/image/url.png',
                    ),
                    ParagraphNode(
                      id: 'paragraph',
                      text: AttributedText(text: 'This is some text'),
                    ),
                    ImageNode(
                      id: 'image_2',
                      imageUrl: 'https://fake.com/image/url.png',
                    ),
                  ],
                ),
              );
              var result = selectAllWhenCmdAIsPressed(
                editContext: editContext,
                keyEvent: const FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.keyA,
                    physicalKey: PhysicalKeyboardKey.keyA,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'a',
                ),
              );

              expect(result, ExecutionInstruction.haltExecution);
              expect(
                editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'image_1',
                  nodePosition: UpstreamDownstreamNodePosition.upstream(),
                ),
              );
              expect(
                editContext.composer.selection!.extent,
                const DocumentPosition(
                  nodeId: 'image_2',
                  nodePosition: UpstreamDownstreamNodePosition.downstream(),
                ),
              );

              Platform.setTestInstance(null);
            },
          );
        },
      );

      group('key pressed with selection', () {
        test('deletes selection if backspace is pressed', () {
          Platform.setTestInstance(MacPlatform());

          final editContext = createEditContext(
            document: MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(text: 'Text with [DELETEME] selection'),
                ),
              ],
            ),
            documentComposer: DocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          var result = anyCharacterOrDestructiveKeyToDeleteSelection(
            editContext: editContext,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.backspace,
                physicalKey: PhysicalKeyboardKey.backspace,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = editContext.editor.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [] selection');

          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });

        test('deletes selection if delete is pressed', () {
          Platform.setTestInstance(MacPlatform());

          final editContext = createEditContext(
            document: MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(text: 'Text with [DELETEME] selection'),
                ),
              ],
            ),
            documentComposer: DocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          var result = anyCharacterOrDestructiveKeyToDeleteSelection(
            editContext: editContext,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.delete,
                physicalKey: PhysicalKeyboardKey.delete,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = editContext.editor.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [] selection');

          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });

        test('deletes selection and inserts character', () {
          Platform.setTestInstance(MacPlatform());

          final editContext = createEditContext(
            document: MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(text: 'Text with [DELETEME] selection'),
                ),
              ],
            ),
            documentComposer: DocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          var result = anyCharacterOrDestructiveKeyToDeleteSelection(
            editContext: editContext,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.keyA,
                physicalKey: PhysicalKeyboardKey.keyA,
              ),
              character: 'a',
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = editContext.editor.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [a] selection');

          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 12),
                ),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });

        test('collapses selection if escape is pressed', () {
          Platform.setTestInstance(MacPlatform());

          final editContext = createEditContext(
            document: MutableDocument(
              nodes: [
                ParagraphNode(
                  id: '1',
                  text: AttributedText(text: 'Text with [SELECTME] selection'),
                ),
              ],
            ),
            documentComposer: DocumentComposer(
              initialSelection: const DocumentSelection(
                base: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 11),
                ),
                extent: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          final result = collapseSelectionWhenEscIsPressed(
            editContext: editContext,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.escape,
                physicalKey: PhysicalKeyboardKey.escape,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          // The text should remain the same
          final paragraph = editContext.editor.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [SELECTME] selection');

          // The selection should be collapsed
          expect(
            editContext.composer.selection,
            equals(
              const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: '1',
                  nodePosition: TextNodePosition(offset: 19),
                ),
              ),
            ),
          );

          Platform.setTestInstance(null);
        });
      });
      test('does nothing when escape is pressed if the selection is collapsed', () {
        Platform.setTestInstance(MacPlatform());

        final editContext = createEditContext(
          document: MutableDocument(
            nodes: [
              ParagraphNode(
                id: '1',
                text: AttributedText(text: 'This is some text'),
              ),
            ],
          ),
          documentComposer: DocumentComposer(
            initialSelection: const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          ),
        );

        final result = collapseSelectionWhenEscIsPressed(
          editContext: editContext,
          keyEvent: const FakeRawKeyEvent(
            data: FakeRawKeyEventData(
              logicalKey: LogicalKeyboardKey.escape,
              physicalKey: PhysicalKeyboardKey.escape,
            ),
          ),
        );

        // The handler should pass on do nothing when there is no selection.
        expect(result, ExecutionInstruction.continueExecution);

        // The text should remain the same
        final paragraph = editContext.editor.document.nodes.first as ParagraphNode;
        expect(paragraph.text.text, 'This is some text');

        // The selection should remain the same
        expect(
          editContext.composer.selection,
          equals(
            const DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: '1',
                nodePosition: TextNodePosition(offset: 8),
              ),
            ),
          ),
        );

        Platform.setTestInstance(null);
      });
    },
  );
}

/// Pumps a [SuperEditor] with a single-paragraph document, with focus, and returns
/// the associated [EditContext] for further inspection and control.
///
/// This particular setup is intended for caret movement testing within a single
/// paragraph node.
Future<EditContext> _pumpCaretMovementTestSetup(
  WidgetTester tester, {
  required int textOffsetInFirstNode,
}) async {
  final composer = DocumentComposer(
    initialSelection: DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: "1",
        nodePosition: TextNodePosition(offset: textOffsetInFirstNode),
      ),
    ),
  );
  final editContext = createEditContext(
    document: singleParagraphDoc(),
    documentComposer: composer,
  );

  final focusNode = FocusNode()..requestFocus();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          focusNode: focusNode,
          editor: editContext.editor,
          composer: composer,
        ),
      ),
    ),
  );

  return editContext;
}
