import 'package:flutter/widgets.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '_presenter.dart';

Widget? horizontalRuleComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentMetadata) {
  if (componentMetadata is! HorizontalRuleComponentViewModel) {
    return null;
  }

  return HorizontalRuleComponent(
    componentKey: componentContext.componentKey,
    selection: componentMetadata.selection,
    selectionColor: componentMetadata.selectionColor,
    showCaret: componentMetadata.caret != null,
    caretColor: componentMetadata.caretColor,
  );
}

class HorizontalRuleComponentViewModel extends SingleColumnLayoutComponentViewModel {
  const HorizontalRuleComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final UpstreamDownstreamNodePosition? caret;
  final Color caretColor;

  HorizontalRuleComponentViewModel copyWith({
    double? maxWidth,
    EdgeInsetsGeometry? padding,
    UpstreamDownstreamNodeSelection? selection,
    Color? selectionColor,
    UpstreamDownstreamNodePosition? caret,
    Color? caretColor,
  }) {
    return HorizontalRuleComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth ?? this.maxWidth,
      padding: padding ?? this.padding,
      selection: selection ?? this.selection,
      selectionColor: selectionColor ?? this.selectionColor,
      caret: caret ?? this.caret,
      caretColor: caretColor ?? this.caretColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is HorizontalRuleComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          caret == other.caret &&
          caretColor == other.caretColor;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      caret.hashCode ^
      caretColor.hashCode;
}
