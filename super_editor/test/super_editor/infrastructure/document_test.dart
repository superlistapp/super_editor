import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Document", () {
    group("nodes", () {
      group("equality", () {
        test("equivalent TextNodes are equal", () {
          expect(
            TextNode(
              id: '1',
              text: AttributedText(
                text: 'a',
                spans: AttributedSpans(),
              ),
            ),
            equals(
              TextNode(
                id: '1',
                text: AttributedText(
                  text: 'a',
                  spans: AttributedSpans(),
                ),
              ),
            ),
          );
        });

        test("different TextNodes are not equal", () {
          expect(
            TextNode(
                  id: '1',
                  text: AttributedText(
                    text: 'a',
                    spans: AttributedSpans(),
                  ),
                ) ==
                TextNode(
                  id: '1',
                  text: AttributedText(
                    text: 'b',
                    spans: AttributedSpans(),
                  ),
                ),
            isFalse,
          );
        });

        test("equivalent ParagraphNodes are equal", () {
          expect(
            ParagraphNode(
              id: '1',
              text: AttributedText(
                text: 'a',
                spans: AttributedSpans(),
              ),
            ),
            equals(
              ParagraphNode(
                id: '1',
                text: AttributedText(
                  text: 'a',
                  spans: AttributedSpans(),
                ),
              ),
            ),
          );
        });

        test("different ParagraphNodes are not equal", () {
          expect(
            ParagraphNode(
                  id: '1',
                  text: AttributedText(
                    text: 'a',
                    spans: AttributedSpans(),
                  ),
                ) ==
                ParagraphNode(
                  id: '1',
                  text: AttributedText(
                    text: 'b',
                    spans: AttributedSpans(),
                  ),
                ),
            isFalse,
          );
        });

        test("equivalent ListItemNodes are equal", () {
          expect(
            ListItemNode(id: '1', itemType: ListItemType.ordered, text: AttributedText(text: 'abcdefghij')),
            equals(
              ListItemNode(id: '1', itemType: ListItemType.ordered, text: AttributedText(text: 'abcdefghij')),
            ),
          );

          expect(
            ListItemNode(id: '1', itemType: ListItemType.unordered, text: AttributedText(text: 'abcdefghij')),
            equals(
              ListItemNode(id: '1', itemType: ListItemType.unordered, text: AttributedText(text: 'abcdefghij')),
            ),
          );
        });

        test("different ListItemNodes are not equal", () {
          expect(
            ListItemNode(id: '1', itemType: ListItemType.ordered, text: AttributedText(text: 'abcdefghij')) ==
                ListItemNode(id: '2', itemType: ListItemType.unordered, text: AttributedText(text: 'abcdefghij')),
            isFalse,
          );

          expect(
            ListItemNode(id: '1', itemType: ListItemType.unordered, text: AttributedText(text: 'abcdefghij')) ==
                ListItemNode(id: '2', itemType: ListItemType.ordered, text: AttributedText(text: 'abcdefghij')),
            isFalse,
          );
        });

        test("equivalent HorizontalRuleNodes are equal", () {
          expect(
            HorizontalRuleNode(id: '1'),
            equals(
              HorizontalRuleNode(id: '1'),
            ),
          );
        });

        test("different HorizontalRuleNodes are not equal", () {
          expect(
            HorizontalRuleNode(id: '1') == HorizontalRuleNode(id: '2'),
            isFalse,
          );
        });

        test("equivalent ImageNodes are equal", () {
          expect(
            ImageNode(id: '1', imageUrl: 'https://thisisnotreal.com'),
            equals(
              ImageNode(id: '1', imageUrl: 'https://thisisnotreal.com'),
            ),
          );
        });

        test("different ImageNodes are not equal", () {
          expect(
            ImageNode(id: '1', imageUrl: 'https://thisisnotreal1.com') ==
                ImageNode(id: '1', imageUrl: 'https://thisisnotreal2.com'),
            isFalse,
          );
        });
      });
    });
  });
}
