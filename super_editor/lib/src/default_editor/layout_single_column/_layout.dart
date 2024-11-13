import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/node_grouping.dart';

import '_presenter.dart';

/// Displays a document in a single-column layout.
///
/// [SingleColumnDocumentLayout] displays a series of visual "components".
/// The components are positioned vertically in a column with some space
/// in between.
///
/// The given [presenter] produces component view models, and each of those
/// component view models are turned into visual components by the given
/// [componentBuilders].
///
/// [SingleColumnDocumentLayout]'s `State` object implements [DocumentLayout],
/// which establishes a contract for querying many document layout
/// properties. To use the [DocumentLayout] API, assign a `GlobalKey`
/// to a [SingleColumnDocumentLayout], obtain its `State` object, and then
/// cast that `State` object to a [DocumentLayout].
class SingleColumnDocumentLayout extends StatefulWidget {
  const SingleColumnDocumentLayout({
    Key? key,
    required this.presenter,
    required this.componentBuilders,
    this.groupBuilders = const [],
    this.onBuildScheduled,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// Presenter that provides a view model for a complete single-column
  /// document layout.
  final SingleColumnLayoutPresenter presenter;

  /// Builders for every type of component that this layout displays.
  ///
  /// Every type of [SingleColumnLayoutComponentViewModel] that might
  /// appear in the displayed `document` should have a
  /// [SingleColumnDocumentComponentBuilder] that knows how to render
  /// that piece of content.
  final List<ComponentBuilder> componentBuilders;

  /// {@template group_builders}
  /// Builders that know how to group nodes together.
  ///
  /// Typically, components are organized vertically from top to bottom. A group
  /// builder can be used to create a subtree with grouped components and add
  /// features like group collapsing.
  /// {@endtemplate}
  final List<GroupBuilder> groupBuilders;

  /// Callback that's invoked whenever this widget schedules a build with
  /// `setState()`.
  ///
  /// This callback was added to facilitate the ContentLayers widget, because
  /// Flutter makes it impossible to monitor the dirty state of a sub-tree.
  ///
  /// TODO: Get rid of this as soon as Flutter makes it possible to monitor
  ///       dirty subtrees.
  final VoidCallback? onBuildScheduled;

  /// Adds a debugging UI to the document layout, when true.
  final bool showDebugPaint;

  @override
  State createState() => SingleColumnDocumentLayoutState();
}

@visibleForTesting
class SingleColumnDocumentLayoutState extends State<SingleColumnDocumentLayout> implements DocumentLayout {
  final Map<String, GlobalKey> _nodeIdsToComponentKeys = {};
  final Map<GlobalKey, String> _componentKeysToNodeIds = {};

  // Keys are cached in top-to-bottom order so that we can visually
  // traverse components without repeatedly querying a `Document`
  // to determine component ordering.
  final List<GlobalKey> _topToBottomComponentKeys = [];

  late SingleColumnLayoutPresenterChangeListener _presenterListener;

  // The key for the renderBox that contains the actual document layout.
  final GlobalKey _boxKey = GlobalKey();
  BuildContext get boxContext => _boxKey.currentContext!;

  /// The list of groups within this layout.
  @visibleForTesting
  List<GroupItem> get groups => UnmodifiableListView(_groups);
  final List<GroupItem> _groups = [];

  /// Maps a node ID to the group that contains it.
  ///
  /// Includes the root node ID for each group and its child
  /// node ID's.
  final Map<String, GroupItem> _nodeIdToGroup = {};

  /// Holds the node ID of the root node of each group that
  /// is currently collapsed.
  final Set<String> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();

    _presenterListener = SingleColumnLayoutPresenterChangeListener(
      onPresenterMarkedDirty: _onPresenterMarkedDirty,
      onViewModelChange: _onViewModelChange,
    );
    widget.presenter.addChangeListener(_presenterListener);

    // Build the view model now, so that any further changes to the
    // presenter send us a dirty notification.
    widget.presenter.updateViewModel();
  }

  @override
  void didUpdateWidget(SingleColumnDocumentLayout oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.presenter != oldWidget.presenter) {
      oldWidget.presenter.removeChangeListener(_presenterListener);
      widget.presenter.addChangeListener(_presenterListener);

      widget.presenter.updateViewModel();
    }
  }

  @override
  void dispose() {
    widget.presenter.removeChangeListener(_presenterListener);
    super.dispose();
  }

  Future<void> _onPresenterMarkedDirty() async {
    editorLayoutLog.fine("Layout presenter is dirty. Instructing it to update the view model.");
    widget.presenter.updateViewModel();
  }

  void _onViewModelChange({
    required List<String> addedComponents,
    required List<String> movedComponents,
    required List<String> changedComponents,
    required List<String> removedComponents,
  }) {
    if (addedComponents.isNotEmpty || movedComponents.isNotEmpty || removedComponents.isNotEmpty) {
      setState(() {
        // Re-flow the whole layout.
      });
    }

    if (changedComponents.isNotEmpty && widget.groupBuilders.isNotEmpty) {
      // A node change might affect the grouping of nodes. For example,
      // a paragraph node converted to a header should create a new group.
      // Or, a header node converted to a paragraph should remove the group.
      for (final nodeId in changedComponents) {
        final nodeIndex = widget.presenter.viewModel.componentViewModels.indexWhere(
          (viewModel) => viewModel.nodeId == nodeId,
        );
        if (nodeIndex < 0) {
          continue;
        }

        final canNodeStartGroup = widget.groupBuilders.any(
          (builder) => builder.canStartGroup(
            nodeIndex: nodeIndex,
            viewModels: widget.presenter.viewModel.componentViewModels,
          ),
        );

        final group = _nodeIdToGroup[nodeId];
        final isAlreadyStartingGroup = group != null && group.rootNodeId == nodeId;
        if (isAlreadyStartingGroup != canNodeStartGroup) {
          // The component is either:
          // - A header of a group, but it can't start a group anymore.
          // - A regular component, but it can start a group now.
          setState(() {
            // Re-flow the layout to re-create the groups.
          });
        }
      }
    }
  }

