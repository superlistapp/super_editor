import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

final _log = Logger(scope: 'DocumentLayout');

/// Displays a `Document` as a single column.
///
/// `DefaultDocumentLayout` displays a visual "component" for each
/// type of node in a given `Document`. The components are positioned
/// vertically in a column with some space in between.
///
/// `DefaultDocumentLayout`'s `State` object implements `DocumentLayout`,
/// which establishes a contract for querying many document layout
/// properties. To use the `DocumentLayout` API, assign a `GlobalKey`
/// to a `DefaultDocumentLayout`, obtain its `State` object, and then
/// cast that `State` object to a `DocumentLayout`.
class DefaultDocumentLayout extends StatefulWidget {
  const DefaultDocumentLayout({
    Key? key,
    required this.document,
    this.documentSelection,
    required this.showCaret,
    required this.componentBuilders,
    this.componentVerticalSpacing = 16,
    this.extensions = const {},
    this.showDebugPaint = false,
  }) : super(key: key);

  /// The `Document` that this layout displays.
  final Document document;

  /// The selection of a region of a `Document`, used when
  /// rendering document content, e.g., painting a text selection.
  final DocumentSelection? documentSelection;

  /// [true] if the document UI should display a caret at the
  /// selection extent.
  final bool showCaret;

  /// Builders for every type of component that this layout displays.
  ///
  /// Every type of `DocumentNode` that might appear in the displayed
  /// `document` should have a `ComponentBuilder` that knows how to
  /// render that piece of content.
  final List<ComponentBuilder> componentBuilders;

  /// The space between sequential components.
  final double componentVerticalSpacing;

  /// Tools that components might use to build themselves.
  ///
  /// `extensions` is used to provide text components with
  /// a default text styler. `extensions` can be used to
  /// pass anything else that a component might expect.
  final Map<String, dynamic> extensions;

  /// Adds a debugging UI to the document layout, when true.
  final bool showDebugPaint;

  @override
  _DefaultDocumentLayoutState createState() => _DefaultDocumentLayoutState();
}

class _DefaultDocumentLayoutState extends State<DefaultDocumentLayout> implements DocumentLayout {
  final Map<String, GlobalKey> _nodeIdsToComponentKeys = {};

  // Keys are cached in top-to-bottom order so that we can visually
  // traverse components without repeatedly querying a `Document`
  // to determine component ordering.
  final List<GlobalKey> _topToBottomComponentKeys = [];

  @override
  DocumentPosition? getDocumentPositionAtOffset(Offset documentOffset) {
    _log.log('getDocumentPositionAtOffset', 'Getting document position at exact offset: $documentOffset');

    final componentKey = _findComponentAtOffset(documentOffset);
    if (componentKey == null || componentKey.currentContext == null) {
      return null;
    }

    final component = componentKey.currentState as DocumentComponent;
    final componentBox = componentKey.currentContext!.findRenderObject() as RenderBox;
    _log.log('getDocumentPositionAtOffset', ' - found node at position: $component');
    final componentOffset = _componentOffset(componentBox, documentOffset);
    final componentPosition = component.getPositionAtOffset(componentOffset);

    final selectionAtOffset = DocumentPosition(
      nodeId: _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key,
      nodePosition: componentPosition,
    );
    _log.log('getDocumentPositionAtOffset', ' - selection at offset: $selectionAtOffset');
    return selectionAtOffset;
  }

  @override
  DocumentPosition? getDocumentPositionNearestToOffset(Offset rawDocumentOffset) {
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
    _log.log('getDocumentPositionNearestToOffset', 'Getting document position at offset: $documentOffset');

    return getDocumentPositionAtOffset(documentOffset);
  }

  @override
  Rect? getRectForPosition(DocumentPosition position) {
    final component = getComponentByNodeId(position.nodeId);
    if (component == null) {
      _log.log('getRectForPosition', 'Could not find any component for node position: $position');
      return null;
    }
    final componentRect = component.getRectForPosition(position.nodePosition);

    final componentBox = component.context.findRenderObject() as RenderBox;
    final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());

