import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';
import 'package:super_editor/super_editor.dart';

import '../_document_test_tools.dart';
import '../_text_entry_test_tools.dart';
import '../infrastructure/_platform_test_tools.dart';

void main() {
  group(
    'document_keyboard_actions.dart',
    () {
      group(
        'CMD + A to select all',
        () {
          test(
            'it does nothing when meta key is pressed but A-key is not pressed',
            () {
              Platform.setTestInstance(MacPlatform());

              final _editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: _editContext,
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

              final _editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: _editContext,
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

              final _editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: _editContext,
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

              final _editContext = createEditContext(
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
                editContext: _editContext,
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
                _editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              );
              expect(
                _editContext.composer.selection!.extent,
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

              final _editContext = createEditContext(
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
                editContext: _editContext,
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
                _editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'paragraph_1',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              );
              expect(
                _editContext.composer.selection!.extent,
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

              final _editContext = createEditContext(
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
                editContext: _editContext,
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
                _editContext.composer.selection!.base,
                const DocumentPosition(
                  nodeId: 'image_1',
                  nodePosition: UpstreamDownstreamNodePosition.upstream(),
                ),
              );
              expect(
                _editContext.composer.selection!.extent,
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

          final _editContext = createEditContext(
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
            editContext: _editContext,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.backspace,
                physicalKey: PhysicalKeyboardKey.backspace,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = _editContext.editor.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [] selection');

          expect(
            _editContext.composer.selection,
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

          final _editContext = createEditContext(
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
            editContext: _editContext,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.delete,
                physicalKey: PhysicalKeyboardKey.delete,
              ),
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = _editContext.editor.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [] selection');

          expect(
            _editContext.composer.selection,
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

          final _editContext = createEditContext(
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
            editContext: _editContext,
            keyEvent: const FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.keyA,
                physicalKey: PhysicalKeyboardKey.keyA,
              ),
              character: 'a',
            ),
          );

          expect(result, ExecutionInstruction.haltExecution);

          final paragraph = _editContext.editor.document.nodes.first as ParagraphNode;
          expect(paragraph.text.text, 'Text with [a] selection');

          expect(
            _editContext.composer.selection,
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
      });
    },
  );
}