  @override
  bool isComponentVisible(String nodeId) {
    return _isNodeVisible(nodeId);
  }

  @override
  DocumentPosition? getDocumentPositionAtOffset(Offset documentOffset) {
    editorLayoutLog.info('Getting document position at exact offset: $documentOffset');

    final componentKey = _findComponentAtOffset(documentOffset);
    if (componentKey == null || componentKey.currentContext == null) {
      return null;
    }

    return _getDocumentPositionInComponentNearOffset(componentKey, documentOffset);
  }

  @override
  DocumentPosition? getDocumentPositionNearestToOffset(Offset rawDocumentOffset) {
    // Constrain the incoming offset to sit within the width
    // of this document layout.
    final docBox = boxContext.findRenderObject() as RenderBox;
    final documentOffset = Offset(
      // Notice the +1/-1. Experimentally, I determined that if we confine
      // to the exact width, that x-value is considered outside the
      // component RenderBox's. However, 1px less than that is
      // considered to be within the component RenderBox's.
      rawDocumentOffset.dx.clamp(1.0, max(docBox.size.width - 1.0, 1.0)),
      rawDocumentOffset.dy,
    );
    editorLayoutLog.info('Getting document position near offset: $documentOffset');

    if (_isAboveStartOfContent(documentOffset)) {
      // The given offset is above the start of the content.
      // Return the position at the start of the first node.
      final firstPosition = _findFirstPosition();
      if (firstPosition != null) {
        return firstPosition;
      }
    }

    if (_isBeyondDocumentEnd(documentOffset)) {
      // The given offset is beyond the end of the content.
      // Return the position at the end of the last node.
      final lastPosition = _findLastPosition();
      if (lastPosition != null) {
        return lastPosition;
      }
    }

    final componentKey = _findComponentClosestToOffset(documentOffset);
    if (componentKey == null || componentKey.currentContext == null) {
      return null;
    }

    return _getDocumentPositionInComponentNearOffset(componentKey, documentOffset);
  }

  DocumentPosition? _getDocumentPositionInComponentNearOffset(GlobalKey componentKey, Offset documentOffset) {
    final component = componentKey.currentState as DocumentComponent;
    final componentBox = componentKey.currentContext!.findRenderObject() as RenderBox;
    editorLayoutLog.info(' - found node at position: $component');
    final componentOffset = _componentOffset(componentBox, documentOffset);
    final componentPosition = component.getPositionAtOffset(componentOffset);

    if (componentPosition == null) {
      return null;
    }

    final selectionAtOffset = DocumentPosition(
      nodeId: _componentKeysToNodeIds[componentKey]!,
      nodePosition: componentPosition,
    );
    editorLayoutLog.info(' - selection at offset: $selectionAtOffset');
    return selectionAtOffset;
  }

  /// Returns whether or not [documentOffset] is above the start of the document's content.
  bool _isAboveStartOfContent(Offset documentOffset) {
    if (_topToBottomComponentKeys.isEmpty) {
      // There is no component in the document.
      return true;
    }

    final componentKey = _topToBottomComponentKeys.first;
    final componentBox = componentKey.currentContext!.findRenderObject() as RenderBox;
    final offsetAtComponent = _componentOffset(componentBox, documentOffset);

    return offsetAtComponent.dy < 0.0;
  }

  /// Returns whether or not [documentOffset] is beyond the end of the document.
  bool _isBeyondDocumentEnd(Offset documentOffset) {
    if (_topToBottomComponentKeys.isEmpty) {
      // There is no component in the document.
      return true;
    }

    final componentKey = _topToBottomComponentKeys.last;
    final componentBox = componentKey.currentContext!.findRenderObject() as RenderBox;
    final offsetAtComponent = _componentOffset(componentBox, documentOffset);

    return offsetAtComponent.dy > componentBox.size.height;
  }

  @override
  Rect? getEdgeForPosition(DocumentPosition position) {
    final component = getComponentByNodeId(position.nodeId);
    if (component == null) {
      editorLayoutLog.info('Could not find any component for node position: $position');
      return null;
    }

    final componentEdge = component.getEdgeForPosition(position.nodePosition);

    final componentBox = component.context.findRenderObject() as RenderBox;
    final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: boxContext.findRenderObject());

