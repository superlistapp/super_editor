import 'package:super_editor/super_editor.dart';
import 'package:super_editor_quill/src/delta_position_figure_outer.dart';
import 'package:test/test.dart';

void main() {
  group('DeltaPositionFigureOuter', () {
    test('description', () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(
            id: 'node-1',
            text: AttributedText('abc'),
          ),
          ParagraphNode(
            id: 'node-1',
            text: AttributedText('def'),
          ),
        ],
      );
      const figureOuter = DeltaPositionFigureOuter();
      expect(figureOuter.isAtTheEndOfABlock(document, 0), false);
      expect(figureOuter.isAtTheEndOfABlock(document, 1), false);
      expect(figureOuter.isAtTheEndOfABlock(document, 2), false);
      expect(figureOuter.isAtTheEndOfABlock(document, 3), true);
      expect(figureOuter.isAtTheEndOfABlock(document, 4), false);
      expect(figureOuter.isAtTheEndOfABlock(document, 5), false);
      expect(figureOuter.isAtTheEndOfABlock(document, 6), false);
      expect(figureOuter.isAtTheEndOfABlock(document, 7), true);
    });
  });
}
