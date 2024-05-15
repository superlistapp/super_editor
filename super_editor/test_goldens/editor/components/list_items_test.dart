import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

import '../../../test/super_editor/supereditor_test_tools.dart';
import '../../test_tools_goldens.dart';

Future<void> main() async {
  await loadAppFonts();

  group('SuperEditor > list items', () {
    group('unordered', () {
      testGoldensOnMac('aligns the dot vertically with the text', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  _createListItemNode(text: 'Font size of 8', fontSize: 8),
                  _createListItemNode(text: 'Font size of 10', fontSize: 10),
                  _createListItemNode(text: 'Font size of 12', fontSize: 12),
                  _createListItemNode(text: 'Font size of 14', fontSize: 14),
                  _createListItemNode(text: 'Font size of 16', fontSize: 16),
                  _createListItemNode(text: 'Font size of 18', fontSize: 18),
                  _createListItemNode(text: 'Font size of 24', fontSize: 24),
                  _createListItemNode(text: 'Font size of 40', fontSize: 40),
                ],
              ),
            )
            .useStylesheet(_createStylesheet())
            .pump();

        await screenMatchesGolden(tester, 'super_editor_list_item_unordered_aligns_dot_with_text_with_font_sizes');
      });

      testGoldensOnMac('aligns the dot vertically with the text with a line multiplier', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  _createListItemNode(text: 'Font size of 8', fontSize: 8),
                  _createListItemNode(text: 'Font size of 10', fontSize: 10),
                  _createListItemNode(text: 'Font size of 12', fontSize: 12),
                  _createListItemNode(text: 'Font size of 14', fontSize: 14),
                  _createListItemNode(text: 'Font size of 16', fontSize: 16),
                  _createListItemNode(text: 'Font size of 18', fontSize: 18),
                  _createListItemNode(text: 'Font size of 24', fontSize: 24),
                  _createListItemNode(text: 'Font size of 40', fontSize: 40),
                ],
              ),
            )
            .useStylesheet(_createStylesheet(lineHeightMultiplier: 3.0))
            .pump();

        await screenMatchesGolden(
            tester, 'super_editor_list_item_unordered_aligns_dot_with_text_with_font_sizes_and_line_multiplier');
      });
    });

    group('ordered', () {
      testGoldensOnMac('aligns the dot vertically with the text', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  _createListItemNode(text: 'Font size of 8', fontSize: 8, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 10', fontSize: 10, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 12', fontSize: 12, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 14', fontSize: 14, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 16', fontSize: 16, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 18', fontSize: 18, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 24', fontSize: 24, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 40', fontSize: 40, listItemType: ListItemType.ordered),
                ],
              ),
            )
            .useStylesheet(_createStylesheet())
            .pump();

        await screenMatchesGolden(tester, 'super_editor_list_item_ordered_aligns_dot_with_text_with_font_sizes');
      });

      testGoldensOnMac('aligns the dot vertically with the text with a line multiplier', (tester) async {
        await tester //
            .createDocument()
            .withCustomContent(
              MutableDocument(
                nodes: [
                  _createListItemNode(text: 'Font size of 8', fontSize: 8, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 10', fontSize: 10, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 12', fontSize: 12, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 14', fontSize: 14, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 16', fontSize: 16, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 18', fontSize: 18, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 24', fontSize: 24, listItemType: ListItemType.ordered),
                  _createListItemNode(text: 'Font size of 40', fontSize: 40, listItemType: ListItemType.ordered),
                ],
              ),
            )
            .useStylesheet(_createStylesheet(lineHeightMultiplier: 3.0))
            .pump();

        await screenMatchesGolden(
            tester, 'super_editor_list_item_ordered_aligns_dot_with_text_with_font_sizes_and_line_multiplier');
      });
    });
  });
}

ListItemNode _createListItemNode({
  required String text,
  required double fontSize,
  ListItemType listItemType = ListItemType.unordered,
}) {
  return ListItemNode(
    id: Editor.createNodeId(),
    itemType: listItemType,
    text: AttributedText(
      text,
      AttributedSpans(attributions: [
        SpanMarker(
          attribution: FontSizeAttribution(fontSize),
          offset: 0,
          markerType: SpanMarkerType.start,
        ),
        SpanMarker(
          attribution: FontSizeAttribution(fontSize),
          offset: text.length - 1,
          markerType: SpanMarkerType.end,
        ),
      ]),
    ),
  );
}

Stylesheet _createStylesheet({
  double lineHeightMultiplier = 1.0,
}) {
  return defaultStylesheet.copyWith(
    addRulesAfter: [
      StyleRule(
        BlockSelector.all,
        (doc, docNode) {
          return {
            Styles.textStyle: TextStyle(
              fontFamily: 'Roboto',
              height: lineHeightMultiplier,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          };
        },
      ),
    ],
  );
}