    return componentEdge.translate(docOffset.dx, docOffset.dy);
  }

  @override
  Rect? getRectForPosition(DocumentPosition position) {
    final component = getComponentByNodeId(position.nodeId);
    if (component == null) {
      editorLayoutLog.info('Could not find any component for node position: $position');
      return null;
    }

    final componentRect = component.getRectForPosition(position.nodePosition);

    final componentBox = component.context.findRenderObject() as RenderBox;
    final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: boxContext.findRenderObject());

    return componentRect.translate(docOffset.dx, docOffset.dy);
  }

  @override
  Rect? getRectForSelection(DocumentPosition base, DocumentPosition extent) {
    final baseComponent = getComponentByNodeId(base.nodeId);
    final extentComponent = getComponentByNodeId(extent.nodeId);
    if (baseComponent == null || extentComponent == null) {
      editorLayoutLog.info(
          'Could not find base and/or extent position to calculate bounding box for selection. Base: $base -> $baseComponent, Extent: $extent -> $extentComponent');
      return null;
    }

    DocumentComponent topComponent;
    final componentBoundingBoxes = <Rect>[];

    // Collect bounding boxes for all selected components.
    final documentLayoutBox = boxContext.findRenderObject() as RenderBox;
    if (base.nodeId == extent.nodeId) {
      // Selection within a single node.
      topComponent = extentComponent;
      final componentOffsetInDocument = (topComponent.context.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero, ancestor: documentLayoutBox);

      final componentBoundingBox = extentComponent
          .getRectForSelection(
            base.nodePosition,
            extent.nodePosition,
          )
          .translate(
            componentOffsetInDocument.dx,
            componentOffsetInDocument.dy,
          );
      componentBoundingBoxes.add(componentBoundingBox);
    } else {
      // Selection across nodes.
      final selectedNodes = _getNodeIdsBetween(base.nodeId, extent.nodeId);
      topComponent = getComponentByNodeId(selectedNodes.first)!;
      final startPosition = selectedNodes.first == base.nodeId ? base.nodePosition : extent.nodePosition;
      final endPosition = selectedNodes.first == base.nodeId ? extent.nodePosition : base.nodePosition;

      for (int i = 0; i < selectedNodes.length; ++i) {
        final component = getComponentByNodeId(selectedNodes[i])!;
        final componentOffsetInDocument =
            (component.context.findRenderObject() as RenderBox).localToGlobal(Offset.zero, ancestor: documentLayoutBox);

        if (i == 0) {
          // This is the first node. The selection goes from
          // startPosition to the end of the node.
          final firstNodeEndPosition = component.getEndPosition();
          final selectionRectInComponent = component.getRectForSelection(
            startPosition,
            firstNodeEndPosition,
          );
          final componentRectInDocument = selectionRectInComponent.translate(
            componentOffsetInDocument.dx,
            componentOffsetInDocument.dy,
          );
          componentBoundingBoxes.add(componentRectInDocument);
        } else if (i == selectedNodes.length - 1) {
          // This is the last node. The selection goes from
          // the beginning of the node to endPosition.
          final lastNodeStartPosition = component.getBeginningPosition();
          final selectionRectInComponent = component.getRectForSelection(
            lastNodeStartPosition,
            endPosition,
          );
          final componentRectInDocument = selectionRectInComponent.translate(
            componentOffsetInDocument.dx,
            componentOffsetInDocument.dy,
          );
          componentBoundingBoxes.add(componentRectInDocument);
        } else {
          // This node sits between start and end. All content
          // is selected.
          final selectionRectInComponent = component.getRectForSelection(
            component.getBeginningPosition(),
            component.getEndPosition(),
          );
          final componentRectInDocument = selectionRectInComponent.translate(
            componentOffsetInDocument.dx,
            componentOffsetInDocument.dy,
          );
          componentBoundingBoxes.add(componentRectInDocument);
        }
      }
    }

    // Combine all component boxes into one big bounding box.
    Rect boundingBox = componentBoundingBoxes.first;
    for (int i = 1; i < componentBoundingBoxes.length; ++i) {
      boundingBox = boundingBox.expandToInclude(componentBoundingBoxes[i]);
    }

    return boundingBox;
  }

  List<String> _getNodeIdsBetween(String baseNodeId, String extentNodeId) {
    final baseComponentKey = _nodeIdsToComponentKeys[baseNodeId]!;
    final baseComponentIndex = _topToBottomComponentKeys.indexOf(baseComponentKey);
    final extentComponentKey = _nodeIdsToComponentKeys[extentNodeId]!;
    final extentComponentIndex = _topToBottomComponentKeys.indexOf(extentComponentKey);

    final topNodeIndex = baseComponentIndex <= extentComponentIndex ? baseComponentIndex : extentComponentIndex;
    final bottomNodeIndex = topNodeIndex == baseComponentIndex ? extentComponentIndex : baseComponentIndex;
    final componentsInside = _topToBottomComponentKeys.sublist(topNodeIndex, bottomNodeIndex + 1);

    return componentsInside.map((componentKey) => _componentKeysToNodeIds[componentKey]!).toList();
  }

  @override
  DocumentSelection? getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset) {
    editorLayoutLog.info('getDocumentSelectionInRegion() - from: $baseOffset, to: $extentOffset');
    final region = Rect.fromPoints(baseOffset, extentOffset);

    String? topNodeId;
    dynamic topNodeBasePosition;
    dynamic topNodeExtentPosition;

    String? bottomNodeId;
    dynamic bottomNodeBasePosition;
    dynamic bottomNodeExtentPosition;

    // Find the top and bottom nodes in the selection region. We do this by finding the component
    // at the top of the selection, then we iterate down the document until we find the bottom
    // component in the selection region. We obtain the document nodes from the components.
    final selectionRegionTopOffset = min(baseOffset.dy, extentOffset.dy);
    final componentSearchStartIndex = max(_findComponentIndexAtOffset(selectionRegionTopOffset), 0);
    for (int i = componentSearchStartIndex; i < _topToBottomComponentKeys.length; i++) {
      final componentKey = _topToBottomComponentKeys[i];
      editorLayoutLog.info(' - considering component "$componentKey"');
      if (componentKey.currentState is! DocumentComponent) {
        editorLayoutLog.info(' - found unknown component: ${componentKey.currentState}');
        continue;
      }

      final nodeId = _componentKeysToNodeIds[componentKey]!;
      if (!_isNodeVisible(nodeId)) {
        // Collapsed components should be avoided at base or extent.
        // They should only be selected when the surrounding components are selected.
        editorLayoutLog.fine(' - node is not visible. Moving on.');
        continue;
      }

      final component = componentKey.currentState as DocumentComponent;

      // Unselectable components should be avoided at base or extent.
      // They should only be selected when the surrounding components are selected.
      if (!component.isVisualSelectionSupported()) {
        editorLayoutLog.fine(' - component does not allow visual selection. Moving on.');
        continue;
      }

      final componentOverlap = _getLocalOverlapWithComponent(region, component);

      if (componentOverlap != null) {
        editorLayoutLog.fine(' - drag intersects: $componentKey}');
        editorLayoutLog.fine(' - intersection: $componentOverlap');
        final componentBaseOffset = _componentOffset(
          componentKey.currentContext!.findRenderObject() as RenderBox,
          baseOffset,
        );
        editorLayoutLog.fine(' - base component offset: $componentBaseOffset');
        final componentExtentOffset = _componentOffset(
          componentKey.currentContext!.findRenderObject() as RenderBox,
          extentOffset,
        );
        editorLayoutLog.fine(' - extent component offset: $componentExtentOffset');

        if (topNodeId == null) {
          // Because we're iterating through components from top to bottom, the
          // first intersecting component that we find must be the top node of
          // the selected area.
          topNodeId = _componentKeysToNodeIds[componentKey];
          topNodeBasePosition = _getNodePositionForComponentOffset(component, componentBaseOffset);
          topNodeExtentPosition = _getNodePositionForComponentOffset(component, componentExtentOffset);
        }
        // We continuously update the bottom node with every additional
        // intersection that we find. This way, when the iteration ends,
        // the last bottom node that we assigned must be the actual bottom
        // node within the selected area.
        bottomNodeId = _componentKeysToNodeIds[componentKey];
        bottomNodeBasePosition = _getNodePositionForComponentOffset(component, componentBaseOffset);
        bottomNodeExtentPosition = _getNodePositionForComponentOffset(component, componentExtentOffset);
      } else if (topNodeId != null) {
        // We already found an overlapping component and the current component doesn't
        // overlap with the region.
        // Because we're iterating through components from top to bottom,
        // it means that there isn't any other component which will overlap,
        // so we can skip the rest of the list.
        break;
      }
    }

    if (topNodeId == null || bottomNodeId == null) {
      // No document content exists in the given region.
      editorLayoutLog
          .finer(' - no document content exists in the region. Node at top: $topNodeId. Node at bottom: $bottomNodeId');
      return null;
    }

    if (topNodeId == bottomNodeId) {
      // Region sits within a single component.
      editorLayoutLog.fine(' - the entire selection sits within a single node: $topNodeId');
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
      editorLayoutLog.fine(' - the selection spans nodes: $topNodeId -> $bottomNodeId');

      // Drag direction determines whether the extent offset is at the
      // top or bottom of the drag rect.
      final isDraggingDown = baseOffset.dy < extentOffset.dy;

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
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: boxContext.findRenderObject());
    final componentBounds = contentOffset & componentBox.size;
    editorLayoutLog.finest("Component bounds: $componentBounds, versus region of interest: $region");

    if (region.overlaps(componentBounds)) {
      // Report the overlap in our local coordinate space.
      return region.translate(-contentOffset.dx, -contentOffset.dy);
    } else {
      return null;
    }
  }

  /// Returns the [NodePosition] that sits at the given [componentOffset].
  ///
  /// If the [componentOffset] is above the component, then the component's
  /// "beginning" position is returned. If the [componentOffset] is below
  /// the component, then the component's "end" position is returned.
  NodePosition? _getNodePositionForComponentOffset(DocumentComponent component, Offset componentOffset) {
    if (componentOffset.dy < 0) {
      return component.getBeginningPosition();
    }
    if (componentOffset.dy > component.getRectForPosition(component.getEndPosition()).bottom) {
      return component.getEndPosition();
    }

    return component.getPositionAtOffset(componentOffset);
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

  GlobalKey? _findComponentClosestToOffset(Offset documentOffset) {
    GlobalKey? nearestComponentKey;
    double nearestDistance = double.infinity;
    for (final pair in _nodeIdsToComponentKeys.entries) {
      final nodeId = pair.key;
      final componentKey = pair.value;

      if (componentKey.currentState is! DocumentComponent) {
        continue;
      }
      if (componentKey.currentContext == null || componentKey.currentContext!.findRenderObject() == null) {
        continue;
      }

      if (!_isNodeVisible(nodeId)) {
        // Ignore any nodes that aren't currently visible.
        continue;
      }

      final componentBox = componentKey.currentContext!.findRenderObject() as RenderBox;
      if (_isOffsetInComponent(componentBox, documentOffset)) {
        return componentKey;
      }

      final distance = _getDistanceToComponent(componentBox, documentOffset);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestComponentKey = componentKey;
      }
    }
    return nearestComponentKey;
  }

  /// Returns the [DocumentPosition] at the beginning of the first node or `null` if the document is empty.
  DocumentPosition? _findFirstPosition() {
    if (_topToBottomComponentKeys.isEmpty) {
      return null;
    }

    final componentKey = _topToBottomComponentKeys.first;
    final component = componentKey.currentState as DocumentComponent;

    return DocumentPosition(
      nodeId: _componentKeysToNodeIds[componentKey]!,
      nodePosition: component.getBeginningPosition(),
    );
  }

  /// Returns the [DocumentPosition] at the end of the last node or `null` if the document is empty.
  DocumentPosition? _findLastPosition() {
    if (_topToBottomComponentKeys.isEmpty) {
      return null;
    }

    final componentKey = _topToBottomComponentKeys.last;
    final component = componentKey.currentState as DocumentComponent;

    return DocumentPosition(
      nodeId: _componentKeysToNodeIds[componentKey]!,
      nodePosition: component.getEndPosition(),
    );
  }

  bool _isOffsetInComponent(RenderBox componentBox, Offset documentOffset) {
    final containerBox = boxContext.findRenderObject() as RenderBox;
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & componentBox.size;

    return contentRect.contains(documentOffset);
  }

  /// Returns the vertical distance between the given [documentOffset] and the
  /// bounds of the given [componentBox].
  double _getDistanceToComponent(RenderBox componentBox, Offset documentOffset) {
    final documentLayoutBox = boxContext.findRenderObject() as RenderBox;
    final componentOffset = componentBox.localToGlobal(Offset.zero, ancestor: documentLayoutBox);
    final componentRect = componentOffset & componentBox.size;

    if (documentOffset.dy < componentRect.top) {
      // The given offset is above the component's bounds.
      return componentRect.top - documentOffset.dy;
    } else if (documentOffset.dy > componentRect.bottom) {
      // The given offset is below the component's bounds.
      return documentOffset.dy - componentRect.bottom;
    } else {
      // The given offset sits within the component bounds.
      return 0;
    }
  }

  Offset _componentOffset(RenderBox componentBox, Offset documentOffset) {
    final containerBox = boxContext.findRenderObject() as RenderBox;
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & componentBox.size;

    return documentOffset - contentRect.topLeft;
  }

  @override
  DocumentComponent? getComponentByNodeId(String nodeId) {
    final key = _nodeIdsToComponentKeys[nodeId];
    if (key == null) {
      editorLayoutLog.info('WARNING: could not find component for node ID: $nodeId');
      return null;
    }
    if (key.currentState is! DocumentComponent) {
      editorLayoutLog.info(
          'WARNING: found component but it\'s not a DocumentComponent: $nodeId, layout key: $key, state: ${key.currentState}, widget: ${key.currentWidget}, context: ${key.currentContext}');
      if (kDebugMode) {
        throw Exception(
            'WARNING: found component but it\'s not a DocumentComponent: $nodeId, layout key: $key, state: ${key.currentState}, widget: ${key.currentWidget}, context: ${key.currentContext}');
      }
      return null;
    }
    return key.currentState as DocumentComponent;
  }

  @override
  Offset getDocumentOffsetFromAncestorOffset(Offset ancestorOffset, [RenderObject? ancestor]) {
    return (boxContext.findRenderObject() as RenderBox).globalToLocal(ancestorOffset, ancestor: ancestor);
  }

  @override
  Offset getAncestorOffsetFromDocumentOffset(Offset documentOffset, [RenderObject? ancestor]) {
    return (boxContext.findRenderObject() as RenderBox).localToGlobal(documentOffset, ancestor: ancestor);
  }

  @override
  Offset getGlobalOffsetFromDocumentOffset(Offset documentOffset) {
    return (boxContext.findRenderObject() as RenderBox).localToGlobal(documentOffset);
  }

  @override
  DocumentPosition? findLastSelectablePosition() {
    NodePosition? nodePosition;
    String? nodeId;

    for (int i = _topToBottomComponentKeys.length - 1; i >= 0; i--) {
      final componentKey = _topToBottomComponentKeys[i];
      final component = componentKey.currentState as DocumentComponent;

      if (component.isVisualSelectionSupported()) {
        nodePosition = component.getEndPosition();
        nodeId = _componentKeysToNodeIds[componentKey];
        break;
      }
    }

    if (nodePosition == null) {
      return null;
    }

    return DocumentPosition(
      nodeId: nodeId!,
      nodePosition: nodePosition,
    );
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onBuildScheduled?.call();
  }

  /// Whether the node with the given [nodeId] is visible in the layout, i.e, it's not
  /// inside a collapsed group.
  bool _isNodeVisible(String nodeId) {
    final group = _nodeIdToGroup[nodeId];
    if (group == null) {
      // The node is not part of a group. It's always visible.
      return true;
    }

    // The root of the group is visible even when the group is collapsed.
    final isVisibleInsideGroup = group.rootNodeId == nodeId || !_isGroupCollapsed(group);
    return isVisibleInsideGroup && _isParentGroupVisible(group);
  }

  bool _isGroupCollapsed(GroupItem group) => _collapsedGroups.contains(group.rootNodeId);

  bool _isParentGroupVisible(GroupItem group) {
    final parentGroup = group.parent;
    if (parentGroup == null) {
      return true;
    }

    return !_isGroupCollapsed(parentGroup) && _isParentGroupVisible(parentGroup);
  }

  @override
  Widget build(BuildContext context) {
    editorLayoutLog.fine("Building document layout");
    final result = SliverToBoxAdapter(
      child: Padding(
        key: _boxKey,
        padding: widget.presenter.viewModel.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _buildDocComponents(),
        ),
      ),
    );

    editorLayoutLog.fine("Done building document");
    return result;
  }

  List<Widget> _buildDocComponents() {
    editorLayoutLog.fine('Building all document layout components');

    final docComponents = <Widget>[];
    final newComponentKeys = <String, GlobalKey>{};
    final newNodeIds = <GlobalKey, String>{};
    _topToBottomComponentKeys.clear();

    final viewModel = widget.presenter.viewModel;
    final componentViewModels = viewModel.componentViewModels;
    editorLayoutLog.fine("Rendering layout view model: ${viewModel.hashCode}");

    final previouslyCollapsedGroups = _collapsedGroups.toSet();

    _collapsedGroups.clear();
    _groups.clear();
    _nodeIdToGroup.clear();

    // Build all doc components and create the groups, if any.
    int currentNodeIndex = 0;
    while (currentNodeIndex < componentViewModels.length) {
      final componentViewModel = componentViewModels[currentNodeIndex];

      _generateAndMapComponentKeyForDocumentNode(
        componentViewModel: componentViewModel,
        componentKeysToNodeIds: newNodeIds,
        nodeIdsToComponentKeys: newComponentKeys,
      );

      // Check if any group builders can start a group at this node.
      bool didNodeStartedGroup = false;
      for (final groupBuilder in widget.groupBuilders) {
        final shouldStartGroup = groupBuilder.canStartGroup(
          nodeIndex: currentNodeIndex,
          viewModels: componentViewModels,
        );

        if (shouldStartGroup) {
          // The current node is the start of a new group. For example,
          // a header that groups all nodes below it until a new header of
          // same level, or smaller, is found. Consume all nodes that can
          // be grouped together.
          final (widget, lastNodeIndexInGroup, groupInfo) = _makeGroup(
            startingNodeIndex: currentNodeIndex,
            groupBuilder: groupBuilder,
            nodeIdsToComponentKeys: newComponentKeys,
            componentKeysToNodeIds: newNodeIds,
            allViewModels: componentViewModels,
            previouslyCollapsedGroups: previouslyCollapsedGroups,
            leaderLink: LeaderLink(),
          );

          didNodeStartedGroup = true;
          docComponents.add(widget);

          // Advance to the next node after the group.
          currentNodeIndex = lastNodeIndexInGroup + 1;

          // The group has been added. Ignore other group builders for this node.
          break;
        }
      }

      if (!didNodeStartedGroup) {
        // The current node is not part of a group. Add it as a regular component.
        docComponents.add(
          _buildComponent(
            componentKey: newComponentKeys[componentViewModel.nodeId]!,
            componentViewModel: componentViewModel,
          ),
        );
        currentNodeIndex += 1;
      }
    }

    _nodeIdsToComponentKeys
      ..clear()
      ..addAll(newComponentKeys);

    _componentKeysToNodeIds
      ..clear()
      ..addAll(newNodeIds);

    editorLayoutLog.finer(' - keys -> IDs after building all components:');
    _nodeIdsToComponentKeys.forEach((key, value) {
      editorLayoutLog.finer('   - $key: $value');
    });

    return docComponents;
  }

  Widget _buildComponent({
    required GlobalKey componentKey,
    required SingleColumnLayoutComponentViewModel componentViewModel,
    LeaderLink? leaderLink,
  }) {
    // Rebuilds whenever this particular component view model changes
    // within the overall layout view model.
    return _PresenterComponentBuilder(
      presenter: widget.presenter,
      watchNode: componentViewModel.nodeId,
      builder: (context, newComponentViewModel) {
        // Converts the component view model into a widget.
        return _Component(
          componentBuilders: widget.componentBuilders,
          componentKey: componentKey,
          componentViewModel: newComponentViewModel,
          leaderLink: leaderLink,
        );
      },
    );
  }

  /// Creates a group of components starting from the given [startingNodeIndex].
  ///
  /// A group contains a group header (the component at [startingNodeIndex]) and
  /// any number of child components.
  ///
  /// Adds each item in [allViewModels] that can be grouped according to the given [groupBuilder].
  ///
  /// The [leaderLink] is attached to the group header, so we can display other widgets near it.
  ///
  /// The [parent] must not be `null` if this group is inside another group.
  (Widget component, int lastNodeIndexInGroup, GroupItem group) _makeGroup({
    required int startingNodeIndex,
    required GroupBuilder groupBuilder,
    required List<SingleColumnLayoutComponentViewModel> allViewModels,
    required LeaderLink leaderLink,
    required Map<String, GlobalKey> nodeIdsToComponentKeys,
    required Map<GlobalKey, String> componentKeysToNodeIds,
    required Set<String> previouslyCollapsedGroups,
    GroupItem? parent,
  }) {
    // All viewmodels that are grouped together.
    final groupedViewModels = <SingleColumnLayoutComponentViewModel>[];

    // All components that are grouped together.
    final groupedComponents = <Widget>[];

    final groupHeader = allViewModels[startingNodeIndex];
    final groupInfo = GroupItem(
      rootNodeId: groupHeader.nodeId,
      parent: parent,
    );
    if (parent != null) {
      parent.add(groupInfo);
    }

    // Restores the collapsed state of the group.
    if (previouslyCollapsedGroups.contains(groupInfo.rootNodeId)) {
      _collapsedGroups.add(groupInfo.rootNodeId);
    }

    groupedViewModels.add(groupHeader);
    groupedComponents.add(
      _buildComponent(
        componentKey: nodeIdsToComponentKeys[groupHeader.nodeId]!,
        componentViewModel: groupHeader,
        leaderLink: leaderLink,
      ),
    );

    // Add all allowed child components to the group.
    int currentNodeIndex = startingNodeIndex + 1;
    while (currentNodeIndex < allViewModels.length) {
      final childViewModel = allViewModels[currentNodeIndex];

      final canAddToGroup = groupBuilder.canAddToGroup(
        nodeIndex: currentNodeIndex,
        allViewModels: allViewModels,
        groupedComponents: UnmodifiableListView(groupedViewModels),
      );
      if (!canAddToGroup) {
        // The current node cannot be added to the group. The group ends
        // before this node.
        break;
      }

      groupedViewModels.add(childViewModel);

      _generateAndMapComponentKeyForDocumentNode(
        componentViewModel: childViewModel,
        componentKeysToNodeIds: componentKeysToNodeIds,
        nodeIdsToComponentKeys: nodeIdsToComponentKeys,
      );

      bool didChildNodeStartedGroup = false;
      for (final childGroupBuilder in widget.groupBuilders) {
        final shouldChildStartGroup = childGroupBuilder.canStartGroup(
          nodeIndex: currentNodeIndex,
          viewModels: allViewModels,
        );
        if (shouldChildStartGroup) {
          // The current child node can start another group. For example,
          // it's a level two header inside a level one header. Let the child
          // create its own group, and add the resulting widget as a child
          // to this group.
          final (widget, lastNodeIndexInChildGroup, childGroup) = _makeGroup(
            startingNodeIndex: currentNodeIndex,
            groupBuilder: childGroupBuilder,
            nodeIdsToComponentKeys: nodeIdsToComponentKeys,
            componentKeysToNodeIds: componentKeysToNodeIds,
            allViewModels: allViewModels,
            previouslyCollapsedGroups: previouslyCollapsedGroups,
            leaderLink: LeaderLink(),
            parent: groupInfo,
          );

          groupInfo.add(childGroup);
          didChildNodeStartedGroup = true;

          // Add a subtree containing the child group to the current group.
          groupedComponents.add(widget);

          // Move to the next node after the child group.
          currentNodeIndex = lastNodeIndexInChildGroup + 1;

          // The child group has been added. Ignore other group builders for this node.
          break;
        }
      }
      if (!didChildNodeStartedGroup) {
        // The current child node is not the start of a group. Add it as a regular component.
        groupedComponents.add(
          _buildComponent(
            componentKey: nodeIdsToComponentKeys[childViewModel.nodeId]!,
            componentViewModel: childViewModel,
          ),
        );

        groupInfo.add(GroupItem(
          rootNodeId: childViewModel.nodeId,
        ));

        // Move to the next node.
        currentNodeIndex += 1;
      }
    }

    _groups.add(groupInfo);

    // Map each node ID to the group which it belongs.
    _nodeIdToGroup[groupInfo.rootNodeId] = groupInfo;
    for (final child in groupInfo.children) {
      _nodeIdToGroup[child.rootNodeId] = groupInfo;
    }

    return (
      groupBuilder.build(
        context,
        headerContentLink: leaderLink,
        groupInfo: groupInfo,
        onCollapsedChanged: (bool collapsed) {
          if (collapsed) {
            _collapsedGroups.add(groupInfo.rootNodeId);
          } else {
            _collapsedGroups.remove(groupInfo.rootNodeId);
          }
        },
        children: groupedComponents,
      ),
      currentNodeIndex - 1,
      groupInfo
    );
  }

  /// Generate a new [GlobalKey] for the given [componentViewModel], if needed, and
  /// creates mappings from the component key to the node ID and vice versa.
  void _generateAndMapComponentKeyForDocumentNode({
    required SingleColumnLayoutComponentViewModel componentViewModel,
    required Map<GlobalKey, String> componentKeysToNodeIds,
    required Map<String, GlobalKey> nodeIdsToComponentKeys,
  }) {
    final componentKey = _obtainComponentKeyForDocumentNode(
      newComponentKeyMap: nodeIdsToComponentKeys,
      nodeId: componentViewModel.nodeId,
    );
    componentKeysToNodeIds[componentKey] = componentViewModel.nodeId;
    editorLayoutLog.finer('Node -> Key: ${componentViewModel.nodeId} -> $componentKey');

    _topToBottomComponentKeys.add(componentKey);
  }

  /// Obtains a `GlobalKey` that should be attached to the component
  /// that represents the given [nodeId].
  ///
  /// If a key was already created for the given [nodeId], that same
  /// key is returned. Otherwise, a new key is created, stored for
  /// later, and returned.
  GlobalKey _obtainComponentKeyForDocumentNode({
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

  /// Finds the component whose vertical bounds contains the offset [dy].
  ///
  /// Returns the index of the component, from top to bottom order.
  int _findComponentIndexAtOffset(double dy) {
    if (_topToBottomComponentKeys.isEmpty) {
      return -1;
    }
    return _binarySearchComponentIndexAtOffset(dy, 0, _topToBottomComponentKeys.length - 1);
  }

  /// Performs a binary search starting from [minIndex] to [maxIndex] to find
  /// a component whose bounds contains the offset [dy].
  ///
  /// Returns the index of the component, from top to bottom order.
  int _binarySearchComponentIndexAtOffset(double dy, int minIndex, int maxIndex) {
    if (minIndex > maxIndex) {
      return -1;
    }

    final middleIndex = ((minIndex + maxIndex) / 2).floor();
    final componentBounds = _getComponentBoundsByIndex(middleIndex);

    if (componentBounds.top <= dy && dy <= componentBounds.bottom) {
      // The component in the middle of the search region is the one we're looking for. Return its index.
      return middleIndex;
    }

    if (dy > componentBounds.bottom) {
      if (middleIndex + 1 < _topToBottomComponentKeys.length) {
        // Check the gap between two components.
        final nextComponentBounds = _getComponentBoundsByIndex(middleIndex + 1);
        final gap = nextComponentBounds.top - componentBounds.bottom;
        if (componentBounds.bottom < dy && dy < (componentBounds.bottom + gap / 2)) {
          // The component we're looking for is somewhere in the bottom half of the current search region.
          return middleIndex;
        }
      }
      return _binarySearchComponentIndexAtOffset(dy, middleIndex + 1, maxIndex);
    } else {
      if (middleIndex - 1 >= 0) {
        // Check the gap between two components.
        final previousComponentBounds = _getComponentBoundsByIndex(middleIndex - 1);
        final gap = componentBounds.top - previousComponentBounds.bottom;
        if ((componentBounds.top - gap / 2) < dy && dy < componentBounds.top) {
          // The component we're looking for is somewhere in the top half of the current search region.
          return middleIndex;
        }
      }
      return _binarySearchComponentIndexAtOffset(dy, minIndex, middleIndex - 1);
    }
  }

  /// Gets the component bounds of the component at [componentIndex] from top to bottom order.
  Rect _getComponentBoundsByIndex(int componentIndex) {
    final componentKey = _topToBottomComponentKeys[componentIndex];
    final component = componentKey.currentState as DocumentComponent;

    final componentBox = component.context.findRenderObject() as RenderBox;
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: boxContext.findRenderObject());
    return contentOffset & componentBox.size;
  }
}

