import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

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

  /// Adds a debugging UI to the document layout, when true.
  final bool showDebugPaint;

  @override
  _SingleColumnDocumentLayoutState createState() => _SingleColumnDocumentLayoutState();
}

class _SingleColumnDocumentLayoutState extends State<SingleColumnDocumentLayout> implements DocumentLayout {
  final Map<String, GlobalKey> _nodeIdsToComponentKeys = {};

  // Keys are cached in top-to-bottom order so that we can visually
  // traverse components without repeatedly querying a `Document`
  // to determine component ordering.
  final List<GlobalKey> _topToBottomComponentKeys = [];

  late SingleColumnLayoutPresenterChangeListener _presenterListener;

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
    required List<String> changedComponents,
    required List<String> removedComponents,
  }) {
    if (addedComponents.isNotEmpty || removedComponents.isNotEmpty) {
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
    final docBox = context.findRenderObject() as RenderBox;
    final documentOffset = Offset(
      // Notice the +1/-1. Experimentally, I determined that if we confine
      // to the exact width, that x-value is considered outside the
      // component RenderBox's. However, 1px less than that is
      // considered to be within the component RenderBox's.
      rawDocumentOffset.dx.clamp(1.0, max(docBox.size.width - 1.0, 1.0)),
      rawDocumentOffset.dy,
    );
    editorLayoutLog.info('Getting document position near offset: $documentOffset');

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
      nodeId: _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key,
      nodePosition: componentPosition,
    );
    editorLayoutLog.info(' - selection at offset: $selectionAtOffset');
    return selectionAtOffset;
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
    if (base.nodeId == extent.nodeId) {
      // Selection within a single node.
      topComponent = extentComponent;
      final componentBoundingBox = extentComponent.getRectForSelection(base.nodePosition, extent.nodePosition);
      componentBoundingBoxes.add(componentBoundingBox);
    } else {
      // Selection across nodes.
      final selectedNodes = _getNodeIdsBetween(base.nodeId, extent.nodeId);
      topComponent = getComponentByNodeId(selectedNodes.first)!;
      final startPosition = selectedNodes.first == base.nodeId ? base.nodePosition : extent.nodePosition;
      final endPosition = selectedNodes.first == extent.nodeId ? extent.nodePosition : base.nodePosition;

      for (int i = 0; i < selectedNodes.length; ++i) {
        final component = getComponentByNodeId(selectedNodes[i])!;

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

  List<String> _getNodeIdsBetween(String baseNodeId, String extentNodeId) {
    final baseComponentKey = _nodeIdsToComponentKeys[baseNodeId]!;
    final baseComponentIndex = _topToBottomComponentKeys.indexOf(baseComponentKey);
    final extentComponentKey = _nodeIdsToComponentKeys[extentNodeId]!;
    final extentComponentIndex = _topToBottomComponentKeys.indexOf(extentComponentKey);

    final topNodeIndex = baseComponentIndex <= extentComponentIndex ? baseComponentIndex : extentComponentIndex;
    final bottomNodeIndex = topNodeIndex == baseComponentIndex ? extentComponentIndex : baseComponentIndex;
    final componentsInside = _topToBottomComponentKeys.sublist(topNodeIndex, bottomNodeIndex + 1);

    return componentsInside.map((componentKey) {
      return _nodeIdsToComponentKeys.entries.firstWhere((entry) {
        return entry.value == componentKey;
      }).key;
    }).toList();
  }

  @override
  DocumentSelection? getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset) {
    editorLayoutLog.info('getDocumentSelectionInRegion() - from: $baseOffset, to: $extentOffset');
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
      editorLayoutLog.info(' - considering component "$componentKey"');
      if (componentKey.currentState is! DocumentComponent) {
        editorLayoutLog.info(' - found unknown component: ${componentKey.currentState}');
        continue;
      }

      final component = componentKey.currentState as DocumentComponent;

      final componentOverlap = _getLocalOverlapWithComponent(region, component);

      if (componentOverlap != null) {
        editorLayoutLog.info(' - drag intersects: $componentKey}');
        editorLayoutLog.info(' - intersection: $componentOverlap');
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

  bool _isOffsetInComponent(RenderBox componentBox, Offset documentOffset) {
    final containerBox = context.findRenderObject() as RenderBox;
    final contentOffset = componentBox.localToGlobal(Offset.zero, ancestor: containerBox);
    final contentRect = contentOffset & componentBox.size;

    return contentRect.contains(documentOffset);
  }

  /// Returns the vertical distance between the given [documentOffset] and the
  /// bounds of the given [componentBox].
  double _getDistanceToComponent(RenderBox componentBox, Offset documentOffset) {
    final documentLayoutBox = context.findRenderObject() as RenderBox;
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
    final containerBox = context.findRenderObject() as RenderBox;
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
  Offset getDocumentOffsetFromAncestorOffset(Offset ancestorOffset, RenderObject ancestor) {
    return (context.findRenderObject() as RenderBox).globalToLocal(ancestorOffset, ancestor: ancestor);
  }

  @override
  Offset getAncestorOffsetFromDocumentOffset(Offset documentOffset, RenderObject ancestor) {
    return (context.findRenderObject() as RenderBox).localToGlobal(documentOffset, ancestor: ancestor);
  }

  @override
  Offset getGlobalOffsetFromDocumentOffset(Offset documentOffset) {
    return (context.findRenderObject() as RenderBox).localToGlobal(documentOffset);
  }

  @override
  Widget build(BuildContext context) {
    editorLayoutLog.fine("Building document layout");
    return Padding(
      padding: widget.presenter.viewModel.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _buildDocComponents(),
      ),
    );
  }

  List<Widget> _buildDocComponents() {
    editorLayoutLog.fine('Building all document layout components');

    final docComponents = <Widget>[];
    final newComponentKeys = <String, GlobalKey>{};
    _topToBottomComponentKeys.clear();

    final viewModel = widget.presenter.viewModel;
    editorLayoutLog.fine("Rendering layout view model: ${viewModel.hashCode}");
    for (final componentViewModel in viewModel.componentViewModels) {
      final componentKey = _obtainComponentKeyForDocumentNode(
        newComponentKeyMap: newComponentKeys,
        nodeId: componentViewModel.nodeId,
      );
      editorLayoutLog.finer('Node -> Key: ${componentViewModel.nodeId} -> $componentKey');

      _topToBottomComponentKeys.add(componentKey);

      docComponents.add(
        // Rebuilds whenever this particular component view model changes
        // within the overall layout view model.
        _PresenterComponentBuilder(
          presenter: widget.presenter,
          watchNode: componentViewModel.nodeId,
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

    editorLayoutLog.finer(' - keys -> IDs after building all components:');
    _nodeIdsToComponentKeys.forEach((key, value) {
      editorLayoutLog.finer('   - $key: $value');
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
      newComponentKeyMap[nodeId] = GlobalKey();
    }
    return newComponentKeyMap[nodeId]!;
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
