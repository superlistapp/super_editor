import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '_presenter.dart';

Widget? paragraphComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentViewModel) {
  if (componentViewModel is! ParagraphComponentViewModel) {
    return null;
  }

  editorLayoutLog.fine("Building paragraph component for node: ${componentViewModel.nodeId}");

  if (componentViewModel.caret != null) {
    editorLayoutLog.finer(' - painting caret in paragraph');
  }

  if (componentViewModel.selection != null) {
    editorLayoutLog.finer(' - painting a text selection:');
    editorLayoutLog.finer('   base: ${componentViewModel.selection!.base}');
    editorLayoutLog.finer('   extent: ${componentViewModel.selection!.extent}');
  } else {
    editorLayoutLog.finer(' - not painting any text selection');
  }

  return TextComponent(
    key: componentContext.componentKey,
    text: componentViewModel.text,
    textStyleBuilder: componentViewModel.textStyleBuilder,
    metadata: componentViewModel.blockType != null
        ? {
            'blockType': componentViewModel.blockType,
          }
        : {},
    textAlign: componentViewModel.textAlignment,
    textDirection: componentViewModel.textDirection,
    textSelection: componentViewModel.selection,
    selectionColor: componentViewModel.selectionColor,
    showCaret: componentViewModel.caret != null,
    caretColor: componentViewModel.caretColor,
    highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
  );
}

class ParagraphComponentViewModel extends SingleColumnLayoutComponentViewModel {
  const ParagraphComponentViewModel({
    required this.nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    this.blockType,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
    this.highlightWhenEmpty = false,
  }) : super(maxWidth: maxWidth, padding: padding);

  @override
  final String nodeId;
  final Attribution? blockType;
  final AttributedText text;
  final AttributionStyleBuilder textStyleBuilder;
  final TextDirection textDirection;
  final TextAlign textAlignment;
  final TextSelection? selection;
  final Color selectionColor;
  final TextPosition? caret;
  final Color caretColor;
  final bool highlightWhenEmpty;

  ParagraphComponentViewModel copyWith({
    String? nodeId,
    double? maxWidth,
    EdgeInsetsGeometry? padding,
    Attribution? blockType,
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
    return ParagraphComponentViewModel(
      nodeId: nodeId ?? this.nodeId,
      maxWidth: maxWidth ?? this.maxWidth,
      padding: padding ?? this.padding,
      blockType: blockType ?? this.blockType,
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
      super == other &&
          other is ParagraphComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          blockType == other.blockType &&
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
      super.hashCode ^
      nodeId.hashCode ^
      blockType.hashCode ^
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