class _PresenterComponentBuilder extends StatefulWidget {
  const _PresenterComponentBuilder({
    Key? key,
    required this.presenter,
    required this.watchNode,
    required this.builder,
  }) : super(key: key);

  final SingleColumnLayoutPresenter presenter;
  final String watchNode;
  final Widget Function(BuildContext, SingleColumnLayoutComponentViewModel) builder;

  @override
  _PresenterComponentBuilderState createState() => _PresenterComponentBuilderState();
}

class _PresenterComponentBuilderState extends State<_PresenterComponentBuilder> {
  late SingleColumnLayoutPresenterChangeListener _presenterListener;

  @override
  void initState() {
    super.initState();

    _presenterListener = SingleColumnLayoutPresenterChangeListener(
      onViewModelChange: _onViewModelChange,
    );
    widget.presenter.addChangeListener(_presenterListener);
  }

  @override
  void didUpdateWidget(_PresenterComponentBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.presenter != oldWidget.presenter) {
      oldWidget.presenter.removeChangeListener(_presenterListener);
      widget.presenter.addChangeListener(_presenterListener);
    }
  }

  @override
  void dispose() {
    widget.presenter.removeChangeListener(_presenterListener);
    super.dispose();
  }

  void _onViewModelChange({
    required List<String> addedComponents,
    required List<String> movedComponents,
    required List<String> changedComponents,
    required List<String> removedComponents,
  }) {
    if (changedComponents.contains(widget.watchNode)) {
      setState(() {
        // Re-build.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    editorLayoutLog.finest("Building component: ${widget.watchNode}");

    final viewModel = widget
        .presenter //
        .viewModel //
        .getComponentViewModelByNodeId(widget.watchNode)!;

    return widget.builder(context, viewModel);
  }
}

/// Builds a component widget for the given [componentViewModel] and
/// binds it to the given [componentKey].
///
/// The specific widget that's build is determined by the given
/// [componentBuilders]. The component widget is rebuilt whenever the
/// given [presenter] reports that the
class _Component extends StatelessWidget {
  const _Component({
    Key? key,
    required this.componentBuilders,
    required this.componentViewModel,
    required this.componentKey,
    this.leaderLink,

    // TODO(srawlins): `unused_element`, when reporting a parameter, is being
    // renamed to `unused_element_parameter`. For now, ignore each; when the SDK
    // constraint is >= 3.6.0, just ignore `unused_element_parameter`.
    // ignore: unused_element, unused_element_parameter
    this.showDebugPaint = false,
  }) : super(key: key);

  /// Builders for every type of component that this layout displays.
  ///
  /// Every type of `DocumentNode` that might appear in the displayed
  /// `document` should have a `ComponentBuilder` that knows how to
  /// render that piece of content.
  final List<ComponentBuilder> componentBuilders;

  /// Global key that will be attached to the root of the component
  /// widget sub-tree.
  final GlobalKey componentKey;

  /// The visual configuration for the component that needs to be built.
  final SingleColumnLayoutComponentViewModel componentViewModel;

  /// An optional [LeaderLink] to be attached to this component content.
  ///
  /// When non-null, a [Leader] widget is placed between the component's
  /// padding and its content.
  final LeaderLink? leaderLink;

  /// Whether to add debug paint to the component.
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final componentContext = SingleColumnDocumentComponentContext(
      context: context,
      componentKey: componentKey,
    );
    for (final componentBuilder in componentBuilders) {
      var component = componentBuilder.createComponent(componentContext, componentViewModel);
      if (component != null) {
        if (leaderLink != null) {
          component = Leader(
            link: leaderLink!,
            child: component,
          );
        }
        // TODO: we might need a SizeChangedNotifier here for the case where two components
        //       change size exactly inversely
        component = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: componentViewModel.maxWidth ?? double.infinity),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: componentViewModel.padding,
              child: component,
            ),
          ),
        );

        return showDebugPaint ? _wrapWithDebugWidget(component) : component;
      }
    }
    return const SizedBox();
  }

  Widget _wrapWithDebugWidget(Widget component) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFF0000), width: 1),
      ),
      child: component,
    );
  }
}

