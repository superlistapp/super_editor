import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '_presenter.dart';

Widget? paragraphComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentMetadata) {
  if (componentMetadata is! ParagraphComponentMetadata) {
    return null;
  }

  editorLayoutLog.fine("Building paragraph component for node: ${componentMetadata.nodeId}");

  if (componentMetadata.caret != null) {
    editorLayoutLog.finer(' - painting caret in paragraph');
  }

  if (componentMetadata.selection != null) {
    editorLayoutLog.finer(' - painting a text selection:');
    editorLayoutLog.finer('   base: ${componentMetadata.selection!.base}');
    editorLayoutLog.finer('   extent: ${componentMetadata.selection!.extent}');
  } else {
    editorLayoutLog.finer(' - not painting any text selection');
  }

  return TextComponent(
    key: componentContext.componentKey,
    text: componentMetadata.text,
    textStyleBuilder: componentMetadata.textStyleBuilder,
    metadata: componentMetadata.blockType != null
        ? {
            'blockType': componentMetadata.blockType,
          }
        : {},
    textAlign: componentMetadata.textAlignment,
    textDirection: componentMetadata.textDirection,
    textSelection: componentMetadata.selection,
    selectionColor: componentMetadata.selectionColor,
    showCaret: componentMetadata.caret != null,
    caretColor: componentMetadata.caretColor,
    highlightWhenEmpty: componentMetadata.highlightWhenEmpty,
  );
}

class ParagraphComponentMetadata implements ComponentViewModel {
  const ParagraphComponentMetadata({
    required this.nodeId,
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
  });

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

  ParagraphComponentMetadata copyWith({
    String? nodeId,
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
    return ParagraphComponentMetadata(
      nodeId: nodeId ?? this.nodeId,
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
      other is ParagraphComponentMetadata &&
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
