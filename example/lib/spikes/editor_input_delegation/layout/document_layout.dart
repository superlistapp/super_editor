import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';

import '../document/rich_text_document.dart';
import '../selection/editor_selection.dart';
import 'components/paragraph/selectable_text.dart';

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
    this.showDebugPaint = false,
  }) : super(key: key);

  final RichTextDocument document;
  final List<DocumentNodeSelection> documentSelection;
  final bool showDebugPaint;

  @override
  DocumentLayoutState createState() => DocumentLayoutState();
}

class DocumentLayoutState extends State<DocumentLayout> {
  final Map<String, GlobalKey> _nodeIdsToComponentKeys = {};
  final List<GlobalKey> _topToBottomComponentKeys = [];

  DocumentPosition getDocumentPositionAtOffset(Offset rawDocumentOffset) {
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

    final componentKey = _findComponentAtOffset(documentOffset);
    if (componentKey != null) {
      final textLayout = componentKey.currentState as TextLayout;
      final textBox = componentKey.currentContext.findRenderObject() as RenderBox;
      print(' - found tapped node: $textLayout');
      final componentOffset = _componentOffset(textBox, documentOffset);
      final textPosition = textLayout.getPositionAtOffset(componentOffset);

      final selectionAtOffset = DocumentPosition<TextPosition>(
        nodeId: _nodeIdsToComponentKeys.entries.firstWhere((element) => element.value == componentKey).key,
        nodePosition: textPosition,
      );
      print(' - selection at offset: $selectionAtOffset');
      return selectionAtOffset;
    }

    return null;
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
      if (componentKey.currentState is! TextLayout) {
        print(' - found unknown component: ${componentKey.currentState}');
        continue;
      }

      final textLayout = componentKey.currentState as TextLayout;

      final dragIntersection = _getDragIntersectionWith(region, textLayout);

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
        final textSelection = textLayout.getSelectionInRect(componentBaseOffset, componentExtentOffset);

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

  Rect _getDragIntersectionWith(Rect region, TextLayout textLayout) {
    return textLayout.calculateLocalOverlap(
      region: region,
      ancestorCoordinateSpace: context.findRenderObject(),
    );
  }

  MouseCursor getDesiredCursorAtOffset(Offset documentOffset) {
    final componentKey = _findComponentAtOffset(documentOffset);
    if (componentKey != null) {
      final componentBox = componentKey.currentContext.findRenderObject() as RenderBox;
      final componentOffset = _componentOffset(componentBox, documentOffset);

      final textLayout = componentKey.currentState as TextLayout;
      final isCursorOverText = textLayout.isTextAtOffset(componentOffset);

      return isCursorOverText ? SystemMouseCursors.text : null;
    }
    return null;
  }

  GlobalKey _findComponentAtOffset(Offset documentOffset) {
    // print('Finding document node at offset: $documentOffset');
    for (final componentKey in _nodeIdsToComponentKeys.values) {
      // print(' - considering component "$componentKey"');
      if (componentKey.currentState is! TextLayout) {
        // print(' - found unknown component: ${componentKey.currentState}');
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

  // TODO: genericize component access instead of always assuming its a text layout
  SelectableTextState getSelectableTextByNodeId(String nodeId) {
    final key = _nodeIdsToComponentKeys[nodeId];
    return key != null && key.currentState is SelectableTextState ? key.currentState as SelectableTextState : null;
  }

  @override
  Widget build(BuildContext context) {
    // print('Building document layout:');
    final docComponents = _buildDocComponents();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final docComponent in docComponents) ...[
          docComponent,
          SizedBox(height: 16),
        ],
      ],
    );
  }

  List<Widget> _buildDocComponents() {
    final docComponents = <Widget>[];
    final newComponentKeys = <String, GlobalKey>{};
    _topToBottomComponentKeys.clear();
    for (final docNode in widget.document.nodes) {
      final componentKey = _createOrTransferComponentKey(
        newComponentKeyMap: newComponentKeys,
        nodeId: docNode.id,
      );
      // print('Node -> Key: ${docNode.id} -> $componentKey');

      _topToBottomComponentKeys.add(componentKey);

      docComponents.add(
        _buildDocumentComponent(
          key: componentKey,
          docNode: docNode,
          selectedNode: widget.documentSelection.firstWhere(
            (element) => element.nodeId == docNode.id,
            orElse: () => null,
          ),
        ),
      );
    }

    _nodeIdsToComponentKeys
      ..clear()
      ..addAll(newComponentKeys);

    return docComponents;
  }

  Widget _buildDocumentComponent({
    GlobalKey key,
    @required DocumentNode docNode,
    DocumentNodeSelection selectedNode,
  }) {
    // print(' - building document component with key: $key');
    if (docNode is ParagraphNode) {
      final textSelection = selectedNode == null ? null : selectedNode.nodeSelection as TextSelection;
      final hasCursor = selectedNode != null ? selectedNode.isExtent : false;
      final highlightWhenEmpty = selectedNode == null ? false : selectedNode.highlightWhenEmpty;

      // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
      // if (hasCursor) {
      //   print('   - ^ has cursor');
      // }

      const textStyle = TextStyle(
        color: Color(0xFF312F2C),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        height: 1.4,
      );

      return SelectableText(
        key: key,
        text: docNode.paragraph,
        textSelection: textSelection,
        hasCursor: hasCursor,
        style: textStyle,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: widget.showDebugPaint,
      );
    } else {
      print('Unknown document node: $docNode');
      return SizedBox();
    }
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
