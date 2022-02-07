import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '_presenter.dart';

Widget? blockquoteComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentMetadata) {
  if (componentMetadata is! BlockquoteComponentMetadata) {
    return null;
  }

  return BlockquoteComponent(
    textKey: componentContext.componentKey,
    text: componentMetadata.text,
    styleBuilder: componentMetadata.textStyleBuilder,
    textSelection: componentMetadata.selection,
    selectionColor: componentMetadata.selectionColor,
    showCaret: componentMetadata.caret != null,
    caretColor: componentMetadata.caretColor,
  );
}

class BlockquoteComponentMetadata implements ComponentViewModel {
  const BlockquoteComponentMetadata({
    required this.nodeId,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
    this.highlightWhenEmpty = false,
  });

  @override
  final String nodeId;
  final AttributedText text;
  final AttributionStyleBuilder textStyleBuilder;
  final TextDirection textDirection;
  final TextAlign textAlignment;
  final TextSelection? selection;
  final Color selectionColor;
  final TextPosition? caret;
  final Color caretColor;
  final bool highlightWhenEmpty;

  BlockquoteComponentMetadata copyWith({
    String? nodeId,
    AttributedText? text,
    AttributionStyleBuilder? textStyleBuilder,
    TextDirection? textDirection,
    TextAlign? textAlignment,
    TextSelection? selection,
    Color? selectionColor,
    TextPosition? caret,
    Color? caretColor,
    bool? highlightWhenEmpty,
  }) {
    return BlockquoteComponentMetadata(
      nodeId: nodeId ?? this.nodeId,
      text: text ?? this.text,
      textStyleBuilder: textStyleBuilder ?? this.textStyleBuilder,
      textDirection: textDirection ?? this.textDirection,
      textAlignment: textAlignment ?? this.textAlignment,
      selection: selection ?? this.selection,
      selectionColor: selectionColor ?? this.selectionColor,
      caret: caret ?? this.caret,
      caretColor: caretColor ?? this.caretColor,
      highlightWhenEmpty: highlightWhenEmpty ?? this.highlightWhenEmpty,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockquoteComponentMetadata &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          text == other.text &&
          textStyleBuilder == other.textStyleBuilder &&
          textDirection == other.textDirection &&
          textAlignment == other.textAlignment &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          caret == other.caret &&
          caretColor == other.caretColor &&
          highlightWhenEmpty == other.highlightWhenEmpty;

  @override
  int get hashCode =>
      nodeId.hashCode ^
      text.hashCode ^
      textStyleBuilder.hashCode ^
      textDirection.hashCode ^
      textAlignment.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      caret.hashCode ^
      caretColor.hashCode ^
      highlightWhenEmpty.hashCode;
}
