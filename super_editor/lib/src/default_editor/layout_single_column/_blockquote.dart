import 'package:flutter/widgets.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '_presenter.dart';

Widget? blockquoteComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
  if (componentViewModel is! BlockquoteComponentViewModel) {
    return null;
  }

  return BlockquoteComponent(
    textKey: componentContext.componentKey,
    text: componentViewModel.text,
    styleBuilder: componentViewModel.textStyleBuilder,
    backgroundColor: componentViewModel.backgroundColor,
    borderRadius: componentViewModel.borderRadius,
    textSelection: componentViewModel.selection,
    selectionColor: componentViewModel.selectionColor,
    showCaret: componentViewModel.caret != null,
    caretColor: componentViewModel.caretColor,
  );
}

class BlockquoteComponentViewModel extends SingleColumnLayoutComponentViewModel {
  const BlockquoteComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    required this.backgroundColor,
    required this.borderRadius,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
    this.highlightWhenEmpty = false,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  final AttributedText text;
  final AttributionStyleBuilder textStyleBuilder;
  final TextDirection textDirection;
  final TextAlign textAlignment;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final TextSelection? selection;
  final Color selectionColor;
  final TextPosition? caret;
  final Color caretColor;
  final bool highlightWhenEmpty;

  BlockquoteComponentViewModel copyWith({
    String? nodeId,
    double? maxWidth,
    EdgeInsetsGeometry? padding,
    AttributedText? text,
    AttributionStyleBuilder? textStyleBuilder,
    TextDirection? textDirection,
    TextAlign? textAlignment,
    Color? backgroundColor,
    BorderRadius? borderRadius,
    TextSelection? selection,
    Color? selectionColor,
    TextPosition? caret,
    Color? caretColor,
    bool? highlightWhenEmpty,
  }) {
    return BlockquoteComponentViewModel(
      nodeId: nodeId ?? this.nodeId,
      maxWidth: maxWidth ?? this.maxWidth,
      padding: padding ?? this.padding,
      text: text ?? this.text,
      textStyleBuilder: textStyleBuilder ?? this.textStyleBuilder,
      textDirection: textDirection ?? this.textDirection,
      textAlignment: textAlignment ?? this.textAlignment,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
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
      super == other &&
          other is BlockquoteComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          text == other.text &&
          textStyleBuilder == other.textStyleBuilder &&
          textDirection == other.textDirection &&
          textAlignment == other.textAlignment &&
          backgroundColor == other.backgroundColor &&
          borderRadius == other.borderRadius &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          caret == other.caret &&
          caretColor == other.caretColor &&
          highlightWhenEmpty == other.highlightWhenEmpty;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      text.hashCode ^
      textStyleBuilder.hashCode ^
      textDirection.hashCode ^
      textAlignment.hashCode ^
      backgroundColor.hashCode ^
      borderRadius.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      caret.hashCode ^
      caretColor.hashCode ^
      highlightWhenEmpty.hashCode;
}
