import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:flutter_richtext/src/infrastructure/_logging.dart';

import 'document_selection.dart';
import 'document.dart';

final _log = Logger(scope: 'DocumentLayout');

/// Abstract representation of a document layout.
///
/// Regardless of how a document is displayed, a `DocumentLayout` needs
/// to answer various questions about where content sits within the layout.
/// A `DocumentLayout` is the source of truth for the mapping between logical
/// `DocumentPosition`s and visual (x,y) positions. For example, this mapping
/// allows the app to determine which portion of a `String` should be selected
/// when the user drags from one (x,y) position to another (x,y) position on
/// the screen.
abstract class DocumentLayout {
  /// Returns the `DocumentPosition` that corresponds to the given
  /// `layoutOffset`, or `null` if the `layoutOffset` does not exist
  /// within a piece of document content.
  DocumentPosition? getDocumentPositionAtOffset(Offset layoutOffset);

  /// Returns the `DocumentPosition` at the y-value of the given `layoutOffset`
  /// that sits closest to the x-value of the given `layoutOffset`, or `null`
  /// if there is no document content at the given y-value.
  ///
  /// For example, a y-position within the first line of a paragraph, and an
  /// x-position that sits to the left of the paragraph would return the
  /// `DocumentPosition` for the first character within the paragraph.
  DocumentPosition? getDocumentPositionNearestToOffset(Offset layoutOffset);

  /// Returns the bounding box of the component that renders the given
  /// `position`, or `null` if no corresponding component can be found, or
  /// the corresponding component has not yet been laid out.
  Rect? getRectForPosition(DocumentPosition position);

  /// Returns a `DocumentSelection` that begins near `baseOffset` and extends
  /// to `extentOffset`, or `null` if no document content sits between the
  /// provided points.
  DocumentSelection? getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset);

  /// Returns the `MouseCursor` that's desired by the component at `documentOffset`, or
  /// `null` if the document has no preference for the `MouseCursor` at the given
  /// `documentOffset`.
  MouseCursor? getDesiredCursorAtOffset(Offset documentOffset);

  /// Returns the `DocumentComponent` that renders the `DocumentNode` with
  /// the given `nodeId`, or `null` if no such component exists.
  DocumentComponent? getComponentByNodeId(String nodeId);
}

/// Contract for all widgets that operate as document components
/// within a `DocumentLayout`.
mixin DocumentComponent<T extends StatefulWidget> on State<T> {
  /// Returns the node position within this component at the given
  /// `localOffset`, or `null` if the `localOffset` does not sit
  /// within any content.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  dynamic? getPositionAtOffset(Offset localOffset);

  /// Returns the (x,y) `Offset` for the given `nodePosition`.
  ///
  /// If the given `nodePosition` corresponds to a component where
  /// a position is ambiguous with regard to an (x,y) `Offset`, like
  /// an image or horizontal rule, it's up to that component to
  /// choose a reasonable `Offset`, such as the center of the image.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  Offset getOffsetForPosition(dynamic nodePosition);

  /// Returns a `Rect` for the given `nodePosition`.
  ///
  /// If the given `nodePosition` corresponds to a single (x,y)
  /// offset rather than a `Rect`, a `Rect` with zero width and
  /// height may be returned.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  Rect? getRectForPosition(dynamic nodePosition);

  /// Returns the node position that represents the "beginning" of
  /// the content within this component, such as the first character
  /// of a paragraph.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  dynamic getBeginningPosition();

  /// Returns the earliest position within this component's
  /// `DocumentNode` that appears at or near the given `x` position.
  ///
  /// This is useful, for example, when moving selection into the
  /// beginning of some text while maintaining the existing horizontal
  /// position of the selection.
  dynamic getBeginningPositionNearX(double x);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved left one unit,
  /// as interpreted by this component/node, in conjunction with
  /// any relevant `movementModifier`.
  ///
  /// The structure and options for `movementModifier`s is
  /// determined by each component/node combination.
  ///
  /// Returns `null` if the concept of horizontal movement does not
  /// make sense for this component.
  ///
  /// Returns `null` if there is nowhere to move left within this
  /// component, such as when the `currentPosition` is the first
  /// character within a paragraph.
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
  /// component, such as when the `currentPosition` refers to the
  /// last character in a paragraph.
  dynamic movePositionRight(dynamic currentPosition, [Map<String, dynamic> movementModifiers]);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved up one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move up within this
  /// component, such as when the `currentPosition` refers to
  /// the first line of a paragraph.
  dynamic movePositionUp(dynamic currentPosition);

  /// Returns a new position within this component's node that
  /// corresponds to the `currentPosition` moved down one unit,
  /// as interpreted by this component/node.
  ///
  /// Returns null if the concept of vertical movement does not
  /// make sense for this component.
  ///
  /// Returns null if there is nowhere to move down within this
  /// component, such as when the `currentPosition` refers to
  /// the last line of a paragraph.
  dynamic movePositionDown(dynamic currentPosition);

  /// Returns the node position that represents the "end" of
  /// the content within this component, such as the last character
  /// of a paragraph.
  ///
  /// See `Document` for more information about `DocumentNode`s and
  /// node positions.
  dynamic getEndPosition();

  /// Returns the latest position within this component's
  /// `DocumentNode` that appears at or near the given `x` position.
  ///
  /// This is useful, for example, when moving selection into the
  /// end of some text while maintaining the existing horizontal
  /// position of the selection.
  dynamic getEndPositionNearX(double x);

  /// Returns a selection of content that appears between the `localBaseOffset`
  /// and the `localExtentOffset`.
  ///
  /// The selection type depends on the type of `DocumentNode` that this
  /// component displays.
  dynamic getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset);

  /// Returns a node selection within this component's `DocumentNode` that
  /// is collapsed at the given `nodePosition`.
  dynamic getCollapsedSelectionAt(dynamic nodePosition);

  /// Returns a node selection within this component's `DocumentNode` that
  /// spans from `basePosition` to `extentPosition`.
  dynamic getSelectionBetween({
    @required dynamic basePosition,
    @required dynamic extentPosition,
  });

  /// Returns a node selection that includes all content within the node.
  dynamic getSelectionOfEverything();

  /// Returns the desired `MouseCursor` at the given (x,y) `localOffset`, or
  /// `null` if this component has no preference for the cursor style.
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset);
}

