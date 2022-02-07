import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '_presenter.dart';

Widget? unorderedListItemComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentMetadata) {
  if (componentMetadata is! ListItemComponentMetadata) {
    return null;
  }

  if (componentMetadata.type != ListItemType.unordered) {
    return null;
  }

  return UnorderedListItemComponent(
    textKey: componentContext.componentKey,
    text: componentMetadata.text,
    styleBuilder: componentMetadata.textStyleBuilder,
    indent: componentMetadata.indent,
    textSelection: componentMetadata.selection,
    selectionColor: componentMetadata.selectionColor,
    showCaret: componentMetadata.caret != null,
    caretColor: componentMetadata.caretColor,
  );
}

Widget? newOrderedListItemBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentMetadata) {
  if (componentMetadata is! ListItemComponentMetadata) {
    return null;
  }

  if (componentMetadata.type != ListItemType.ordered) {
    return null;
  }

  return OrderedListItemComponent(
    textKey: componentContext.componentKey,
    indent: componentMetadata.indent,
    listIndex: componentMetadata.ordinalValue!,
    text: componentMetadata.text,
    styleBuilder: componentMetadata.textStyleBuilder,
    textSelection: componentMetadata.selection,
    selectionColor: componentMetadata.selectionColor,
    showCaret: componentMetadata.caret != null,
    caretColor: componentMetadata.caretColor,
  );
}

class ListItemComponentMetadata implements ComponentViewModel {
  const ListItemComponentMetadata({
    required this.nodeId,
    required this.type,
    this.ordinalValue,
    required this.indent,
    required this.text,
    required this.textStyleBuilder,
    this.textDirection = TextDirection.ltr,
    this.selection,
    required this.selectionColor,
    this.caret,
    required this.caretColor,
  });

  @override
  final String nodeId;
  final ListItemType type;
  final int? ordinalValue;
  final int indent;
  final AttributedText text;
  final AttributionStyleBuilder textStyleBuilder;
  final TextDirection textDirection;
  final TextSelection? selection;
  final Color selectionColor;
  final TextPosition? caret;
  final Color caretColor;

  ListItemComponentMetadata copyWith({
    String? nodeId,
    ListItemType? type,
    int? ordinalValue,
    int? indent,
    AttributedText? text,
    AttributionStyleBuilder? textStyleBuilder,
    TextDirection? textDirection,
    TextSelection? selection,
    Color? selectionColor,
    TextPosition? caret,
    Color? caretColor,
  }) {
    return ListItemComponentMetadata(
      nodeId: nodeId ?? this.nodeId,
      type: type ?? this.type,
      ordinalValue: ordinalValue ?? this.ordinalValue,
      indent: indent ?? this.indent,
      text: text ?? this.text,
      textStyleBuilder: textStyleBuilder ?? this.textStyleBuilder,
      textDirection: textDirection ?? this.textDirection,
      selection: selection ?? this.selection,
      selectionColor: selectionColor ?? this.selectionColor,
      caret: caret ?? this.caret,
      caretColor: caretColor ?? this.caretColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListItemComponentMetadata &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          type == other.type &&
          ordinalValue == other.ordinalValue &&
          indent == other.indent &&
          text == other.text &&
          textStyleBuilder == other.textStyleBuilder &&
          textDirection == other.textDirection &&
          selection == other.selection &&
          selectionColor == other.selectionColor &&
          caret == other.caret &&
          caretColor == other.caretColor;

  @override
  int get hashCode =>
      nodeId.hashCode ^
      type.hashCode ^
      ordinalValue.hashCode ^
      indent.hashCode ^
      text.hashCode ^
      textStyleBuilder.hashCode ^
      textDirection.hashCode ^
      selection.hashCode ^
      selectionColor.hashCode ^
      caret.hashCode ^
      caretColor.hashCode;
}
