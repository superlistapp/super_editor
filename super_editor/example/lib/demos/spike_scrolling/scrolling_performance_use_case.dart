import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class ScrollingPerformanceUseCase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SuperEditor.standard(
      // Roughly a 20 page document in a standard word editor
      editor: DocumentEditor(document: _createInitialDocument(250)),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    );
  }
}

MutableDocument _createInitialDocument(int size, [int fizz = 3, int buzz = 5]) {
  return MutableDocument(
    nodes: List.generate(size, (index) {
      if (index % fizz == 0 && index % buzz == 0) {
        return ImageNode(
          id: DocumentEditor.createNodeId(),
          imageUrl: 'https://i.imgur.com/fSZwM7G.jpg',
        );
      } else if (index % fizz == 0) {
        return ListItemNode.unordered(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text: 'This is an unordered list item',
          ),
        );
      } else if (index % buzz == 0) {
        return ListItemNode.ordered(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text: 'First thing to do',
          ),
        );
      }

      return ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              '$index. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      );
    }),
  );
}
