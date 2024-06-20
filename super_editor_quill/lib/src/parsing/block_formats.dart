import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/super_editor.dart';

/// A [BlockDeltaFormat] that applies a header block type to a paragraph.
class HeaderDeltaFormat extends FilterByNameBlockDeltaFormat {
  static const _header = "header";

  const HeaderDeltaFormat() : super(_header);

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);
    final level = value as int;

    return [
      ChangeParagraphBlockTypeRequest(
        nodeId: composer.selection!.extent.nodeId,
        blockType: _getHeaderAttribution(level),
      ),
    ];
  }

  Attribution _getHeaderAttribution(int level) {
    switch (level) {
      case 1:
        return header1Attribution;
      case 2:
        return header2Attribution;
      case 3:
        return header3Attribution;
      case 4:
        return header4Attribution;
      case 5:
        return header5Attribution;
      case 6:
      default:
        return header6Attribution;
    }
  }
}

/// A [BlockDeltaFormat] that applies a blockquote block type to a paragraph.
class BlockquoteDeltaFormat extends FilterByNameBlockDeltaFormat {
  static const _blockquote = "blockquote";

  const BlockquoteDeltaFormat() : super(_blockquote);

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    return [
      ChangeParagraphBlockTypeRequest(
        nodeId: composer.selection!.extent.nodeId,
        blockType: blockquoteAttribution,
      ),
    ];
  }
}

/// A [BlockDeltaFormat] that applies a code block type to a paragraph.
class CodeBlockDeltaFormat extends FilterByNameBlockDeltaFormat {
  static const _code = "code-block";

  const CodeBlockDeltaFormat() : super(_code);

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    // TODO: add support for recording the language of the code block, which comes from
    //       the value of the "code-block" property.
    return [
      ChangeParagraphBlockTypeRequest(
        nodeId: composer.selection!.extent.nodeId,
        blockType: codeAttribution,
      ),
    ];
  }
}

/// A [BlockDeltaFormat] that converts a paragraph to a list item or a task.
class ListDeltaFormat extends FilterByNameBlockDeltaFormat {
  static const _list = "list";
  static const _listOrdered = "ordered";
  static const _listUnordered = "bullet";

  const ListDeltaFormat() : super(_list);

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    if (_isTask(value as String)) {
      return [
        ConvertParagraphToTaskRequest(
          nodeId: composer.selection!.extent.nodeId,
          isComplete: _isChecked(value),
        ),
      ];
    }

    return [
      ConvertParagraphToListItemRequest(
        nodeId: composer.selection!.extent.nodeId,
        type: _getListType(value),
      ),
    ];
  }

  bool _isTask(String name) {
    return name == "checked" || name == "unchecked";
  }

  bool _isChecked(String name) {
    assert(_isTask(name));
    return name == "checked";
  }

  ListItemType _getListType(String name) {
    switch (name) {
      case _listOrdered:
        return ListItemType.ordered;
      case _listUnordered:
        return ListItemType.unordered;
      default:
        throw Exception("Unknown list item type: $name");
    }
  }
}

/// A [BlockDeltaFormat] that applies an alignment to a paragraph.
class AlignDeltaFormat extends FilterByNameBlockDeltaFormat {
  static const _align = "align";
  static const _alignLeft = "left";
  static const _alignCenter = "center";
  static const _alignRight = "right";
  static const _alignJustify = "justify";

  const AlignDeltaFormat() : super(_align);

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    return [
      ChangeParagraphAlignmentRequest(
        nodeId: composer.selection!.extent.nodeId,
        alignment: _getTextAlignment(value as String),
      ),
    ];
  }

  TextAlign _getTextAlignment(String name) {
    switch (name) {
      case _alignLeft:
        return TextAlign.start;
      case _alignCenter:
        return TextAlign.center;
      case _alignRight:
        return TextAlign.end;
      case _alignJustify:
        return TextAlign.justify;
      default:
        throw Exception("Unknown text alignment: $name");
    }
  }
}

/// A [BlockDeltaFormat] that applies an indent to a paragraph.
class IndentParagraphDeltaFormat extends FilterByNameBlockDeltaFormat {
  static const _indent = "indent";

  const IndentParagraphDeltaFormat() : super(_indent);

  @override
  List<EditRequest>? doApplyFormat(Editor editor, Object value) {
    final composer = editor.context.find<MutableDocumentComposer>(Editor.composerKey);

    return [
      SetParagraphIndentRequest(
        composer.selection!.extent.nodeId,
        level: value as int,
      ),
    ];
  }
}

/// A [BlockDeltaFormat] that filters out any operation that doesn't have
/// an attribute with the given [name].
abstract class FilterByNameBlockDeltaFormat implements BlockDeltaFormat {
  const FilterByNameBlockDeltaFormat(this.name);

  final String name;

  @override
  List<EditRequest>? applyTo(Operation operation, Editor editor) {
    if (!operation.hasAttribute(name)) {
      return null;
    }

    return doApplyFormat(editor, operation.attributes![name]);
  }

  @protected
  List<EditRequest>? doApplyFormat(Editor editor, Object value);
}

/// A block-level format for a text block, e.g., header, blockquote, code.
///
/// Given a Quill Delta text insertion operation, a [BlockDeltaFormat] inspects
/// the delta attributes for a given block format property. The [BlockDeltaFormat]
/// then returns the [EditRequest]s necessary to apply that block format to the
/// currently selected [DocumentNode] in the Super Editor [Document] (which is
/// available through the [Editor].
///
/// For example, a header block delta format might inspect the operation attributes
/// looking for the key "header". It finds the key "header" with a value of `1`,
/// signifying a "level 1 header". That block delta format then checks the [editor]
/// for the currently selected node. Finally, that block delta format assembles an
/// [EditRequest] to apply a [header1Attribution] to the currently selected
/// [ParagraphNode].
abstract interface class BlockDeltaFormat {
  List<EditRequest>? applyTo(Operation operation, Editor editor);
}
