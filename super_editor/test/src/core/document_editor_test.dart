import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('MutableDocument', () {
    test('it replaces one node by another ', () {
      final oldNode = ParagraphNode(id: 'old', text: AttributedText());
      final document = MutableDocument(
        nodes: [
          HorizontalRuleNode(id: '0'),
          oldNode,
          HorizontalRuleNode(id: '2'),
        ],
      );

      final newNode = ParagraphNode(id: 'new', text: AttributedText());
      document.replaceNode(oldNode: oldNode, newNode: newNode);

      // oldNode does not exist
      expect(document.nodes.contains(oldNode), false);
      // newNode exists at index 1
      expect(document.nodes.indexOf(newNode), 1);
    });

    test('it is equal to another document when both documents are empty', () {
      final document1 = MutableDocument(nodes: []);
      final document2 = MutableDocument(nodes: []);

      expect(document1 == document2, isTrue);
    });

    test(
        'it is equal to another document when each content node is equal to the corresponding node in the other document',
        () {
      final document1 = MutableDocument(nodes: [
        TextNode(
          id: '1',
          text: AttributedText(
            text: 'a',
            spans: AttributedSpans(),
          ),
        ),
      ]);
      final document2 = MutableDocument(nodes: [
        TextNode(
          id: '1',
          text: AttributedText(
            text: 'a',
            spans: AttributedSpans(),
          ),
        ),
      ]);

      expect(document1 == document2, isTrue);
    });

    test('it is NOT equal to a document with the same starting nodes but with additional nodes at the end', () {
      final document1 = MutableDocument(nodes: [HorizontalRuleNode(id: '1')]);
      final document2 = MutableDocument(nodes: [HorizontalRuleNode(id: '1'), HorizontalRuleNode(id: '2')]);

      expect(document1 == document2, isFalse);
    });

    test('it is NOT equal to a document when corresponding nodes are NOT equal', () {
      final document1 = MutableDocument(nodes: [HorizontalRuleNode(id: '1')]);
      final document2 = MutableDocument(nodes: [HorizontalRuleNode(id: '2')]);

      expect(document1 == document2, isFalse);
    });
  });
}
