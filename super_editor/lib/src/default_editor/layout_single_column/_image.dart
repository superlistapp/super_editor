import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '_layout.dart';
import '_presenter.dart';

Widget? imageComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentMetadata) {
  if (componentMetadata is! ImageComponentMetadata) {
    return null;
  }

  return ImageComponent(
    componentKey: componentContext.componentKey,
    imageUrl: componentMetadata.imageUrl,
    selection: componentMetadata.selection,
    selectionColor: componentMetadata.selectionColor,
    showCaret: componentMetadata.caret != null,
    caretColor: componentMetadata.caretColor,
  );
}

class ImageComponentMetadata extends SingleColumnDocumentLayoutComponentViewModel {
  const ImageComponentMetadata({
    required this.nodeId,
    double? maxWidth,
    required this.imageUrl,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
  }) : super(maxWidth: maxWidth);

  @override
  final String nodeId;
  final String imageUrl;
  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final UpstreamDownstreamNodePosition? caret;
  final Color caretColor;

  ImageComponentMetadata copyWith({
    double? maxWidth,
    String? imageUrl,
    UpstreamDownstreamNodeSelection? selection,
    Color? selectionColor,
    UpstreamDownstreamNodePosition? caret,
    Color? caretColor,
  }) {
    return ImageComponentMetadata(
      nodeId: nodeId,
      maxWidth: maxWidth ?? this.maxWidth,
      imageUrl: imageUrl ?? this.imageUrl,
      selection: selection ?? this.selection,
      selectionColor: selectionColor ?? this.selectionColor,
      caret: caret ?? this.caret,
      caretColor: caretColor ?? this.caretColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageComponentMetadata &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          imageUrl == other.imageUrl &&
          maxWidth == other.maxWidth &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          caret == other.caret &&
          caretColor == other.caretColor;

  @override
  int get hashCode =>
      nodeId.hashCode ^
      imageUrl.hashCode ^
      maxWidth.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      caret.hashCode ^
      caretColor.hashCode;
}
