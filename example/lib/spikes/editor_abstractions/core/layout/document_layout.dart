import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';

import '../document/rich_text_document.dart';
import '../selection/editor_selection.dart';

/// Displays a `RichTextDocument`.
///
/// `DocumentLayout` displays a visual "component" for each
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
class DocumentLayout extends StatefulWidget {
  const DocumentLayout({
    Key key,
    @required this.document,
    @required this.documentSelection,
    @required this.componentBuilder,
    this.showDebugPaint = false,
  }) : super(key: key);

  final RichTextDocument document;
  final List<DocumentNodeSelection> documentSelection;
  final ComponentBuilder componentBuilder;
  final bool showDebugPaint;

  @override
  DocumentLayoutState createState() => DocumentLayoutState();
}

class DocumentLayoutState extends State<DocumentLayout> {
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
      print(' - found tapped node: $component');
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
      // Notice the -1. Experimentally, I determined that if we confine
      // to the exact width, that x-value is considered outside the
      // component RenderBox's. However, 1px less than that is
      // considered to be within the component RenderBox's.
      rawDocumentOffset.dx.clamp(0.0, docBox.size.width - 1),
      rawDocumentOffset.dy,
    );
    print('Getting document position at offset: $documentOffset');

    return getDocumentPositionAtOffset(documentOffset);
  }

  DocumentSelection getDocumentSelectionInRegion(Offset baseOffset, Offset extentOffset) {
    print('getDocumentSelectionInRegion() - from: $baseOffset, to: $extentOffset');
    // Drag direction determines whether the extent offset is at the
    // top or bottom of the drag rect.
    // TODO: this condition is wrong when the user is dragging within a single line of text
    final isDraggingDown = baseOffset.dy < extentOffset.dy;

    final region = Rect.fromPoints(baseOffset, extentOffset);

    String topNodeId;
    TextSelection topTextSelection;
    String bottomNodeId;
    TextSelection bottomTextSelection;
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
        final textSelection = component.getSelectionInRange(componentBaseOffset, componentExtentOffset);

        if (topTextSelection == null) {
          topNodeId = _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key;
          topTextSelection = textSelection;
        }
        bottomNodeId = _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key;
        bottomTextSelection = textSelection;
      }
    }

    print(' - top text selection: $topTextSelection');
    print(' - bottom text selection: $bottomTextSelection');

    if (topTextSelection == null) {
      return null;
    } else if (topNodeId == bottomNodeId) {
      // Region sits within a paragraph.
      return DocumentSelection(
        base: DocumentPosition(
          nodeId: topNodeId,
          nodePosition: TextPosition(offset: topTextSelection.baseOffset),
        ),
        extent: DocumentPosition(
          nodeId: bottomNodeId,
          nodePosition: TextPosition(offset: topTextSelection.extentOffset),
        ),
      );
    } else {
      // Region covers multiple paragraphs.
      return DocumentSelection(
        base: DocumentPosition(
          nodeId: isDraggingDown ? topNodeId : bottomNodeId,
          nodePosition: isDraggingDown ? topTextSelection.base : bottomTextSelection.base,
        ),
        extent: DocumentPosition(
          nodeId: isDraggingDown ? bottomNodeId : topNodeId,
          nodePosition: isDraggingDown ? bottomTextSelection.extent : topTextSelection.extent,
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
    return key != null && key.currentState is DocumentComponent ? key.currentState as DocumentComponent : null;
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
    print(' - doc selection: ${widget.documentSelection}');

    for (final docNode in widget.document.nodes) {
      final componentKey = _createOrTransferComponentKey(
        newComponentKeyMap: newComponentKeys,
        nodeId: docNode.id,
      );
      // print('Node -> Key: ${docNode.id} -> $componentKey');

      _topToBottomComponentKeys.add(componentKey);

      final component = widget.componentBuilder(
        context: context,
        document: widget.document,
        currentNode: docNode,
        currentSelection: widget.documentSelection,
        key: componentKey,
        selectedNode: widget.documentSelection.firstWhere(
          (element) => element.nodeId == docNode.id,
          orElse: () => null,
        ),
        showDebugPaint: widget.showDebugPaint,
      );

      docComponents.add(component);
    }

    _nodeIdsToComponentKeys
      ..clear()
      ..addAll(newComponentKeys);

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
}

/// Contract for all widgets that operate as document components
/// within a `DocumentLayout`.
mixin DocumentComponent<T extends StatefulWidget> on State<T> {
  dynamic getPositionAtOffset(Offset localOffset);

  Offset getOffsetForPosition(dynamic nodePosition);

  dynamic getBeginningPosition();

  dynamic getBeginningPositionNearX(double x);

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
  @required List<DocumentNodeSelection> currentSelection,
  // TODO: get rid of selectedNode param
  @required DocumentNodeSelection selectedNode,
  @required GlobalKey key,
  bool showDebugPaint,
});
