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

    test('it is equal to a similar document with the same content', () {
      final node = HorizontalRuleNode(id: '0');

      final document1 = MutableDocument(nodes: [node]);
      final document2 = MutableDocument(nodes: [node]);

      expect(document1 == document2, isTrue);
    });

    test('it is NOT equal to a similar document with different content', () {
      final node = HorizontalRuleNode(id: '0');

      final document1 = MutableDocument(nodes: [node]);
      final document2 = MutableDocument(nodes: [node, node]);

      expect(document1 == document2, isFalse);
    });
  });
}
