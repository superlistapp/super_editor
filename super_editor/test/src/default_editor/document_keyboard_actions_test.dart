import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/document_interaction.dart';
import 'package:super_editor/src/default_editor/document_keyboard_actions.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '../_document_test_tools.dart';
import '../_text_entry_test_tools.dart';

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
              final _editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: _editContext,
                keyEvent: FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.meta,
                    physicalKey: PhysicalKeyboardKey.keyC,
                    isMetaPressed: true,
                    isModifierKeyPressed: false,
                  ),
                  character: 'c',
                ),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);
            },
          );

          test(
            'it does nothing when A-key is pressed but meta key is not pressed',
            () {
              final _editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: _editContext,
                keyEvent: FakeRawKeyEvent(
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
            },
          );

          test(
            'it does nothing when CMD+A is pressed but the document is empty',
            () {
              final _editContext = createEditContext(document: MutableDocument());
              var result = selectAllWhenCmdAIsPressed(
                editContext: _editContext,
                keyEvent: FakeRawKeyEvent(
                    data: FakeRawKeyEventData(
                      logicalKey: LogicalKeyboardKey.meta,
                      physicalKey: PhysicalKeyboardKey.keyA,
                      isMetaPressed: true,
                      isModifierKeyPressed: false,
                    ),
                    character: 'a'),
              );

              // The handler should pass on handling the key.
              expect(result, ExecutionInstruction.continueExecution);
            },
          );

          test(
            'it selects all when CMD+A is pressed with a single-node document',
            () {
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
                keyEvent: FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.meta,
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
                DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextPosition(offset: 0),
                ),
              );
              expect(
                _editContext.composer.selection!.extent,
                DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextPosition(offset: 'This is some text'.length),
                ),
              );
            },
          );
          test(
            'it selects all when CMD+A is pressed with a two-node document',
            () {
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
                keyEvent: FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.meta,
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
                DocumentPosition(
                  nodeId: 'paragraph_1',
                  nodePosition: TextPosition(offset: 0),
                ),
              );
              expect(
                _editContext.composer.selection!.extent,
                DocumentPosition(
                  nodeId: 'paragraph_2',
                  nodePosition: TextPosition(offset: 'This is some text'.length),
                ),
              );
            },
          );
          test(
            'it selects all when CMD+A is pressed with a three-node document',
            () {
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
                keyEvent: FakeRawKeyEvent(
                  data: FakeRawKeyEventData(
                    logicalKey: LogicalKeyboardKey.meta,
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
                DocumentPosition(
                  nodeId: 'image_1',
                  nodePosition: BinaryPosition.included(),
                ),
              );
              expect(
                _editContext.composer.selection!.extent,
                DocumentPosition(
                  nodeId: 'image_2',
                  nodePosition: BinaryPosition.included(),
                ),
              );
            },
          );
        },
      );
    },
  );
}