/// Contract for document components that include editable text.
///
/// Examples: paragraphs, list items, images with captions.
///
/// The node positions accepted by a `TextComposable` are `dynamic`
/// rather than `TextPosition`s because an editor might be configured
/// to include complex text composition, like tables, which might
/// choose to index positions based on cell IDs, or row and column
/// indices.
abstract class TextComposable {
  /// Returns a `TextSelection` that encompasses the entire word
  /// found at the given `nodePosition`.
  TextSelection getWordSelectionAt(dynamic nodePosition);

  /// Returns all text surrounding `nodePosition` that is not
  /// broken by white space.
  String getContiguousTextAt(dynamic nodePosition);

  /// Returns the node position that corresponds to a text location
  /// that is one line above the given `nodePosition`, or `null` if
  /// there is no position one line up.
  dynamic? getPositionOneLineUp(dynamic nodePosition);

  /// Returns the node position that corresponds to a text location
  /// that is one line below the given `nodePosition`, or `null` if
  /// there is no position one line down.
  dynamic? getPositionOneLineDown(dynamic nodePosition);

  /// Returns the node position that corresponds to the first character
  /// in the line of text that contains the given `nodePosition`.
  dynamic getPositionAtStartOfLine(dynamic nodePosition);

  /// Returns the node position that corresponds to the last character
  /// in the line of text that contains the given `nodePosition`.
  dynamic getPositionAtEndOfLine(dynamic nodePosition);
}

/// Builds a widget that renders the desired UI for one or
/// more `DocumentNode`s.
///
/// Every widget returned from a `ComponentBuilder` should be
/// a `StatefulWidget` that mixes in `DocumentComponent`.
///
/// A `ComponentBuilder` might be invoked with a type of
/// `DocumentNode` that it doesn't know how to work with. When
/// this happens, the `ComponentBuilder` should return `null`,
/// indicating that it doesn't know how to build a component
/// for the given `DocumentNode`.
///
/// See `ComponentContext` for expectations about how to use
/// the context to build a component widget.
typedef ComponentBuilder = Widget? Function(ComponentContext);

/// Information that is provided to a `ComponentBuilder` to
/// construct an appropriate `DocumentComponent` widget.
class ComponentContext {
  const ComponentContext({
    required this.context,
    required this.document,
    required this.documentNode,
    required this.componentKey,
    this.nodeSelection,
    this.extensions = const {},
  });

  /// The `BuildContext` for the parent of the `DocumentComponent`
  /// that needs to be built.
  final BuildContext context;

  /// The `Document` that contains the `DocumentNode`.
  final Document document;

  /// The `DocumentNode` for which a component is needed.
  final DocumentNode documentNode;

  /// A `GlobalKey` that must be assigned to the `DocumentComponent`
  /// widget returned by a `ComponentBuilder`.
  ///
  /// The `componentKey` is used by the `DocumentLayout` to query for
  /// node-specific information, like node positions and selections.
  final GlobalKey componentKey;

  /// The current selected region within the `documentNode`.
  ///
  /// The component should paint this selection.
  final DocumentNodeSelection? nodeSelection;

  /// May contain additional information needed to build the
  /// component, based on the specific type of the `documentNode`.
  final Map<String, dynamic> extensions;
}

/// Displays a `Document`.
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
    if (componentRect == null) {
      return null;
    }

    final componentBox = component.context.findRenderObject() as RenderBox;
    final docOffset = componentBox.localToGlobal(Offset.zero, ancestor: context.findRenderObject());

    return componentRect.translate(docOffset.dx, docOffset.dy);
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
