import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/render_sliver_ext.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '_presenter.dart';

class _PrecalculateExtents extends ExtentPrecalculationPolicy {
  @override
  bool shouldPrecalculateExtents(ExtentPrecalculationContext context) {
    // TODO: Reconsider implementing adaptive extent estimation instead.
    return true;
  }
}

extension on DocumentComponent {
  bool get isActive {
    final renderObject = (context as Element).renderObject;
    return renderObject?.attached == true;
  }
}

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
    this.onBuildScheduled,
    this.showDebugPaint = false,
    this.documentSelection,
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

  final ValueListenable<DocumentSelection?>? documentSelection;

  @override
  State createState() => _SingleColumnDocumentLayoutState();
}

class _SingleColumnDocumentLayoutState extends State<SingleColumnDocumentLayout> implements ScrollableDocumentLayout {
  final Map<String, GlobalKey> _nodeIdsToComponentKeys = {};
  final Map<GlobalKey, String> _componentKeysToNodeIds = {};

  // Keys are cached in top-to-bottom order so that we can visually
  // traverse components without repeatedly querying a `Document`
  // to determine component ordering.
  final List<GlobalKey> _topToBottomComponentKeys = [];

  late SingleColumnLayoutPresenterChangeListener _presenterListener;

  final _listController = ListController();

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
    _listController.dispose();
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
    final docBox = context.findRenderObject() as RenderSliver;
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
    if (componentKey.currentContext == null) {
      return false;
    }
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
    if (componentKey.currentContext == null) {
      return false;
    }
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
    final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());

    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    return componentEdge.translate(docOffset.dx, docOffset.dy + scrollOffset);
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
    final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());

    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    return componentRect.translate(docOffset.dx, docOffset.dy + scrollOffset);
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
    final documentLayoutBox = context.findRenderObject() as RenderSliver;
    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
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
            componentOffsetInDocument.dy + scrollOffset,
          );
      componentBoundingBoxes.add(componentBoundingBox);
    } else {
      // Selection across nodes.
      final selectedNodes = _getNodeIdsBetween(base.nodeId, extent.nodeId);
      topComponent = getComponentByNodeId(selectedNodes.first)!;
      final startPosition = selectedNodes.first == base.nodeId ? base.nodePosition : extent.nodePosition;
      final endPosition = selectedNodes.first == base.nodeId ? extent.nodePosition : base.nodePosition;

      for (int i = 0; i < selectedNodes.length; ++i) {
        final component = getComponentByNodeId(selectedNodes[i]);
        if (component == null) {
          continue;
        }
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
            componentOffsetInDocument.dy + scrollOffset,
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
            componentOffsetInDocument.dy + scrollOffset,
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
            componentOffsetInDocument.dy + scrollOffset,
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
    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    final contentOffset =
        componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject()).translate(0, scrollOffset);
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
    for (final componentKey in _nodeIdsToComponentKeys.values) {
      if (componentKey.currentState is! DocumentComponent) {
        continue;
      }
      if (componentKey.currentContext == null || componentKey.currentContext!.findRenderObject() == null) {
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
    final scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    final containerBox = context.findRenderObject();
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: containerBox).translate(0, scrollOffset);
    final contentRect = contentOffset & componentBox.size;

    return contentRect.contains(documentOffset);
  }

  /// Returns the vertical distance between the given [documentOffset] and the
  /// bounds of the given [componentBox].
  double _getDistanceToComponent(RenderBox componentBox, Offset documentOffset) {
    final scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    final documentLayoutBox = context.findRenderObject();
    final componentOffset =
        componentBox.localToGlobal(Offset.zero, ancestor: documentLayoutBox).translate(0, scrollOffset);
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
    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    final containerBox = context.findRenderObject();
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: containerBox).translate(0, scrollOffset);
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
    if (key.currentState == null) {
      // Expected with super_sliver_list based layout.
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
    final res = key.currentState as DocumentComponent;
    if (!res.isActive) {
      return null;
    }
    return res;
  }

  @override
  Offset getDocumentOffsetFromAncestorOffset(Offset ancestorOffset, [RenderObject? ancestor]) {
    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    return (context.findRenderObject() as RenderSliver)
        .globalToLocal(ancestorOffset, ancestor: ancestor)
        .translate(0, scrollOffset);
  }

  @override
  Offset getAncestorOffsetFromDocumentOffset(Offset documentOffset, [RenderObject? ancestor]) {
    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    return (context.findRenderObject() as RenderSliver)
        .localToGlobal(documentOffset, ancestor: ancestor)
        .translate(0, -scrollOffset);
  }

  @override
  Offset getGlobalOffsetFromDocumentOffset(Offset documentOffset) {
    double scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    return (context.findRenderObject() as RenderSliver).localToGlobal(documentOffset).translate(0, -scrollOffset);
  }

  @override
  DocumentPosition? findLastSelectablePosition() {
    NodePosition? nodePosition;
    String? nodeId;

    for (int i = _topToBottomComponentKeys.length - 1; i >= 0; i--) {
      final componentKey = _topToBottomComponentKeys[i];
      final component = componentKey.currentState as DocumentComponent?;
      if (component == null || !component.isActive) {
        continue;
      }

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

  @override
  Widget build(BuildContext context) {
    editorLayoutLog.fine("Building document layout");
    final result = SliverPadding(
      padding: widget.presenter.viewModel.padding,
      sliver: SuperSliverList(
        listController: _listController,
        layoutKeptAliveChildren: true,
        extentPrecalculationPolicy: _PrecalculateExtents(),
        delegate: SliverChildListDelegate(_buildDocComponents()),
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
    editorLayoutLog.fine(() => "Rendering layout view model: ${viewModel.hashCode}");
    for (final componentViewModel in viewModel.componentViewModels) {
      final componentKey = _obtainComponentKeyForDocumentNode(
        newComponentKeyMap: newComponentKeys,
        nodeId: componentViewModel.nodeId,
      );
      newNodeIds[componentKey] = componentViewModel.nodeId;
      editorLayoutLog.finer(() => 'Node -> Key: ${componentViewModel.nodeId} -> $componentKey');

      _topToBottomComponentKeys.add(componentKey);

      docComponents.add(
        // Rebuilds whenever this particular component view model changes
        // within the overall layout view model.
        _PresenterComponentBuilder(
          presenter: widget.presenter,
          watchNode: componentViewModel.nodeId,
          firstOrLast: componentViewModel == viewModel.componentViewModels.first ||
              componentViewModel == viewModel.componentViewModels.last,
          selection: widget.documentSelection,
          builder: (context, newComponentViewModel) {
            // Converts the component view model into a widget.
            return _Component(
              componentBuilders: widget.componentBuilders,
              componentKey: componentKey,
              componentViewModel: newComponentViewModel,
            );
          },
        ),
      );
    }

    _nodeIdsToComponentKeys
      ..clear()
      ..addAll(newComponentKeys);

    _componentKeysToNodeIds
      ..clear()
      ..addAll(newNodeIds);

    editorLayoutLog.finer(() => ' - keys -> IDs after building all components:');
    _nodeIdsToComponentKeys.forEach((key, value) {
      editorLayoutLog.finer(() => '   - $key: $value');
    });

    return docComponents;
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
      newComponentKeyMap[nodeId] = GlobalKey(
        debugLabel: 'DocumentComponent-$nodeId',
      );
    }
    return newComponentKeyMap[nodeId]!;
  }

  /// Finds the component whose vertical bounds contains the offset [dy].
  ///
  /// Returns the index of the component, from top to bottom order.
  int _findComponentIndexAtOffset(double dy) {
    final scrollOffset = (context.findRenderObject() as RenderSliver).constraints.scrollOffset;
    for (int i = 0; i < _topToBottomComponentKeys.length; i++) {
      final componentKey = _topToBottomComponentKeys[i];
      final component = componentKey.currentState as DocumentComponent?;
      if (component == null || !component.isActive) {
        continue;
      }

      final componentBox = component.context.findRenderObject() as RenderBox;
      final contentOffset =
          componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject()).translate(0, scrollOffset);
      final componentRect = contentOffset & componentBox.size;

      if (componentRect.top <= dy && dy <= componentRect.bottom) {
        return i;
      }
    }
    return -1;
  }

  @override
  void ensureVisible(DocumentPosition position) {
    final component = getComponentByNodeId(position.nodeId);

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;

    if (component == null) {
      final key = _nodeIdsToComponentKeys[position.nodeId];
      final index = _topToBottomComponentKeys.indexOf(key!);
      _listController.jumpToItem(
        index: index,
        scrollController: scrollable.widget.controller!,
        alignment: 0.0,
      );
      return;
    }

    // final index = _topToBottomComponentKeys.indexWhere((key) => key.currentState == component);
    final componentRect = component.getRectForPosition(position.nodePosition); // .translate(padding.left, padding.top);
    // print('CR $index $componentRect');

    {
      final viewport = RenderAbstractViewport.maybeOf(context.findRenderObject());
      if (viewport == null) return;

      final target = component.context.findRenderObject();
      final minOffset = viewport
          .getOffsetToRevealExt(
            target!,
            0.0,
            rect: componentRect,
            esimationOnly: true,
          )
          .offset;

      final position = scrollable.position;

      if (position.pixels > minOffset) {
        final offset = viewport
            .getOffsetToRevealExt(
              target,
              0.0,
              rect: componentRect,
              esimationOnly: false,
            )
            .offset;
        scrollable.position.moveTo(offset);
      } else {
        final maxOffset = viewport.getOffsetToRevealExt(target, 1.0, rect: componentRect).offset;
        if (position.pixels < maxOffset) {
          final offset = viewport
              .getOffsetToRevealExt(
                target,
                1.0,
                rect: componentRect,
                esimationOnly: false,
              )
              .offset;
          scrollable.position.moveTo(offset);
        }
      }
    }
  }

  @override
  void animateToBeginningOfDocument({required Duration duration, required Curve curve}) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;

    _listController.animateToItem(
      index: 0,
      scrollController: scrollable.widget.controller!,
      alignment: 0.0,
      duration: (_) => duration,
      curve: (_) => curve,
    );
  }

  @override
  void animateToEndOfDocument({required Duration duration, required Curve curve}) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;

    _listController.animateToItem(
      index: _componentKeysToNodeIds.length - 1,
      scrollController: scrollable.widget.controller!,
      alignment: 1.0,
      duration: (_) => duration,
      curve: (_) => curve,
    );
  }
}