/// Information about a [DocumentNode] that is grouped together with other nodes.
///
/// A [GroupItem] can be a leaf node, i.e., a regular node that doesn't start
/// a new group, for example, a regular paragraph, or it can be a group that contains
/// other nodes. For example, a level one header might have a level two header below it,
/// the level two header itself starts another group, but is part of the level one header's
/// group.
class GroupItem {
  GroupItem({
    required this.rootNodeId,
    this.parent,
  });

  /// The ID of the node that is the root of this group.
  ///
  /// This node appears immediately before its children in the document.
  ///
  /// If this is a leaf node, this is the ID of the node.
  final String rootNodeId;

  /// The items that are grouped together with the node representer by [rootNodeId]
  /// in the document.
  ///
  /// If any [children] is itself another group, only the root node of that group
  /// appears in this list.
  ///
  /// If a [GroupItem] is a leaf node, this list will be empty.
  List<GroupItem> get children => UnmodifiableListView(_children);
  final List<GroupItem> _children = [];

  /// The parent group of this group, if this is a sub-group.
  ///
  /// For example, a level two header might have a level one header as its parent.
  ///
  /// If this is a top-level group, this is `null`.
  final GroupItem? parent;

  /// Whether this group is a leaf node, i.e., it doesn't contain any child nodes.
  bool get isLeaf => _children.isEmpty;

  /// Add [child] as a child of this group.
  void add(GroupItem child) {
    _children.add(child);
  }

  /// The node IDs of all nodes that are a direct or indirect child of this group.
  ///
  /// For example, if this group contains a child group, the node IDs of each child
  /// within the child group appear in this list.
  List<String> get allNodeIds {
    final allNodeIds = <String>[rootNodeId];
    for (final child in _children) {
      allNodeIds.addAll(child.allNodeIds);
    }
    return allNodeIds;
  }

  /// Whether the node with the given [nodeId] is a child of this group
  /// or a child of one of its child groups.
  bool contains(String nodeId) {
    if (rootNodeId == nodeId) {
      return true;
    }

    for (final child in _children) {
      if (child.contains(nodeId)) {
        return true;
      }
    }

    return false;
  }
}
