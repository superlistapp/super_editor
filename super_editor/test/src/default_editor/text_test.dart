import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('text.dart', () {
    group('ToggleTextAttributionsCommand', () {
      test('it toggles selected text and nothing more', () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'paragraph',
              text: AttributedText(' make me bold '),
            )
          ],
        );
        final editor = DocumentEditor(document: document);

        final command = ToggleTextAttributionsCommand(
          documentSelection: const DocumentSelection(
            base: DocumentPosition(
              nodeId: 'paragraph',
              nodePosition: TextNodePosition(offset: 1),
            ),
            extent: DocumentPosition(
              nodeId: 'paragraph',
              // IMPORTANT: we want to end the bold at the 'd' character but
              // the TextPosition indexes the ' ' after the 'd'. This is because
              // TextPosition references the character after the selection, not
              // the last character in the selection. See the TextPosition class
              // definition for more information.
              nodePosition: TextNodePosition(offset: 13),
            ),
          ),
          attributions: {boldAttribution},
        );

        editor.executeCommand(command);

        final boldedText = (document.nodes.first as ParagraphNode).text;
        expect(boldedText.getAllAttributionsAt(0), <dynamic>{});
        expect(boldedText.getAllAttributionsAt(1), {boldAttribution});
        expect(boldedText.getAllAttributionsAt(12), {boldAttribution});
        expect(boldedText.getAllAttributionsAt(13), <dynamic>{});
      });
    });

    group('TextNode', () {
      group('computeSelection', () {
        test('throws if passed other types of NodePosition', () {
          final node = TextNode(
            id: 'text node',
            text: AttributedText('text'),
          );
          expect(
            () => node.computeSelection(
              base: const UpstreamDownstreamNodePosition.upstream(),
              extent: const UpstreamDownstreamNodePosition.downstream(),
            ),
            throwsAssertionError,
          );
        });

        test('preserves the affinity of extent', () {
          final node = TextNode(
            id: 'text node',
            text: AttributedText('text'),
          );

          final selectionWithUpstream = node.computeSelection(
            base: const TextNodePosition(
              offset: 0,
              affinity: TextAffinity.downstream,
            ),
            extent: const TextNodePosition(
              offset: 3,
              affinity: TextAffinity.upstream,
            ),
          );
          expect(selectionWithUpstream.affinity, TextAffinity.upstream);

          final selectionWithDownstream = node.computeSelection(
            base: const TextNodePosition(
              offset: 0,
              affinity: TextAffinity.upstream,
            ),
            extent: const TextNodePosition(
              offset: 3,
              affinity: TextAffinity.downstream,
            ),
          );
          expect(selectionWithDownstream.affinity, TextAffinity.downstream);
        });
      });
    });

    group('TextNodeSelection', () {
      group('get base', () {
        test('preserves affinity', () {
          const selectionWithUpstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.upstream);
          expect(selectionWithUpstream.base.affinity, TextAffinity.upstream);

          const selectionWithDownstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.downstream);
          expect(selectionWithDownstream.base.affinity, TextAffinity.downstream);
        });
      });

      group('get extent', () {
        test('preserves affinity', () {
          const selectionWithUpstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.upstream);
          expect(selectionWithUpstream.extent.affinity, TextAffinity.upstream);

          const selectionWithDownstream = TextNodeSelection.collapsed(offset: 0, affinity: TextAffinity.downstream);
          expect(selectionWithDownstream.extent.affinity, TextAffinity.downstream);
        });
      });
    });
  });
}
