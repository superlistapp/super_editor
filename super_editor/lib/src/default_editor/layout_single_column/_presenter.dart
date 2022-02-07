import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import '../attributions.dart';
import '_blockquote.dart';
import '_horizontal_rule.dart';
import '_image.dart';
import '_list_items.dart';
import '_paragraph.dart';

/// Builds a widget that renders the desired UI for one or
/// more [DocumentNode]s.
///
/// Every widget returned from a [SingleColumnDocumentComponentBuilder]
/// should be a [StatefulWidget] that mixes in [DocumentComponent].
///
/// A [SingleColumnDocumentComponentBuilder] might be invoked with a
/// type of [ComponentViewModel] that it doesn't know how to work with.
/// When this happens, the [SingleColumnDocumentComponentBuilder] should
/// return `null`, indicating that it doesn't know how to build a component
/// for the given [ComponentViewModel].
typedef SingleColumnDocumentComponentBuilder = Widget? Function(
  SingleColumnDocumentComponentContext,
  ComponentViewModel,
);

/// Information that is provided to a [ComponentBuilder] to
/// construct an appropriate [DocumentComponent] widget.
class SingleColumnDocumentComponentContext {
  /// Creates a component context.
  const SingleColumnDocumentComponentContext({
    required this.context,
    required this.document,
    required this.componentKey,
  });

  /// The [BuildContext] for the parent of the [DocumentComponent]
  /// that needs to be built.
  final BuildContext context;

  /// The [Document] that contains the [DocumentNode].
  final Document document;

  /// A [GlobalKey] that must be assigned to the [DocumentComponent]
  /// widget returned by a [ComponentBuilder].
  ///
  /// The [componentKey] is used by the [DocumentLayout] to query for
  /// node-specific information, like node positions and selections.
  final GlobalKey componentKey;
}

class SingleColumnMetadataFactory implements ComponentViewModelFactory {
  @override
  ComponentViewModel createComponentViewModel(Document document, DocumentNode node) {
    if (node is ParagraphNode) {
      final textDirection = getParagraphDirection(node.text.text);

      TextAlign textAlign = (textDirection == TextDirection.ltr) ? TextAlign.left : TextAlign.right;
      final textAlignName = node.metadata['textAlign'];
      switch (textAlignName) {
        case 'left':
          textAlign = TextAlign.left;
          break;
        case 'center':
          textAlign = TextAlign.center;
          break;
        case 'right':
          textAlign = TextAlign.right;
          break;
        case 'justify':
          textAlign = TextAlign.justify;
          break;
      }

      final isBlockquote = node.metadata['blockType'] == blockquoteAttribution;
      if (isBlockquote) {
        return BlockquoteComponentMetadata(
          nodeId: node.id,
          text: node.text,
          textStyleBuilder: _noStyleBuilder,
          textDirection: textDirection,
          textAlignment: textAlign,
          selectionColor: const Color(0x00000000),
          caretColor: const Color(0x00000000),
        );
      }

      return ParagraphComponentMetadata(
        nodeId: node.id,
        blockType: node.metadata['blockType'],
        text: node.text,
        textStyleBuilder: _noStyleBuilder,
        textDirection: textDirection,
        textAlignment: textAlign,
        selectionColor: const Color(0x00000000),
        caretColor: const Color(0x00000000),
      );
    }
    if (node is ListItemNode) {
      int? ordinalValue;
      if (node.type == ListItemType.ordered) {
        ordinalValue = 1;
        DocumentNode? nodeAbove = document.getNodeBefore(node);
        while (nodeAbove != null &&
            nodeAbove is ListItemNode &&
            nodeAbove.type == ListItemType.ordered &&
            nodeAbove.indent >= node.indent) {
          if (nodeAbove.indent == node.indent) {
            ordinalValue = ordinalValue! + 1;
          }
          nodeAbove = document.getNodeBefore(nodeAbove);
        }
      }

      return ListItemComponentMetadata(
        nodeId: node.id,
        type: node.type,
        indent: node.indent,
        ordinalValue: ordinalValue,
        text: node.text,
        textStyleBuilder: _noStyleBuilder,
        selectionColor: const Color(0x00000000),
        caretColor: const Color(0x00000000),
      );
    }
    if (node is ImageNode) {
      return ImageComponentMetadata(
        nodeId: node.id,
        imageUrl: node.imageUrl,
        selectionColor: const Color(0x00000000),
        caretColor: const Color(0x00000000),
      );
    }
    if (node is HorizontalRuleNode) {
      return HorizontalRuleComponentMetadata(
        nodeId: node.id,
        selectionColor: const Color(0x00000000),
        caretColor: const Color(0x00000000),
      );
    }

    throw Exception("Super Editor doesn't know how to style node: ${node.runtimeType}");
  }
}

