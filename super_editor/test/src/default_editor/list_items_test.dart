import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';
import 'package:super_editor/src/infrastructure/platform_detector.dart';

import '../_document_test_tools.dart';
import '../_text_entry_test_tools.dart';
import '../infrastructure/_platform_test_tools.dart';

void main() {
  group('list_items.dart', () {
    group('Text entry', () {
      test(
        'it converts paragraph node to list node when "1. " is pressed',
        () {
          Platform.setTestInstance(MacPlatform());

          final _editContext = createEditContext(
            document: MutableDocument(
              nodes: [
                ParagraphNode(
                  id: 'paragraph',
                  text: AttributedText(text: ''),
                ),
              ],
            ),
            documentComposer: DocumentComposer(
              initialSelection: const DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: 'paragraph',
                  nodePosition: TextNodePosition(offset: 0),
                ),
              ),
            ),
          );

          const keyOrder = [
            FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.numpad1,
                physicalKey: PhysicalKeyboardKey.numpad1,
                isMetaPressed: false,
                isModifierKeyPressed: false,
              ),
              character: '1',
            ),
            FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.period,
                physicalKey: PhysicalKeyboardKey.period,
                isMetaPressed: false,
                isModifierKeyPressed: false,
              ),
              character: '.',
            ),
            FakeRawKeyEvent(
              data: FakeRawKeyEventData(
                logicalKey: LogicalKeyboardKey.space,
                physicalKey: PhysicalKeyboardKey.space,
                isMetaPressed: false,
                isModifierKeyPressed: false,
              ),
              character: ' ',
            ),
          ];

          for (final key in keyOrder) {
            anyCharacterToInsertInParagraph(
              editContext: _editContext,
              keyEvent: key,
            );
          }

          expect(_editContext.editor.document.nodes.first, isA<ListItemNode>());
          Platform.setTestInstance(null);
        },
      );
    });
  });
}
