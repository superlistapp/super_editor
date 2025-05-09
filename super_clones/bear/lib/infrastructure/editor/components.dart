import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

const dashComponentBuilders = [
  DashListItemComponentBuilder(),
  ...defaultComponentBuilders,
];

class DashListItemComponentBuilder implements ComponentBuilder {
  const DashListItemComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ListItemNode) {
      return null;
    }
    if (node.type != ListItemType.unordered) {
      return null;
    }

    return UnorderedListItemComponentViewModel(
      nodeId: node.id,
      indent: node.indent,
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! UnorderedListItemComponentViewModel) {
      return null;
    }

    return UnorderedListItemComponent(
      componentKey: componentContext.componentKey,
      text: componentViewModel.text,
      styleBuilder: componentViewModel.textStyleBuilder,
      indent: componentViewModel.indent,
      indentCalculator: (TextStyle textStyle, int indent) {
        return (textStyle.fontSize! * 0.60) * 3 * (indent + 1);
      },
      dotStyle: const ListItemDotStyle(
        color: Colors.red,
        size: Size(6, 6),
      ),
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
      underlines: componentViewModel.createUnderlines(),
    );
  }
}
