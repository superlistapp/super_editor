import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/box_component.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';

@immutable
class TableBlockNode extends BlockNode {
  TableBlockNode({
    required this.id,
    required List<List<TextNode>> rows,
    super.metadata,
  }) : _rows = List.from(rows.map((row) => List<TextNode>.from(row))) {
    initAddToMetadata({"blockType": const NamedAttribution("tableBlock")});
  }

  List<List<TextNode>> get rows => UnmodifiableListView(_rows);
  final List<List<TextNode>> _rows;

  List<TextNode> getRow(int index) {
    if (index < 0 || index >= _rows.length) {
      throw RangeError.range(index, 0, _rows.length - 1, 'index');
    }
    return UnmodifiableListView(_rows[index]);
  }

  List<TextNode> getColumn(int index) {
    if (_rows.isEmpty || index < 0 || index >= _rows[0].length) {
      throw RangeError.range(index, 0, _rows[0].length - 1, 'index');
    }
    return UnmodifiableListView(_rows.map((row) => row[index]));
  }

  TextNode getCell(int rowIndex, int cellIndex) {
    if (rowIndex < 0 || rowIndex >= _rows.length) {
      throw RangeError.range(rowIndex, 0, _rows.length - 1, 'rowIndex');
    }
    final row = _rows[rowIndex];
    if (cellIndex < 0 || cellIndex >= row.length) {
      throw RangeError.range(cellIndex, 0, row.length - 1, 'cellIndex');
    }
    return row[cellIndex];
  }

  @override
  final String id;

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return TableBlockNode(
      id: id,
      metadata: newMetadata,
      rows: _rows,
    );
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return TableBlockNode(
      id: id,
      rows: _rows,
      metadata: {
        ...metadata,
        ...newProperties,
      },
    );
  }

  @override
  String? copyContent(NodeSelection selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      // We don't know how to handle this selection type.
      return null;
    }
    if (selection.isCollapsed) {
      // This selection doesn't include the table - it's a collapsed selection
      // either on the upstream or downstream edge.
      return null;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (i > 0) {
        // Separate rows with a newline.
        buffer.write('\n');
      }

      for (int j = 0; j < row.length; j++) {
        final cell = row[j];
        if (j > 0) {
          // Separate cells with a tab.
          buffer.write('\t');
        }

        buffer.write(cell.text.toPlainText(includePlaceholders: false));
      }
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableBlockNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          const DeepCollectionEquality().equals(_rows, other._rows) &&
          metadata == other.metadata;

  @override
  int get hashCode => id.hashCode ^ _rows.hashCode ^ metadata.hashCode;
}
