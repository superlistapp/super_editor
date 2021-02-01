import 'package:example/spikes/editor_input_delegation/document/document_nodes.dart';
import 'package:example/spikes/editor_input_delegation/ui_components/list_items.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';

import '../document/rich_text_document.dart';
import '../selection/editor_selection.dart';
import '../selectable_text/selectable_text.dart';

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
    this.componentDecorator,
    this.showDebugPaint = false,
  }) : super(key: key);

  final RichTextDocument document;
  final List<DocumentNodeSelection> documentSelection;
  final ComponentBuilder componentBuilder;
  final ComponentDecorator componentDecorator;
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
      final textLayout = componentKey.currentState as TextLayout;
      final textBox = componentKey.currentContext.findRenderObject() as RenderBox;
      print(' - found tapped node: $textLayout');
      final componentOffset = _componentOffset(textBox, rawDocumentOffset);
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

      final decoratedComponent = widget.componentDecorator != null
          ? widget.componentDecorator.call(
              context: context,
              document: widget.document,
              currentNode: docNode,
              currentSelection: widget.documentSelection,
              child: component,
            )
          : component;

      docComponents.add(decoratedComponent);
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

final ComponentBuilder defaultComponentBuilder = ({
  @required BuildContext context,
  @required RichTextDocument document,
  @required DocumentNode currentNode,
  @required List<DocumentNodeSelection> currentSelection,
  // TODO: get rid of selectedNode param
  @required DocumentNodeSelection selectedNode,
  @required GlobalKey key,
  bool showDebugPaint = false,
}) {
  if (currentNode is TextNode) {
    final textSelection = selectedNode == null ? null : selectedNode.nodeSelection as TextSelection;
    final hasCursor = selectedNode != null ? selectedNode.isExtent : false;
    final highlightWhenEmpty = selectedNode == null ? false : selectedNode.highlightWhenEmpty;

    // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
    // if (hasCursor) {
    //   print('   - ^ has cursor');
    // }

    final selectableText = SelectableText(
      key: key,
      text: currentNode.text,
      textSelection: textSelection,
      hasCursor: hasCursor,
      // TODO: figure out how to configure styles
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: const Color(0xFF312F2C),
      ),
      highlightWhenEmpty: highlightWhenEmpty,
      showDebugPaint: showDebugPaint,
    );

    if (document.getNodeIndex(currentNode) == 0 && currentNode.text.isEmpty && !hasCursor) {
      return MouseRegion(
        cursor: SystemMouseCursors.text,
        child: Stack(
          children: [
            Text(
              'Enter your title',
              style: Theme.of(context).textTheme.bodyText1.copyWith(
                    color: const Color(0xFFC3C1C1),
                  ),
            ),
            Positioned.fill(child: selectableText),
          ],
        ),
      );
    } else if (document.getNodeIndex(currentNode) == 1 && currentNode.text.isEmpty && !hasCursor) {
      return MouseRegion(
        cursor: SystemMouseCursors.text,
        child: Stack(
          children: [
            Text(
              'Enter your content...',
              style: Theme.of(context).textTheme.bodyText1.copyWith(
                    color: const Color(0xFFC3C1C1),
                  ),
            ),
            Positioned.fill(child: selectableText),
          ],
        ),
      );
    } else {
      return selectableText;
    }
  } else if (currentNode is ImageNode) {
    return Center(
      child: Image.network(
        currentNode.imageUrl,
        key: key,
        fit: BoxFit.contain,
      ),
    );
  } else if (currentNode is UnorderedListItemNode) {
    return UnorderedListItemComponent(
      key: key,
      text: currentNode.text,
      indent: currentNode.indent,
      showDebugPaint: showDebugPaint,
    );
  } else if (currentNode is OrderedListItemNode) {
    int index = 1;
    DocumentNode nodeAbove = document.getNodeBefore(currentNode);
    while (nodeAbove != null && nodeAbove is OrderedListItemNode && nodeAbove.indent >= currentNode.indent) {
      if ((nodeAbove as OrderedListItemNode).indent == currentNode.indent) {
        index += 1;
      }
      nodeAbove = document.getNodeBefore(nodeAbove);
    }

    return OrderedListItemComponent(
      key: key,
      listIndex: index,
      text: currentNode.text,
      indent: currentNode.indent,
      showDebugPaint: showDebugPaint,
    );
  } else {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: Placeholder(),
    );
  }
};

typedef ComponentDecorator = Widget Function({
  @required BuildContext context,
  @required RichTextDocument document,
  @required DocumentNode currentNode,
  @required List<DocumentNodeSelection> currentSelection,
  @required Widget child,
});
