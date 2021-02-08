import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../core/document/rich_text_document.dart';
import 'box_component.dart';

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
}

/// Displays a horizontal rule in a document.
class HorizontalRuleComponent extends StatelessWidget {
  const HorizontalRuleComponent({
    Key key,
    @required this.componentKey,
    this.color = Colors.grey,
    this.thickness = 1,
    this.selectedColor = Colors.blue,
    this.isSelected = false,
  }) : super(key: key);

  final GlobalKey componentKey;
  final Color color;
  final double thickness;
  final Color selectedColor;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return BoxComponent(
      key: componentKey,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: 1,
            color: isSelected ? selectedColor : Colors.transparent,
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
