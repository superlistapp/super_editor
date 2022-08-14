import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'layout_single_column/layout_single_column.dart';

/// [DocumentNode] for a horizontal rule, which represents a full-width
/// horizontal separation in a document.
class HorizontalRuleNode extends BlockNode with ChangeNotifier {
  HorizontalRuleNode({
    required this.id,
  }) {
    putMetadataValue("blockType", const NamedAttribution("horizontalRule"));
  }

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

class HorizontalRuleComponentBuilder implements ComponentBuilder {
  const HorizontalRuleComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! HorizontalRuleNode) {
      return null;
    }

    return HorizontalRuleComponentViewModel(
      nodeId: node.id,
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! HorizontalRuleComponentViewModel) {
      return null;
    }

    return HorizontalRuleComponent(
      componentKey: componentContext.componentKey,
      styledSelections: componentViewModel.styledSelections,
    );
  }
}

class HorizontalRuleComponentViewModel extends SingleColumnLayoutComponentViewModel {
  HorizontalRuleComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    List<StyledSelection<UpstreamDownstreamNodeSelection>>? styledSelections,
  })  : styledSelections = styledSelections ?? [],
        super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  List<StyledSelection<UpstreamDownstreamNodeSelection>> styledSelections;

  @override
  HorizontalRuleComponentViewModel copy() {
    return HorizontalRuleComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      styledSelections: List.from(styledSelections),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is HorizontalRuleComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          const DeepCollectionEquality().equals(styledSelections, other.styledSelections);

  @override
  int get hashCode => super.hashCode ^ nodeId.hashCode ^ styledSelections.hashCode;
}

/// Displays a horizontal rule in a document.
class HorizontalRuleComponent extends StatelessWidget {
  const HorizontalRuleComponent({
    Key? key,
    required this.componentKey,
    this.color = Colors.grey,
    this.thickness = 1,
    this.styledSelections = const [],
  }) : super(key: key);

  final GlobalKey componentKey;
  final Color color;
  final double thickness;
  final List<StyledSelection<UpstreamDownstreamNodeSelection>> styledSelections;

  @override
  Widget build(BuildContext context) {
    return SelectableBox(
      styledSelections: styledSelections,
      child: BoxComponent(
        key: componentKey,
        child: Divider(
          color: color,
          thickness: thickness,
        ),
      ),
    );
  }
}