    return componentRect.translate(docOffset.dx, docOffset.dy);
  }

  @override
  Rect? getRectForSelection(DocumentPosition base, DocumentPosition extent) {
    final baseComponent = getComponentByNodeId(base.nodeId);
    final extentComponent = getComponentByNodeId(extent.nodeId);
    if (baseComponent == null || extentComponent == null) {
      _log.log('getRectForSelection',
          'Could not find base and/or extent position to calculate bounding box for selection. Base: $base -> $baseComponent, Extent: $extent -> $extentComponent');
      return null;
    }

    DocumentComponent topComponent;
    final componentBoundingBoxes = <Rect>[];

    // Collect bounding boxes for all selected components.
    if (base.nodeId == extent.nodeId) {
      // Selection within a single node.
      topComponent = extentComponent;
      final componentBoundingBox = extentComponent.getRectForSelection(base.nodePosition, extent.nodePosition);
      componentBoundingBoxes.add(componentBoundingBox);
    } else {
      // Selection across nodes.
      final selectedNodes = widget.document.getNodesInside(base, extent);
      topComponent = getComponentByNodeId(selectedNodes.first.id)!;
      final startPosition = selectedNodes.first.id == base.nodeId ? base.nodePosition : extent.nodePosition;
      final endPosition = selectedNodes.first.id == extent.nodeId ? extent.nodePosition : base.nodePosition;

      for (int i = 0; i < selectedNodes.length; ++i) {
        final component = getComponentByNodeId(selectedNodes[i].id)!;

        if (i == 0) {
          // This is the first node. The selection goes from
          // startPosition to the end of the node.
          final firstNodeEndPosition = component.getEndPosition();
          componentBoundingBoxes.add(component.getRectForSelection(startPosition, firstNodeEndPosition));
        } else if (i == selectedNodes.length - 1) {
          // This is the last node. The selection goes from
          // the beginning of the node to endPosition.
          final lastNodeStartPosition = component.getBeginningPosition();
          componentBoundingBoxes.add(component.getRectForSelection(lastNodeStartPosition, endPosition));
        } else {
          // This node sits between start and end. All content
          // is selected.
          componentBoundingBoxes.add(
            component.getRectForSelection(
              component.getBeginningPosition(),
              component.getEndPosition(),
            ),
          );
        }
      }
    }

    // Combine all component boxes into one big bounding box.
    Rect boundingBox = componentBoundingBoxes.first;
    for (int i = 1; i < componentBoundingBoxes.length; ++i) {
      boundingBox.expandToInclude(componentBoundingBoxes[i]);
    }

    // Translate the bounding box so that it's positioned in document coordinate space.
    final topComponentBox = topComponent.context.findRenderObject() as RenderBox;
    final docOffset = topComponentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
    boundingBox = boundingBox.translate(docOffset.dx, docOffset.dy);

    return boundingBox;
  }

  @override
  DocumentSelection? getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset) {
    _log.log('getDocumentSelectionInRegion', 'getDocumentSelectionInRegion() - from: $baseOffset, to: $extentOffset');
    // Drag direction determines whether the extent offset is at the
    // top or bottom of the drag rect.
    // TODO: this condition is wrong when the user is dragging within a single line of text (#50)
    final isDraggingDown = baseOffset.dy < extentOffset.dy;

    final region = Rect.fromPoints(baseOffset, extentOffset);

    String? topNodeId;
    dynamic topNodeBasePosition;
    dynamic topNodeExtentPosition;

    String? bottomNodeId;
    dynamic bottomNodeBasePosition;
    dynamic bottomNodeExtentPosition;

    for (final componentKey in _topToBottomComponentKeys) {
      _log.log('getDocumentSelectionInRegion', ' - considering component "$componentKey"');
      if (componentKey.currentState is! DocumentComponent) {
        _log.log('getDocumentSelectionInRegion', ' - found unknown component: ${componentKey.currentState}');
        continue;
      }

      final component = componentKey.currentState as DocumentComponent;

      final componentOverlap = _getLocalOverlapWithComponent(region, component);

      if (componentOverlap != null) {
        _log.log('getDocumentSelectionInRegion', ' - drag intersects: $componentKey}');
        _log.log('getDocumentSelectionInRegion', ' - intersection: $componentOverlap');
        final componentBaseOffset = _componentOffset(
          componentKey.currentContext!.findRenderObject() as RenderBox,
          baseOffset,
        );
        final componentExtentOffset = _componentOffset(
          componentKey.currentContext!.findRenderObject() as RenderBox,
          extentOffset,
        );

        if (topNodeId == null) {
          // Because we're iterating through components from top to bottom, the
          // first intersecting component that we find must be the top node of
          // the selected area.
          topNodeId = _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key;
          topNodeBasePosition = component.getPositionAtOffset(componentBaseOffset);
          topNodeExtentPosition = component.getPositionAtOffset(componentExtentOffset);
        }
        // We continuously update the bottom node with every additional
        // intersection that we find. This way, when the iteration ends,
        // the last bottom node that we assigned must be the actual bottom
        // node within the selected area.
        bottomNodeId = _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key;
        bottomNodeBasePosition = component.getPositionAtOffset(componentBaseOffset);
        bottomNodeExtentPosition = component.getPositionAtOffset(componentExtentOffset);
      }
    }

    if (topNodeId == null || bottomNodeId == null) {
      // No document content exists in the given region.
      return null;
    }

    if (topNodeId == bottomNodeId) {
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

  /// Returns the overlapping `Rect` between the given `region` and the given
  /// `component`'s bounding box.
  ///
  /// Returns `null` if there is no overlap.
  Rect? _getLocalOverlapWithComponent(Rect region, DocumentComponent component) {
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

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset documentOffset) {
    final componentKey = _findComponentAtOffset(documentOffset);
    if (componentKey == null ||
        componentKey.currentContext == null ||
        componentKey.currentContext!.findRenderObject() == null) {
      return null;
    }

    final componentBox = componentKey.currentContext!.findRenderObject() as RenderBox;
    final componentOffset = _componentOffset(componentBox, documentOffset);

    final component = componentKey.currentState as DocumentComponent;
    return component.getDesiredCursorAtOffset(componentOffset);
  }

  GlobalKey? _findComponentAtOffset(Offset documentOffset) {
    for (final componentKey in _nodeIdsToComponentKeys.values) {
      if (componentKey.currentState is! DocumentComponent) {
        continue;
      }
      if (componentKey.currentContext == null || componentKey.currentContext!.findRenderObject() == null) {
        continue;
      }

      final textBox = componentKey.currentContext!.findRenderObject() as RenderBox;
      if (_isOffsetInComponent(textBox, documentOffset)) {
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

  @override
  DocumentComponent? getComponentByNodeId(String nodeId) {
    final key = _nodeIdsToComponentKeys[nodeId];
    if (key == null) {
      _log.log('getComponentByNodeId', 'WARNING: could not find component for node ID: $nodeId');
      return null;
    }
    if (key.currentState is! DocumentComponent) {
      _log.log('getComponentByNodeId',
          'WARNING: found component but it\'s not a DocumentComponent: $nodeId, layout key: $key, state: ${key.currentState}, widget: ${key.currentWidget}, context: ${key.currentContext}');
      return null;
    }
    return key.currentState as DocumentComponent;
  }

  @override
  Offset getDocumentOffsetFromAncestorOffset(Offset ancestorOffset, RenderObject ancestor) {
    return (context.findRenderObject() as RenderBox).globalToLocal(ancestorOffset, ancestor: ancestor);
  }

  @override
  Offset getAncestorOffsetFromDocumentOffset(Offset documentOffset, RenderObject ancestor) {
    return (context.findRenderObject() as RenderBox).localToGlobal(documentOffset, ancestor: ancestor);
  }

  @override
  Widget build(BuildContext context) {
    final docComponents = _buildDocComponents();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final docComponent in docComponents) ...[
          docComponent,
          SizedBox(height: widget.componentVerticalSpacing),
        ],
      ],
    );
  }

  List<Widget> _buildDocComponents() {
    final docComponents = <Widget>[];
    final newComponentKeys = <String, GlobalKey>{};
    _topToBottomComponentKeys.clear();

    _log.log('_buildDocComponents', '_buildDocComponents()');

    final selectedNodes = widget.documentSelection != null
        ? widget.document.getNodesInside(
            widget.documentSelection!.base,
            widget.documentSelection!.extent,
          )
        : const <DocumentNode>[];

    final extensions = Map.from(widget.extensions);
    extensions['showDebugPaint'] = widget.showDebugPaint;

    for (final docNode in widget.document.nodes) {
      final componentKey = _createOrTransferComponentKey(
        newComponentKeyMap: newComponentKeys,
        nodeId: docNode.id,
      );
      _log.log('_buildDocComponents', 'Node -> Key: ${docNode.id} -> $componentKey');

      _topToBottomComponentKeys.add(componentKey);

      final nodeSelection = _computeNodeSelection(
        selectedNodes: selectedNodes,
        nodeId: docNode.id,
      );

      final component = _buildComponent(ComponentContext(
        context: context,
        document: widget.document,
        documentNode: docNode,
        componentKey: componentKey,
        showCaret: widget.showCaret,
        nodeSelection: nodeSelection,
        extensions: widget.extensions,
      ));

      if (component != null) {
        docComponents.add(component);
      } else {
        _log.log('_buildDocComponents', 'Failed to build component for node: $docNode');
      }
    }

    _nodeIdsToComponentKeys
      ..clear()
      ..addAll(newComponentKeys);

    _log.log('_buildDocComponents', ' - keys -> IDs after building all components:');
    _nodeIdsToComponentKeys.forEach((key, value) {
      _log.log('_buildDocComponents', '   - $key: $value');
    });

    return docComponents;
  }

  // TODO: try assigning a new GlobalKey every time and see if it breaks
  //       anything. If it doesn't break anything, or hurt performance,
  //       then replace this behavior with regular GlobalKey instantiation (#51)
  GlobalKey _createOrTransferComponentKey({
    required Map<String, GlobalKey> newComponentKeyMap,
    required String nodeId,
  }) {
    if (_nodeIdsToComponentKeys.containsKey(nodeId)) {
      newComponentKeyMap[nodeId] = _nodeIdsToComponentKeys[nodeId]!;
    } else {
      newComponentKeyMap[nodeId] = GlobalKey();
    }
    return newComponentKeyMap[nodeId]!;
  }

  /// Computes the `DocumentNodeSelection` for the individual `nodeId` based on
  /// the total list of selected nodes.
  DocumentNodeSelection? _computeNodeSelection({
    required List<DocumentNode> selectedNodes,
    required String nodeId,
  }) {
    if (widget.documentSelection == null) {
      return null;
    }
    final documentSelection = widget.documentSelection!;

    _log.log('_computeNodeSelection', '_computeNodeSelection(): $nodeId');
    _log.log('_computeNodeSelection', ' - base: ${documentSelection.base.nodeId}');
    _log.log('_computeNodeSelection', ' - extent: ${documentSelection.extent.nodeId}');

    final node = widget.document.getNodeById(nodeId);
    if (node == null) {
      return null;
    }

    if (documentSelection.base.nodeId == documentSelection.extent.nodeId) {
      _log.log('_computeNodeSelection', ' - selection is within 1 node.');
      if (documentSelection.base.nodeId != nodeId) {
        // Only 1 node is selected and its not the node we're interested in. Return.
        _log.log('_computeNodeSelection', ' - this node is not selected. Returning null.');
        return null;
      }

      _log.log('_computeNodeSelection', ' - this node has the selection');
      final baseNodePosition = documentSelection.base.nodePosition;
      final extentNodePosition = documentSelection.extent.nodePosition;
      final nodeSelection = node.computeSelection(base: baseNodePosition, extent: extentNodePosition);
      _log.log('_computeNodeSelection', ' - node selection: $nodeSelection');

      return DocumentNodeSelection(
        nodeId: nodeId,
        nodeSelection: nodeSelection,
        isBase: true,
        isExtent: true,
      );
    } else {
      // Log all the selected nodes.
      _log.log('_computeNodeSelection', ' - selection contains multiple nodes:');
      for (final node in selectedNodes) {
        _log.log('_computeNodeSelection', '   - ${node.id}');
      }

      if (selectedNodes.firstWhereOrNull((selectedNode) => selectedNode.id == nodeId) == null) {
        // The document selection does not contain the node we're interested in. Return.
        _log.log('_computeNodeSelection', ' - this node is not in the selection');
        return null;
      }

      if (selectedNodes.first.id == nodeId) {
        _log.log('_computeNodeSelection', ' - this is the first node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the top node in that selection. Therefore, this node is
        // selected from a position down to its bottom.
        final isBase = nodeId == documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: nodeId,
          nodeSelection: node.computeSelection(
            base: isBase ? documentSelection.base.nodePosition : node.endPosition,
            extent: isBase ? node.endPosition : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
        );
      } else if (selectedNodes.last.id == nodeId) {
        _log.log('_computeNodeSelection', ' - this is the last node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the bottom node in that selection. Therefore, this node is
        // selected from the beginning down to some position.
        final isBase = nodeId == documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: nodeId,
          nodeSelection: node.computeSelection(
            base: isBase ? node.beginningPosition : node.beginningPosition,
            extent: isBase ? documentSelection.base.nodePosition : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
        );
      } else {
        _log.log('_computeNodeSelection', ' - this node is fully selected within the selection');
        // Multiple nodes are selected and this node is neither the top
        // or the bottom node, therefore this entire node is selected.
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

  Widget? _buildComponent(ComponentContext componentContext) {
    for (final componentBuilder in widget.componentBuilders) {
      final component = componentBuilder(componentContext);
      if (component != null) {
        return component;
      }
    }
    return null;
  }
}