class _PresenterComponentBuilder extends StatefulWidget {
  const _PresenterComponentBuilder({
    Key? key,
    required this.presenter,
    required this.watchNode,
    required this.builder,
    required this.firstOrLast,
    required this.selection,
  }) : super(key: key);

  final SingleColumnLayoutPresenter presenter;
  final String watchNode;
  final Widget Function(BuildContext, SingleColumnLayoutComponentViewModel) builder;
  final ValueListenable<DocumentSelection?>? selection;
  final bool firstOrLast;

  @override
  _PresenterComponentBuilderState createState() => _PresenterComponentBuilderState();
}

class _PresenterComponentBuilderState extends State<_PresenterComponentBuilder> with AutomaticKeepAliveClientMixin {
  late SingleColumnLayoutPresenterChangeListener _presenterListener;

  @override
  void initState() {
    super.initState();

    _presenterListener = SingleColumnLayoutPresenterChangeListener(
      onViewModelChange: _onViewModelChange,
    );
    widget.presenter.addChangeListener(_presenterListener);
    widget.selection?.addListener(_selectionDidChange);
  }

  @override
  void didUpdateWidget(_PresenterComponentBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.presenter != oldWidget.presenter) {
      oldWidget.presenter.removeChangeListener(_presenterListener);
      widget.presenter.addChangeListener(_presenterListener);
    }
    if (widget.selection != oldWidget.selection) {
      oldWidget.selection?.removeListener(_selectionDidChange);
      widget.selection?.addListener(_selectionDidChange);
    }
  }

  @override
  void dispose() {
    widget.presenter.removeChangeListener(_presenterListener);
    widget.selection?.removeListener(_selectionDidChange);
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
    super.build(context);
    editorLayoutLog.finest("Building component: ${widget.watchNode}");

    final viewModel = widget
        .presenter //
        .viewModel //
        .getComponentViewModelByNodeId(widget.watchNode)!;

    return widget.builder(context, viewModel);
  }

  @override
  bool get wantKeepAlive {
    if (widget.firstOrLast) {
      return true;
    }
    final selection = widget.selection?.value;
    if (selection != null) {
      if (selection.start.nodeId == widget.watchNode || selection.end.nodeId == widget.watchNode) {
        return true;
      }
    }
    return false;
  }

  void _selectionDidChange() {
    updateKeepAlive();
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
        // TODO: we might need a SizeChangedNotifier here for the case where two components
        //       change size exactly inversely
        component = Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: componentViewModel.maxWidth ?? double.infinity),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: componentViewModel.padding,
                child: component,
              ),
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
