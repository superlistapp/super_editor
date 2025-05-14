import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';

class TableNode extends GroupNode {
  TableNode.sparse(
    String id,
    this.cells,
  ) : super(id, cells.values.toList()) {
    print("Creating TableNode");
    // Compute the number of rows and columns.
    final rowIndices = <int>{};
    final columnIndices = <int>{};
    for (final cell in cells.keys) {
      rowIndices.add(cell.row);
      columnIndices.add(cell.col);
    }
    rowCount = rowIndices.length;
    columnCount = columnIndices.length;
    print("Done with TableNode constructor");
  }

  final Map<TableCellPosition, TableCellNode> cells;

  late final int rowCount;
  late final int columnCount;

  TableCellNode? getCellAt(TableCellPosition position) => cells[position];

  @override
  NodePosition get beginningPosition => TableNodePosition(
        (row: 0, col: 0),
        getCellAt((row: 0, col: 0))!.endPosition,
      );

  @override
  NodePosition get endPosition => CompositeNodePosition(
        compositeNodeId: id,
        childNodeId: _nodes.last.id,
        childNodePosition: _nodes.last.endPosition,
      );
}

/// A selection within a single [TableNode].
class TableNodeSelection implements NodeSelection {
  const TableNodeSelection.collapsed(
    TableNodePosition position,
  )   : base = position,
        extent = position;

  const TableNodeSelection({
    required this.base,
    required this.extent,
  });

  final TableNodePosition base;
  final TableNodePosition extent;
}

/// A singular position within a [TableNode].
class TableNodePosition implements NodePosition {
  const TableNodePosition(this.cell, this.cellPath);

  final TableCellPosition cell;
  final NodePath cellPath;

  @override
  bool isEquivalentTo(NodePosition other) {
    if (other is! TableNodePosition) {
      return false;
    }

    return cell == other.cell && cellPath == other.cellPath;
  }
}

typedef TableCellPosition = ({int row, int col});

class TableCellNode extends GroupNode {
  TableCellNode(super.id, super.nodes);
}

class TableComponentBuilder implements ComponentBuilder {
  const TableComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
    List<ComponentBuilder> componentBuilders,
  ) {
    if (node is! TableNode) {
      return null;
    }

    print("Creating TableViewModel");
    return TableViewModel(
      node: node,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! TableViewModel) {
      return null;
    }

    print("Creating TableComponent");
    return TableComponent(
      key: componentContext.componentKey,
      node: componentViewModel.node,
    );
  }
}

class TableViewModel extends SingleColumnLayoutComponentViewModel {
  TableViewModel({
    required this.node,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double? maxWidth,
  }) : super(nodeId: node.id, padding: padding, maxWidth: maxWidth);

  final TableNode node;

  @override
  TableViewModel copy() {
    return TableViewModel(
      node: node,
      padding: padding,
      maxWidth: maxWidth,
    );
  }
}

class TableComponent extends StatefulWidget {
  const TableComponent({
    super.key,
    required this.node,
  });

  final TableNode node;

  @override
  State<TableComponent> createState() => _TableComponentState();
}

class _TableComponentState extends State<TableComponent> with DocumentComponent {
  final _cellKeys = <List<GlobalKey>>[];

  @override
  void initState() {
    super.initState();

    for (int row = 0; row < widget.node.rowCount; row += 1) {
      for (int col = 0; col < widget.node.columnCount; col += 1) {
        if (row >= _cellKeys.length) {
          _cellKeys.add(<GlobalKey>[]);
        }
        if (col >= _cellKeys[row].length) {
          _cellKeys[row].add(GlobalKey(debugLabel: "Cell (row: $row, col: $col)"));
        }
      }
    }
  }

  @override
  NodePosition getBeginningPosition() {
    return widget.node.beginningPosition;
  }

  @override
  NodePosition getBeginningPositionNearX(double x) {
    // TODO: implement getBeginningPositionNearX
    throw UnimplementedError();
  }

  @override
  NodePosition getEndPosition() {
    return widget.node.endPosition;
  }

  @override
  NodePosition getEndPositionNearX(double x) {
    // TODO: implement getEndPositionNearX
    throw UnimplementedError();
  }

  @override
  NodeSelection getCollapsedSelectionAt(NodePosition nodePosition) {
    if (nodePosition is! TableNodePosition) {
      throw Exception('The given nodePosition ($nodePosition) is not compatible with TableComponent');
    }

    return TableNodeSelection.collapsed(nodePosition);
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    // TODO: implement getDesiredCursorAtOffset
    throw UnimplementedError();
  }

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) {
    // TODO: implement getEdgeForPosition
    throw UnimplementedError();
  }

  @override
  Offset getOffsetForPosition(NodePosition nodePosition) {
    // TODO: implement getOffsetForPosition
    throw UnimplementedError();
  }

  @override
  NodePosition? getPositionAtOffset(Offset localOffset) {
    // TODO: implement getPositionAtOffset
    throw UnimplementedError();
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    // TODO: implement getRectForPosition
    throw UnimplementedError();
  }

  @override
  Rect getRectForSelection(NodePosition baseNodePosition, NodePosition extentNodePosition) {
    // TODO: implement getRectForSelection
    throw UnimplementedError();
  }

  @override
  NodeSelection getSelectionBetween({required NodePosition basePosition, required NodePosition extentPosition}) {
    // TODO: implement getSelectionBetween
    throw UnimplementedError();
  }

  @override
  NodeSelection? getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    // TODO: implement getSelectionInRange
    throw UnimplementedError();
  }

  @override
  NodeSelection getSelectionOfEverything() {
    // TODO: implement getSelectionOfEverything
    throw UnimplementedError();
  }

  @override
  NodePosition? movePositionUp(NodePosition currentPosition) {
    // TODO: implement movePositionUp
    throw UnimplementedError();
  }

  @override
  NodePosition? movePositionDown(NodePosition currentPosition) {
    // TODO: implement movePositionDown
    throw UnimplementedError();
  }

  @override
  NodePosition? movePositionLeft(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    // TODO: implement movePositionLeft
    throw UnimplementedError();
  }

  @override
  NodePosition? movePositionRight(NodePosition currentPosition, [MovementModifier? movementModifier]) {
    // TODO: implement movePositionRight
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int row = 0; row < widget.node.rowCount; row += 1) //
          Row(
            children: [
              for (int col = 0; col < widget.node.columnCount; col += 1) //
                Expanded(
                  key: _cellKeys[row][col],
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    color: const Color(0xFFFF0000),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