TextStyle _noStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle();
}

class SingleColumnComponentConfiguration implements ComponentStyler {
  SingleColumnComponentConfiguration({
    required this.documentSelection,
    required this.textStyleBuilder,
    required this.selectionColor,
    required this.caretColor,
    this.shouldDocumentShowCaret = false,
  });

  final DocumentSelection? documentSelection;
  final AttributionStyleBuilder textStyleBuilder;
  final Color selectionColor;
  final Color caretColor;

  bool shouldDocumentShowCaret;

  @override
  ComponentViewModel styleComponentViewModel(
    Document document,
    DocumentNode node,
    ComponentViewModel componentMetadata,
  ) {
    final selectedNodes = documentSelection != null
        ? document.getNodesInside(
            documentSelection!.base,
            documentSelection!.extent,
          )
        : const <DocumentNode>[];
    final nodeSelection = _computeNodeSelection(selectedNodes: selectedNodes, node: node);

    if (node is TextNode) {
      final textSelection = nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
          ? null
          : nodeSelection.nodeSelection as TextSelection;
      if (nodeSelection != null && nodeSelection.nodeSelection is! TextSelection) {
        editorLayoutLog.shout(
            'ERROR: Building a paragraph component but the selection is not a TextSelection. Node: ${node.id}, Selection: ${nodeSelection.nodeSelection}');
      }
      final showCaret = shouldDocumentShowCaret && nodeSelection != null ? nodeSelection.isExtent : false;
      final highlightWhenEmpty = nodeSelection == null ? false : nodeSelection.highlightWhenEmpty;

      editorLayoutLog.finer(' - ${node.id}: $nodeSelection');
      if (showCaret) {
        editorLayoutLog.finer('   - ^ showing caret');
      }

      editorLayoutLog.finer(' - building a paragraph with selection:');
      editorLayoutLog.finer('   - base: ${textSelection?.base}');
      editorLayoutLog.finer('   - extent: ${textSelection?.extent}');

      if (componentMetadata is ParagraphComponentMetadata) {
        return componentMetadata.copyWith(
          textStyleBuilder: textStyleBuilder,
          selection: textSelection,
          selectionColor: selectionColor,
          caret: showCaret ? textSelection?.extent : null,
          caretColor: caretColor,
          highlightWhenEmpty: highlightWhenEmpty,
        );
      }
      if (componentMetadata is BlockquoteComponentMetadata) {
        return componentMetadata.copyWith(
          textStyleBuilder: textStyleBuilder,
          selection: textSelection,
          selectionColor: selectionColor,
          caret: showCaret ? textSelection?.extent : null,
          caretColor: caretColor,
          highlightWhenEmpty: highlightWhenEmpty,
        );
      }
      if (componentMetadata is ListItemComponentMetadata) {
        return componentMetadata.copyWith(
          textStyleBuilder: textStyleBuilder,
          selection: textSelection,
          selectionColor: selectionColor,
          caret: showCaret ? textSelection?.extent : null,
          caretColor: caretColor,
        );
      }
    }
    if (componentMetadata is ImageComponentMetadata) {
      final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as UpstreamDownstreamNodeSelection;

      return componentMetadata.copyWith(
        maxWidth: document.nodes.first == node ? double.infinity : null,
        selection: selection,
        selectionColor: selectionColor,
        caret: shouldDocumentShowCaret ? selection?.extent : null,
        caretColor: caretColor,
      );
    }
    if (componentMetadata is HorizontalRuleComponentMetadata) {
      final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as UpstreamDownstreamNodeSelection;

      return componentMetadata.copyWith(
        selection: selection,
        selectionColor: selectionColor,
        caret: shouldDocumentShowCaret ? selection?.extent : null,
        caretColor: caretColor,
      );
    }

    // We don't know what kind of component this is. Return it, unmodified.
    return componentMetadata;
  }

