import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';

import 'document_selection.dart';
import 'document.dart';

/// Displays a `RichTextDocument`.
///
/// `DefaultDocumentLayout` displays a visual "component" for each
/// type of node in a given `RichTextDocument`. The components
/// are positioned vertically in a column with some space in between.
///
/// To get the `DocumentPosition` at a given (x,y) coordinate, see
/// `getDocumentPositionAtOffset()`.
///
/// To get the `DocumentSelection` within a rectangular region, see
/// `getDocumentSelectionInRegion()`.
///
/// To get the `MouseCursor` that should be displayed for the content
/// at a given (x,y) coordinate, see `getDesiredCursorAtOffset()`.
///
/// To get the `SelectableTextState` that corresponds to a given
/// `RichTextDocument` node, see `getSelectableTextByNodeId()`
/// WARNING: this method will eventually disappear and be replaced
/// by a version that returns a generic "document component". This
/// is needed to facilitate visual components other than text.
class DefaultDocumentLayout extends StatefulWidget {
  const DefaultDocumentLayout({
    Key key,
    @required this.document,
    @required this.documentSelection,
    @required this.componentBuilder,
    this.showDebugPaint = false,
  }) : super(key: key);

  final RichTextDocument document;
  final DocumentSelection documentSelection;
  final ComponentBuilder componentBuilder;
  final bool showDebugPaint;

  @override
  _DefaultDocumentLayoutState createState() => _DefaultDocumentLayoutState();
}

class _DefaultDocumentLayoutState extends State<DefaultDocumentLayout> with DocumentLayout {
  final Map<String, GlobalKey> _nodeIdsToComponentKeys = {};
  final List<GlobalKey> _topToBottomComponentKeys = [];

  /// Returns the `DocumentPosition` at the given `rawDocumentOffset`,
  /// but only if the offset truly wits within a document component.
  ///
  /// To find a `DocumentPosition` based only on y-value, use
  /// `getDocumentPositionNearestToOffset`.
  DocumentPosition getDocumentPositionAtOffset(Offset rawDocumentOffset) {
    print('Getting document position at exact offset: $rawDocumentOffset');

    final componentKey = _findComponentAtOffset(rawDocumentOffset);
    if (componentKey != null) {
      final component = componentKey.currentState as DocumentComponent;
      final componentBox = componentKey.currentContext.findRenderObject() as RenderBox;
      print(' - found node at position: $component');
      final componentOffset = _componentOffset(componentBox, rawDocumentOffset);
      final componentPosition = component.getPositionAtOffset(componentOffset);

      final selectionAtOffset = DocumentPosition(
        nodeId: _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key,
        nodePosition: componentPosition,
      );
      print(' - selection at offset: $selectionAtOffset');
      return selectionAtOffset;
    }

    return null;
  }

  DocumentPosition getDocumentPositionNearestToOffset(Offset rawDocumentOffset) {
    // Constrain the incoming offset to sit within the width
    // of this document layout.
    final docBox = context.findRenderObject() as RenderBox;
    final documentOffset = Offset(
      // Notice the +1/-1. Experimentally, I determined that if we confine
      // to the exact width, that x-value is considered outside the
      // component RenderBox's. However, 1px less than that is
      // considered to be within the component RenderBox's.
      rawDocumentOffset.dx.clamp(1.0, docBox.size.width - 1),
      rawDocumentOffset.dy,
    );
    print('Getting document position at offset: $documentOffset');

    return getDocumentPositionAtOffset(documentOffset);
  }

  Rect getRectForPosition(DocumentPosition position) {
    final component = getComponentByNodeId(position.nodeId);
    if (component == null) {
      print('Could not find any component for node position: $position');
      return null;
    }
    final componentRect = component.getRectForPosition(position.nodePosition);
    if (componentRect == null) {
      return null;
    }

    final componentBox = component.context.findRenderObject() as RenderBox;
    final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());

