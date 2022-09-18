import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Inspects a given [SuperEditor] in the widget tree.
class SuperEditorInspector {
  /// Returns `true` if the given [SuperEditor] widget currently has focus, or
  /// `false` otherwise.
  ///
  /// {@template supereditor_finder}
  /// By default, this method expects a single [SuperEditor] in the widget tree and
  /// finds it `byType`. To specify one [SuperEditor] among many, pass a [superEditorFinder].
  /// {@endtemplate}
  static bool hasFocus([Finder? finder]) {
    final element = (finder ?? find.byType(SuperEditor)).evaluate().single as StatefulElement;
    final superEditor = element.state as SuperEditorState;
    return superEditor.focusNode.hasFocus;
  }

  /// Returns the [Document] within the [SuperEditor] matched by [finder],
  /// or the singular [SuperEditor] in the widget tree, if [finder] is `null`.
  ///
  /// {@macro supereditor_finder}
  static Document? findDocument([Finder? finder]) {
    final element = (finder ?? find.byType(SuperEditor)).evaluate().single as StatefulElement;
    final superEditor = element.state as SuperEditorState;
    return superEditor.editContext.editor.document;
  }

  /// Returns the current [DocumentSelection] for the [SuperEditor] matched by
  /// [finder], or the singular [SuperEditor] in the widget tree, if [finder]
  /// is `null`.
  ///
  /// {@macro supereditor_finder}
  static DocumentSelection? findDocumentSelection([Finder? finder]) {
    final element = (finder ?? find.byType(SuperEditor)).evaluate().single as StatefulElement;
    final superEditor = element.state as SuperEditorState;
    return superEditor.editContext.composer.selection;
  }

  /// Returns the (x,y) offset for the caret that's currently visible in the document.
  static Offset findCaretOffsetInDocument([Finder? finder]) {
    final caretBox = find.byKey(primaryCaretKey).evaluate().single.renderObject as RenderBox;
    final globalCaretOffset = caretBox.localToGlobal(Offset.zero);
    final documentLayout = _findDocumentLayout(finder);
    final globalToDocumentOffset = documentLayout.getGlobalOffsetFromDocumentOffset(Offset.zero);
    return globalCaretOffset - globalToDocumentOffset;
  }

  /// Returns the (x,y) offset for the component which renders the node with the given [nodeId].
  ///
  /// {@macro supereditor_finder}
  static Offset findComponentOffset(String nodeId, Alignment alignment, [Finder? finder]) {
    final documentLayout = _findDocumentLayout(finder);
    final component = documentLayout.getComponentByNodeId(nodeId);
    assert(component != null);
    final componentBox = component!.context.findRenderObject() as RenderBox;
    final rect = componentBox.localToGlobal(Offset.zero) & componentBox.size;
    return alignment.withinRect(rect);
  }

  /// Returns the (x,y) offset for a caret, if that caret appeared at the given [position].
  ///
  /// {@macro supereditor_finder}
  static Offset calculateOffsetForCaret(DocumentPosition position, [Finder? finder]) {
    final documentLayout = _findDocumentLayout(finder);
    final positionRect = documentLayout.getRectForPosition(position);
    assert(positionRect != null);
    return positionRect!.topLeft;
  }

  /// Returns `true` if the entire content rectangle at [position] is visible on
  /// screen, or `false` otherwise.
  ///
  /// {@macro supereditor_finder}
  static bool isPositionVisibleGlobally(DocumentPosition position, Size globalSize, [Finder? finder]) {
    final documentLayout = _findDocumentLayout(finder);
    final positionRect = documentLayout.getRectForPosition(position)!;
    final globalDocumentOffset = documentLayout.getGlobalOffsetFromDocumentOffset(Offset.zero);
    final globalPositionRect = positionRect.translate(globalDocumentOffset.dx, globalDocumentOffset.dy);

    return globalPositionRect.top >= 0 &&
        globalPositionRect.left >= 0 &&
        globalPositionRect.bottom <= globalSize.height &&
        globalPositionRect.right <= globalSize.width;
  }

  /// Finds and returns the [Widget] that configures the [DocumentComponent] with the
  /// given [nodeId].
  ///
  /// The given [nodeId] must exist in the [SuperEditor]'s document. The [Widget] that
  /// configures the give node must be of type [WidgetType].
  ///
  /// {@macro supereditor_finder}
  static WidgetType findWidgetForComponent<WidgetType>(String nodeId, [Finder? superEditorFinder]) {
    final documentLayout = _findDocumentLayout(superEditorFinder);
    final widget = (documentLayout.getComponentByNodeId(nodeId) as TextComponentState).widget;
    if (widget is! WidgetType) {
      throw Exception("Looking for a component's widget. Expected type $WidgetType, but found ${widget.runtimeType}");
    }

    return widget as WidgetType;
  }

  /// Returns the [AttributedText] within the [ParagraphNode] associated with the
  /// given [nodeId].
  ///
  /// There must be a [ParagraphNode] with the given [nodeId], displayed in a
  /// [SuperEditor].
  ///
  /// {@macro supereditor_finder}
  static AttributedText findTextInParagraph(String nodeId, [Finder? superEditorFinder]) {
    final documentLayout = _findDocumentLayout(superEditorFinder);
    return (documentLayout.getComponentByNodeId(nodeId) as TextComponentState).widget.text;
  }

  /// Finds and returns the [TextStyle] that's applied to the top-level of the [TextSpan]
  /// in the paragraph with the given [nodeId].
  ///
  /// {@macro supereditor_finder}
  static TextStyle? findParagraphStyle(String nodeId, [Finder? superEditorFinder]) {
    final documentLayout = _findDocumentLayout(superEditorFinder);

    final textComponentState = documentLayout.getComponentByNodeId(nodeId) as TextComponentState;
    final superTextWithSelection = find
        .descendant(of: find.byWidget(textComponentState.widget), matching: find.byType(SuperTextWithSelection))
        .evaluate()
        .single
        .widget as SuperTextWithSelection;
    return superTextWithSelection.richText.style;
  }

  /// Returns the [DocumentNode] at given the [index].
  /// 
  /// The given [index] must be a valid node index inside the [Document].The node at [index] 
  /// must be of type [NodeType].
  /// 
  /// {@macro supereditor_finder}
  static NodeType getNodeAt<NodeType extends DocumentNode>(int index, [Finder? superEditorFinder]) {
    final doc = findDocument(superEditorFinder); 
       
    if (doc == null) {
      throw Exception('SuperEditor not found');
    }

    if (index >= doc.nodes.length) {
      throw Exception('Tried to access index $index in a document where the max index is ${doc.nodes.length - 1}');
    }

    final node = doc.nodes[index];
    if (node is! NodeType) {
      throw Exception('Tried to access a ${node.runtimeType} as $NodeType');
    }

    return node;
  }

  /// Finds the [DocumentLayout] that backs a [SuperEditor] in the widget tree.
  ///
  /// {@macro supereditor_finder}
  static DocumentLayout _findDocumentLayout([Finder? superEditorFinder]) {
    late final Finder layoutFinder;
    if (superEditorFinder != null) {
      layoutFinder = find.descendant(of: superEditorFinder, matching: find.byType(SingleColumnDocumentLayout));
    } else {
      layoutFinder = find.byType(SingleColumnDocumentLayout);
    }
    final documentLayoutElement = layoutFinder.evaluate().single as StatefulElement;
    return documentLayoutElement.state as DocumentLayout;
  }

  SuperEditorInspector._();
}
