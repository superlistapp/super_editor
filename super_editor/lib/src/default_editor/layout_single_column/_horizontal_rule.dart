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

class HorizontalRuleComponentMetadata implements ComponentViewModel {
  const HorizontalRuleComponentMetadata({
    required this.nodeId,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
  });

  @override
  final String nodeId;
  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final UpstreamDownstreamNodePosition? caret;
  final Color caretColor;

  HorizontalRuleComponentMetadata copyWith({
    UpstreamDownstreamNodeSelection? selection,
    Color? selectionColor,
    UpstreamDownstreamNodePosition? caret,
    Color? caretColor,
  }) {
    return HorizontalRuleComponentMetadata(
      nodeId: nodeId,
      selection: selection ?? this.selection,
      selectionColor: selectionColor ?? this.selectionColor,
      caret: caret ?? this.caret,
      caretColor: caretColor ?? this.caretColor,
    );
  }
}
