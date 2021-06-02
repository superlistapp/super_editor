import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'styles.dart';

/// [DocumentNode] for a horizontal rule, which represents a full-width
/// horizontal separation in a document.
class HorizontalRuleNode with ChangeNotifier implements DocumentNode {
  HorizontalRuleNode({
    required this.id,
  });

  @override
  final String id;

  @override
  BinaryNodePosition get beginningPosition => BinaryNodePosition.included();

  @override
  BinaryNodePosition get endPosition => BinaryNodePosition.included();

  @override
  NodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position2 but received a ${position2.runtimeType}');
    }

    // BinaryNodePosition's don't disambiguate between upstream and downstream so
    // it doesn't matter which one we return.
    return position1;
  }

  @override
  NodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position2 but received a ${position2.runtimeType}');
    }

    // BinaryNodePosition's don't disambiguate between upstream and downstream so
    // it doesn't matter which one we return.
    return position1;
  }

  @override
  BinarySelection computeSelection({
    @required dynamic base,
    @required dynamic extent,
  }) {
    return BinarySelection.all();
  }

  @override
  String? copyContent(dynamic selection) {
    if (selection is! BinarySelection) {
      throw Exception('HorizontalRuleNode can only copy content from a BinarySelection.');
    }

    return selection.position == BinaryNodePosition.included() ? '---' : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is HorizontalRuleNode;
  }
}

/// Displays a horizontal rule in a document.
class HorizontalRuleComponent extends StatelessWidget {
  const HorizontalRuleComponent({
    Key? key,
    required this.componentKey,
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

/// Component builder that returns a [HorizontalRuleComponent] when
/// [componentContext.documentNode] is a [HorizontalRuleNode].
Widget? horizontalRuleBuilder(ComponentContext componentContext) {
  if (componentContext.documentNode is! HorizontalRuleNode) {
    return null;
  }

  final selection =
      componentContext.nodeSelection == null ? null : componentContext.nodeSelection!.nodeSelection as BinarySelection;
  final isSelected = selection != null && selection.position.isIncluded;

  return HorizontalRuleComponent(
    componentKey: componentContext.componentKey,
    isSelected: isSelected,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
  );
}
