import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:uuid/uuid.dart';

import '../_document_test_tools.dart';
import '_text_entry_test_tools.dart';

void main() {
  group(
    'Select All with Shortcut',
    () {
      test(
        'CMD + C does nothing in selectAllWhenCmdAIsPressed',
        () {
          final _editContext = _createEditContext();
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
        'Key A click (without meta) does nothing with empty node list',
        () {
          final _editContext = _createEditContext();
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
        'CMD + A does nothing with empty node list',
        () {
          final _editContext = _createEditContext();
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
        'CMD + A selects single node from a one node list',
        () {
          final _editContext = _createEditContext(
            nodes: [
              _generateParagraphNode(),
            ],
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
              nodeId: _editContext.editor.document.nodes.first.id,
              nodePosition:
                  _editContext.editor.document.nodes.first.beginningPosition,
            ),
          );
          expect(
            _editContext.composer.selection!.extent,
            DocumentPosition(
              nodeId: _editContext.editor.document.nodes.last.id,
              nodePosition: _editContext.editor.document.nodes.last.endPosition,
            ),
          );
        },
      );
      test(
        'CMD + A selects two nodes (all nodes) from a two node list',
        () {
          final _editContext = _createEditContext(
            nodes: [
              _generateParagraphNode(),
              _generateParagraphNode(),
            ],
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
              nodeId: _editContext.editor.document.nodes.first.id,
              nodePosition:
                  _editContext.editor.document.nodes.first.beginningPosition,
            ),
          );
          expect(
            _editContext.composer.selection!.extent,
            DocumentPosition(
              nodeId: _editContext.editor.document.nodes.last.id,
              nodePosition: _editContext.editor.document.nodes.last.endPosition,
            ),
          );
        },
      );
      test(
        'CMD + A selects three nodes (all nodes) from a variety of nodes of 3 node items',
        () {
          final _editContext = _createEditContext(
            nodes: [
              _generateParagraphNode(),
              _generateParagraphNode(),
              HorizontalRuleNode(id: Uuid().v4()),
            ],
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
              nodeId: _editContext.editor.document.nodes.first.id,
              nodePosition:
                  _editContext.editor.document.nodes.first.beginningPosition,
            ),
          );
          expect(
            _editContext.composer.selection!.extent,
            DocumentPosition(
              nodeId: _editContext.editor.document.nodes.last.id,
              nodePosition: _editContext.editor.document.nodes.last.endPosition,
            ),
          );
        },
      );
      test(
        'CMD + A selects five nodes (all nodes) from a variety of nodes of 5 node items',
        () {
          final _editContext = _createEditContext(
            nodes: [
              ImageNode(id: Uuid().v4(), imageUrl: 'random_url'),
              _generateParagraphNode(),
              _generateParagraphNode(),
              HorizontalRuleNode(id: Uuid().v4()),
              ImageNode(id: Uuid().v4(), imageUrl: 'random_url'),
            ],
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
              nodeId: _editContext.editor.document.nodes.first.id,
              nodePosition:
                  _editContext.editor.document.nodes.first.beginningPosition,
            ),
          );
          expect(
            _editContext.composer.selection!.extent,
            DocumentPosition(
              nodeId: _editContext.editor.document.nodes.last.id,
              nodePosition: _editContext.editor.document.nodes.last.endPosition,
            ),
          );
        },
      );
    },
  );
}

EditContext _createEditContext({List<DocumentNode>? nodes}) {
  final document = MutableDocument(nodes: nodes ?? []);
  final documentEditor = DocumentEditor(document: document);
  final fakeLayout = FakeDocumentLayout();
  final composer = DocumentComposer();
  return EditContext(
    editor: documentEditor,
    getDocumentLayout: () => fakeLayout,
    composer: composer,
  );
}

ParagraphNode _generateParagraphNode() => ParagraphNode(
      id: Uuid().v4(),
      text: AttributedText(text: 'This is some text'),
    );
