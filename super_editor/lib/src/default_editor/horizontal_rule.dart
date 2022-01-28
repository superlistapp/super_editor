import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'styles.dart';

/// [DocumentNode] for a horizontal rule, which represents a full-width
/// horizontal separation in a document.
class HorizontalRuleNode extends BlockNode with ChangeNotifier {
  HorizontalRuleNode({
    required this.id,
  });

  @override
  final String id;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception('HorizontalRuleNode can only copy content from a UpstreamDownstreamNodeSelection.');
    }

    return !selection.isCollapsed ? '---' : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is HorizontalRuleNode;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HorizontalRuleNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
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

  final selection = componentContext.nodeSelection == null
      ? null
      : componentContext.nodeSelection!.nodeSelection as UpstreamDownstreamNodeSelection;
  final isSelected = selection != null && !selection.isCollapsed;

  return HorizontalRuleComponent(
    componentKey: componentContext.componentKey,
    isSelected: isSelected,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle?)?.selectionColor ??
        const Color(0x00000000),
  );
}
