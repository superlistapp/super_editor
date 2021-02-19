import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'styles.dart';

class HorizontalRuleNode with ChangeNotifier implements DocumentNode {
  HorizontalRuleNode({
    @required this.id,
  });

  final String id;

  BinaryPosition get beginningPosition => BinaryPosition.included();

  BinaryPosition get endPosition => BinaryPosition.included();

  BinarySelection computeSelection({
    @required dynamic base,
    @required dynamic extent,
  }) {
    return BinarySelection.all();
  }

  @override
  String copyContent(dynamic selection) {
    assert(selection is BinarySelection);

    return (selection as BinarySelection).position == BinaryPosition.included() ? '---' : null;
  }
}

/// Displays a horizontal rule in a document.
class HorizontalRuleComponent extends StatelessWidget {
  const HorizontalRuleComponent({
    Key key,
    @required this.componentKey,
    this.color = Colors.grey,
    this.thickness = 1,
    this.selectionColor = Colors.blue,
    this.isSelected = false,
  }) : super(key: key);

  final GlobalKey componentKey;
  final Color color;
  final double thickness;
  final Color selectionColor;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return BoxComponent(
      key: componentKey,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: 1,
            color: isSelected ? selectionColor : Colors.transparent,
          ),
        ),
        child: Divider(
          color: color,
          thickness: thickness,
        ),
      ),
    );
  }
}

Widget horizontalRuleBuilder(ComponentContext componentContext) {
  if (componentContext.currentNode is! HorizontalRuleNode) {
    return null;
  }

  final selection =
      componentContext.nodeSelection == null ? null : componentContext.nodeSelection.nodeSelection as BinarySelection;
  final isSelected = selection != null && selection.position.isIncluded;

  return HorizontalRuleComponent(
    componentKey: componentContext.componentKey,
    isSelected: isSelected,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
  );
}