    return componentRect.translate(docOffset.dx, docOffset.dy);
  }

  DocumentSelection getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset) {
    print('getDocumentSelectionInRegion() - from: $baseOffset, to: $extentOffset');
    // Drag direction determines whether the extent offset is at the
    // top or bottom of the drag rect.
    // TODO: this condition is wrong when the user is dragging within a single line of text
    final isDraggingDown = baseOffset.dy < extentOffset.dy;

    final region = Rect.fromPoints(baseOffset, extentOffset);

    String topNodeId;
    dynamic topNodeBasePosition;
    dynamic topNodeExtentPosition;

    String bottomNodeId;
    dynamic bottomNodeBasePosition;
    dynamic bottomNodeExtentPosition;

    for (final componentKey in _topToBottomComponentKeys) {
      print(' - considering component "$componentKey"');
      if (componentKey.currentState is! DocumentComponent) {
        print(' - found unknown component: ${componentKey.currentState}');
        continue;
      }

      final component = componentKey.currentState as DocumentComponent;

      final dragIntersection = _getDragIntersectionWith(region, component);

      if (dragIntersection != null) {
        print(' - drag intersects: $componentKey}');
        print(' - intersection: $dragIntersection');
        final componentBaseOffset = _componentOffset(
          componentKey.currentContext.findRenderObject() as RenderBox,
          baseOffset,
        );
        final componentExtentOffset = _componentOffset(
          componentKey.currentContext.findRenderObject() as RenderBox,
          extentOffset,
        );

        if (topNodeId == null) {
          topNodeId = _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key;
          topNodeBasePosition = component.getPositionAtOffset(componentBaseOffset);
          topNodeExtentPosition = component.getPositionAtOffset(componentExtentOffset);
        }
        bottomNodeId = _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key;
        bottomNodeBasePosition = component.getPositionAtOffset(componentBaseOffset);
        bottomNodeExtentPosition = component.getPositionAtOffset(componentExtentOffset);
      }
    }

    if (topNodeId == null) {
      return null;
    } else if (topNodeId == bottomNodeId) {
      // Region sits within a single component.
      return DocumentSelection(
        base: DocumentPosition(
          nodeId: topNodeId,
          nodePosition: topNodeBasePosition,
        ),
        extent: DocumentPosition(
          nodeId: bottomNodeId,
          nodePosition: topNodeExtentPosition,
        ),
      );
    } else {
      // Region covers multiple components.
      return DocumentSelection(
        base: DocumentPosition(
          nodeId: isDraggingDown ? topNodeId : bottomNodeId,
          nodePosition: isDraggingDown ? topNodeBasePosition : bottomNodeBasePosition,
        ),
        extent: DocumentPosition(
          nodeId: isDraggingDown ? bottomNodeId : topNodeId,
          nodePosition: isDraggingDown ? bottomNodeExtentPosition : topNodeExtentPosition,
        ),
      );
    }
  }

  Rect _getDragIntersectionWith(Rect region, DocumentComponent component) {
    final componentBox = component.context.findRenderObject() as RenderBox;
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
    final componentBounds = contentOffset & componentBox.size;

    if (region.overlaps(componentBounds)) {
      // Report the overlap in our local coordinate space.
      return region.translate(-contentOffset.dx, -contentOffset.dy);
    } else {
      return null;
    }
  }

  MouseCursor getDesiredCursorAtOffset(Offset documentOffset) {
    final componentKey = _findComponentAtOffset(documentOffset);
    if (componentKey != null) {
      final componentBox = componentKey.currentContext.findRenderObject() as RenderBox;
      final componentOffset = _componentOffset(componentBox, documentOffset);

      final component = componentKey.currentState as DocumentComponent;
      return component.getDesiredCursorAtOffset(componentOffset);
    }
    return null;
  }

  GlobalKey _findComponentAtOffset(Offset documentOffset) {
    // print('Finding document node at offset: $documentOffset');
    for (final componentKey in _nodeIdsToComponentKeys.values) {
      // print(' - considering component "$componentKey"');
      if (componentKey.currentState is! DocumentComponent) {
        // print(' - found unknown component - $componentKey: ${componentKey.currentState}');
        continue;
      }

      final textBox = componentKey.currentContext.findRenderObject() as RenderBox;
      if (_isOffsetInComponent(textBox, documentOffset)) {
        // print(' - found component at offset: $componentKey');
        return componentKey;
      }
    }
    return null;
  }

  bool _isOffsetInComponent(RenderBox componentBox, Offset documentOffset) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & componentBox.size;

    return contentRect.contains(documentOffset);
  }

  Offset _componentOffset(RenderBox componentBox, Offset documentOffset) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & componentBox.size;

    return documentOffset - contentRect.topLeft;
  }

  DocumentComponent getComponentByNodeId(String nodeId) {
    final key = _nodeIdsToComponentKeys[nodeId];
    if (key == null) {
      print('WARNING: could not find component for node ID: $nodeId');
      return null;
    }
    if (key.currentState is! DocumentComponent) {
      print(
          'WARNING: found component but it\'s not a DocumentComponent: $nodeId, layout key: $key, state: ${key.currentState}, widget: ${key.currentWidget}, context: ${key.currentContext}');
    }
    return key.currentState as DocumentComponent;
  }

  @override
  Widget build(BuildContext context) {
    // print('Building document layout:');
    final docComponents = _buildDocComponents();

    return DefaultTextStyle(
      style: const TextStyle(
        color: Color(0xFF312F2C),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final docComponent in docComponents) ...[
            docComponent,
            SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildDocComponents() {
    final docComponents = <Widget>[];
    final newComponentKeys = <String, GlobalKey>{};
    _topToBottomComponentKeys.clear();

    print('_buildDocComponents()');

    final selectedNodes = widget.documentSelection != null
        ? widget.document.getNodesInside(
            widget.documentSelection.base,
            widget.documentSelection.extent,
          )
        : const <DocumentNode>[];

    for (final docNode in widget.document.nodes) {
      final componentKey = _createOrTransferComponentKey(
        newComponentKeyMap: newComponentKeys,
        nodeId: docNode.id,
      );
      print('Node -> Key: ${docNode.id} -> $componentKey');

      _topToBottomComponentKeys.add(componentKey);

      final nodeSelection = _computeNodeSelection(
        selectedNodes: selectedNodes,
        nodeId: docNode.id,
      );

      final component = widget.componentBuilder(
        context: context,
        document: widget.document,
        currentNode: docNode,
        key: componentKey,
        nodeSelection: nodeSelection,
        showDebugPaint: widget.showDebugPaint,
      );

      docComponents.add(component);
    }

    _nodeIdsToComponentKeys
      ..clear()
      ..addAll(newComponentKeys);

    print(' - keys -> IDs after building all components:');
    _nodeIdsToComponentKeys.forEach((key, value) {
      print('   - $key: $value');
    });

    return docComponents;
  }

  GlobalKey _createOrTransferComponentKey({
    Map<String, GlobalKey> newComponentKeyMap,
    String nodeId,
  }) {
    if (_nodeIdsToComponentKeys.containsKey(nodeId)) {
      newComponentKeyMap[nodeId] = _nodeIdsToComponentKeys[nodeId];
    } else {
      newComponentKeyMap[nodeId] = GlobalKey();
    }
    return newComponentKeyMap[nodeId];
  }

  DocumentNodeSelection _computeNodeSelection({
    @required List<DocumentNode> selectedNodes,
    @required String nodeId,
  }) {
    if (widget.documentSelection == null) {
      return null;
    }

    print('_computeNodeSelection(): $nodeId');
    print(' - base: ${widget.documentSelection.base.nodeId}');
    print(' - extent: ${widget.documentSelection.extent.nodeId}');

    final node = widget.document.getNodeById(nodeId);
    if (widget.documentSelection.base.nodeId == widget.documentSelection.extent.nodeId) {
      print(' - selection is within 1 node.');
      if (widget.documentSelection.base.nodeId != nodeId) {
        print(' - this node is not selected. Returning null.');
        return null;
      }

      print(' - this node has the selection');
      final baseNodePosition = widget.documentSelection.base.nodePosition;
      final extentNodePosition = widget.documentSelection.extent.nodePosition;
      final nodeSelection = node.computeSelection(base: baseNodePosition, extent: extentNodePosition);
      print(' - node selection: $nodeSelection');

      return DocumentNodeSelection(
        nodeId: nodeId,
        nodeSelection: nodeSelection,
        isBase: true,
        isExtent: true,
      );
    } else {
      print(' - selection contains multiple nodes:');
      for (final node in selectedNodes) {
        print('   - ${node.id}');
      }

      if (selectedNodes.firstWhere((selectedNode) => selectedNode.id == nodeId, orElse: () => null) == null) {
        print(' - this node is not in the selection');
        return null;
      }

      // TODO: we currently operate with "selections" within a node, but this
      //       is superfluous for nodes that are fully selected. They have no
      //       base and no extent, but we're reporting selections instead of
      //       ranges. Change DocumentNodeSelection to report a range, and
      //       then optionally a base and/or extent node position.
      if (selectedNodes.first.id == nodeId) {
        print(' - this is the first node in the selection');
        // This node is selected from a position down to its bottom.
        final isBase = nodeId == widget.documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: nodeId,
          nodeSelection: node.computeSelection(
            base: isBase ? widget.documentSelection.base.nodePosition : node.endPosition,
            extent: isBase ? node.endPosition : widget.documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
        );
      } else if (selectedNodes.last.id == nodeId) {
        print(' - this is the last node in the selection');
        // This node is selected from its top down to a position.
        final isBase = nodeId == widget.documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: nodeId,
          nodeSelection: node.computeSelection(
            base: isBase ? node.beginningPosition : node.beginningPosition,
            extent: isBase ? widget.documentSelection.base.nodePosition : widget.documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
        );
      } else {
        print(' - this node is fully selected within the selection');
        // This entire node is selected.
        return DocumentNodeSelection(
          nodeId: nodeId,
          nodeSelection: node.computeSelection(
            base: node.beginningPosition,
            extent: node.endPosition,
          ),
        );
      }
    }
  }
}

abstract class DocumentLayout {
  DocumentPosition getDocumentPositionAtOffset(Offset rawDocumentOffset);

  DocumentPosition getDocumentPositionNearestToOffset(Offset rawDocumentOffset);

  Rect getRectForPosition(DocumentPosition position);

  DocumentSelection getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset);

  MouseCursor getDesiredCursorAtOffset(Offset documentOffset);

  DocumentComponent getComponentByNodeId(String nodeId);
}

/// Contract for all widgets that operate as document components
/// within a `DocumentLayout`.
mixin DocumentComponent<T extends StatefulWidget> on State<T> {
  dynamic getPositionAtOffset(Offset localOffset);

  Offset getOffsetForPosition(dynamic nodePosition);

  Rect getRectForPosition(dynamic nodePosition);

  dynamic getBeginningPosition();

  dynamic getBeginningPositionNearX(double x);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved left one unit,
  /// as interpreted by this component/node, in conjunction with
  /// any relevant `movementModifier`.
  ///
  /// The structure and options for `movementModifier`s is
  /// determined by each component/node combination.
  ///
  /// Returns null if the concept of horizontal movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move left within this
  /// component.
  dynamic movePositionLeft(dynamic currentPosition, [Map<String, dynamic> movementModifiers]);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved right one unit,
  /// as interpreted by this component/node, in conjunction with
  /// any relevant `movementModifier`.
  ///
  /// The structure and options for `movementModifier`s is
  /// determined by each component/node combination.
  ///
  /// Returns null if the concept of horizontal movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move right within this
  /// component.
  dynamic movePositionRight(dynamic currentPosition, [Map<String, dynamic> movementModifiers]);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved up one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move up within this
  /// component.
  dynamic movePositionUp(dynamic currentPosition);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved down one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move down within this
  /// component.
  dynamic movePositionDown(dynamic currentPosition);

  dynamic getEndPosition();

  dynamic getEndPositionNearX(double x);

  dynamic getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset);

  dynamic getCollapsedSelectionAt(dynamic nodePosition);

  dynamic getSelectionBetween({
    @required dynamic basePosition,
    @required dynamic extentPosition,
  });

  dynamic getSelectionOfEverything();

  MouseCursor getDesiredCursorAtOffset(Offset localOffset);
}

/// Contract for document components that include editable text.
///
/// Examples: paragraphs, list items, images with captions.
abstract class TextComposable {
  TextSelection getWordSelectionAt(dynamic nodePosition);

  String getContiguousTextAt(dynamic nodePosition);

  dynamic getPositionOneLineUp(dynamic nodePosition);

  dynamic getPositionOneLineDown(dynamic nodePosition);

  dynamic getPositionAtEndOfLine(dynamic nodePosition);

  dynamic getPositionAtStartOfLine(dynamic nodePosition);
}

typedef ComponentBuilder = Widget Function({
  @required BuildContext context,
  @required RichTextDocument document,
  @required DocumentNode currentNode,
  @required DocumentNodeSelection nodeSelection,
  @required GlobalKey key,
  bool showDebugPaint,
});
