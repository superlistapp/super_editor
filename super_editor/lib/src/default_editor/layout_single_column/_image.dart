import 'package:flutter/widgets.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '_presenter.dart';

Widget? imageComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentMetadata) {
  if (componentMetadata is! ImageComponentViewModel) {
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

class ImageComponentViewModel extends SingleColumnLayoutComponentViewModel {
  const ImageComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required this.imageUrl,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  final String imageUrl;
  final UpstreamDownstreamNodeSelection? selection;
  final Color selectionColor;
  final UpstreamDownstreamNodePosition? caret;
  final Color caretColor;

  ImageComponentViewModel copyWith({
    double? maxWidth,
    EdgeInsetsGeometry? padding,
    String? imageUrl,
    UpstreamDownstreamNodeSelection? selection,
    Color? selectionColor,
    UpstreamDownstreamNodePosition? caret,
    Color? caretColor,
  }) {
    return ImageComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth ?? this.maxWidth,
      padding: padding ?? this.padding,
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
      super == other &&
          other is ImageComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          imageUrl == other.imageUrl &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          caret == other.caret &&
          caretColor == other.caretColor;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      imageUrl.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      caret.hashCode ^
      caretColor.hashCode;
}
