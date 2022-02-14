import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '_presenter.dart';

Widget? horizontalRuleComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentMetadata) {
  if (componentMetadata is! HorizontalRuleComponentMetadata) {
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

class HorizontalRuleComponentMetadata extends SingleColumnLayoutComponentViewModel {
  const HorizontalRuleComponentMetadata({
    required this.nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
  }) : super(maxWidth: maxWidth, padding: padding);

  @override
  final String nodeId;
  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final UpstreamDownstreamNodePosition? caret;
  final Color caretColor;

  HorizontalRuleComponentMetadata copyWith({
    double? maxWidth,
    EdgeInsetsGeometry? padding,
    UpstreamDownstreamNodeSelection? selection,
    Color? selectionColor,
    UpstreamDownstreamNodePosition? caret,
    Color? caretColor,
  }) {
    return HorizontalRuleComponentMetadata(
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
          other is HorizontalRuleComponentMetadata &&
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