  /// Computes the `DocumentNodeSelection` for the individual `nodeId` based on
  /// the total list of selected nodes.
  DocumentNodeSelection? _computeNodeSelection({
    required List<DocumentNode> selectedNodes,
    required DocumentNode node,
  }) {
    if (documentSelection == null) {
      return null;
    }

    editorLayoutLog.finer('_computeNodeSelection(): ${node.id}');
    editorLayoutLog.finer(' - base: ${documentSelection!.base.nodeId}');
    editorLayoutLog.finer(' - extent: ${documentSelection!.extent.nodeId}');

    if (documentSelection!.base.nodeId == documentSelection!.extent.nodeId) {
      editorLayoutLog.finer(' - selection is within 1 node.');
      if (documentSelection!.base.nodeId != node.id) {
        // Only 1 node is selected and its not the node we're interested in. Return.
        editorLayoutLog.finer(' - this node is not selected. Returning null.');
        return null;
      }

      editorLayoutLog.finer(' - this node has the selection');
      final baseNodePosition = documentSelection!.base.nodePosition;
      final extentNodePosition = documentSelection!.extent.nodePosition;
      final nodeSelection = node.computeSelection(base: baseNodePosition, extent: extentNodePosition);
      editorLayoutLog.finer(' - node selection: $nodeSelection');

      return DocumentNodeSelection(
        nodeId: node.id,
        nodeSelection: nodeSelection,
        isBase: true,
        isExtent: true,
      );
    } else {
      // Log all the selected nodes.
      editorLayoutLog.finer(' - selection contains multiple nodes:');
      for (final node in selectedNodes) {
        editorLayoutLog.finer('   - ${node.id}');
      }

      if (selectedNodes.firstWhereOrNull((selectedNode) => selectedNode.id == node.id) == null) {
        // The document selection does not contain the node we're interested in. Return.
        editorLayoutLog.finer(' - this node is not in the selection');
        return null;
      }

      if (selectedNodes.first.id == node.id) {
        editorLayoutLog.finer(' - this is the first node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the top node in that selection. Therefore, this node is
        // selected from a position down to its bottom.
        final isBase = node.id == documentSelection!.base.nodeId;
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? documentSelection!.base.nodePosition : node.endPosition,
            extent: isBase ? node.endPosition : documentSelection!.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
        );
      } else if (selectedNodes.last.id == node.id) {
        editorLayoutLog.finer(' - this is the last node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the bottom node in that selection. Therefore, this node is
        // selected from the beginning down to some position.
        final isBase = node.id == documentSelection!.base.nodeId;
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? node.beginningPosition : node.beginningPosition,
            extent: isBase ? documentSelection!.base.nodePosition : documentSelection!.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
        );
      } else {
        editorLayoutLog.finer(' - this node is fully selected within the selection');
        // Multiple nodes are selected and this node is neither the top
        // or the bottom node, therefore this entire node is selected.
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: node.beginningPosition,
            extent: node.endPosition,
          ),
        );
      }
    }
  }
}

/// View model for an entire [SingleColumnDocumentLayout].
class SingleColumnDocumentLayoutViewModel {
  const SingleColumnDocumentLayoutViewModel({
    required List<SingleColumnDocumentLayoutComponentViewModel> componentViewModels,
  }) : _componentViewModels = componentViewModels;

  final List<SingleColumnDocumentLayoutComponentViewModel> _componentViewModels;
  List<SingleColumnDocumentLayoutComponentViewModel> get componentViewModels => _componentViewModels;
}

/// Base class for a [ComponentViewModel] that appears within a
/// [SingleColumnDocumentLayout].
abstract class SingleColumnDocumentLayoutComponentViewModel implements ComponentViewModel {
  const SingleColumnDocumentLayoutComponentViewModel({
    this.maxWidth,
  });

  /// The maximum width of this component in the layout, or `null` to
  /// defer to the layout's preference.
  final double? maxWidth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleColumnDocumentLayoutComponentViewModel &&
          runtimeType == other.runtimeType &&
          maxWidth == other.maxWidth;

  @override
  int get hashCode => maxWidth.hashCode;
}
