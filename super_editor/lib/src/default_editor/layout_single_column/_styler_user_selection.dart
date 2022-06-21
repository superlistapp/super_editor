import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../../core/document.dart';
import '_presenter.dart';

/// [SingleColumnLayoutStylePhase] that applies visual selections to each component,
/// e.g., text selections, image selections, caret positioning.
class SingleColumnLayoutSelectionStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutSelectionStyler({
    required Document document,
    required DocumentComposer composer,
    required SelectionStyles primaryUserSelectionStyles,
    NonPrimarySelectionStyler? nonPrimarySelectionStyler,
  })  : _document = document,
        _composer = composer,
        _selectionStyles = primaryUserSelectionStyles,
        _nonPrimarySelectionStyler = nonPrimarySelectionStyler {
    // Our styles need to be re-applied whenever the document selection changes.
    _composer.selectionNotifier.addListener(markDirty);
    _composer.addNonPrimarySelectionListener(NonPrimarySelectionListener(
      onSelectionAdded: (_) => markDirty(),
      onSelectionChanged: (_) => markDirty(),
      onSelectionRemoved: (_) => markDirty(),
    ));
  }

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(markDirty);
    super.dispose();
  }

  final Document _document;
  final DocumentComposer _composer;
  final SelectionStyles _selectionStyles;
  final NonPrimarySelectionStyler? _nonPrimarySelectionStyler;

  bool _shouldDocumentShowCaret = false;
  set shouldDocumentShowCaret(bool newValue) {
    if (newValue == _shouldDocumentShowCaret) {
      return;
    }

    _shouldDocumentShowCaret = newValue;
    editorLayoutLog.fine(
        "Change to 'document should show caret': $_shouldDocumentShowCaret");
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel style(
      Document document, SingleColumnLayoutViewModel viewModel) {
    editorLayoutLog
        .info("(Re)calculating selection view model for document layout");
    editorLayoutLog
        .fine("Applying selection to components: ${_composer.selection}");
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applySelection(previousViewModel.copy()),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applySelection(
      SingleColumnLayoutComponentViewModel viewModel) {
    final documentSelection = _composer.selection;
    final node = _document.getNodeById(viewModel.nodeId)!;

    DocumentNodeSelection? nodeSelection;
    if (documentSelection != null) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          documentSelection.base,
          documentSelection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }
      nodeSelection = _computeNodeSelection(
          documentSelection: documentSelection,
          selectedNodes: selectedNodes,
          node: node);
    }

    editorLayoutLog.fine("Node selection (${node.id}): $nodeSelection");
    if (node is TextNode) {
      final styledSelections = _computeStyledSelectionsForText(
        composer: _composer,
        node: node,
      );

      final textSelection =
          nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
              ? null
              : nodeSelection.nodeSelection as TextSelection;
      if (nodeSelection != null &&
          nodeSelection.nodeSelection is! TextSelection) {
        editorLayoutLog.shout(
            'ERROR: Building a paragraph component but the selection is not a TextSelection. Node: ${node.id}, Selection: ${nodeSelection.nodeSelection}');
      }
      final showCaret = _shouldDocumentShowCaret && nodeSelection != null
          ? nodeSelection.isExtent
          : false;
      // final highlightWhenEmpty =
      //     nodeSelection == null ? false : nodeSelection.highlightWhenEmpty && _selectionStyles.highlightEmptyTextBlocks;

      editorLayoutLog.finer(' - ${node.id}: $nodeSelection');
      if (showCaret) {
        editorLayoutLog.finer('   - ^ showing caret');
      }

      editorLayoutLog.finer(' - building a paragraph with selection:');
      editorLayoutLog.finer('   - base: ${textSelection?.base}');
      editorLayoutLog.finer('   - extent: ${textSelection?.extent}');

      if (viewModel is TextComponentViewModel) {
        viewModel
          ..styledSelections = styledSelections
          ..caret = showCaret ? textSelection?.extent : null
          ..caretColor = _selectionStyles.caretColor;
      }
    }
    if (viewModel is ImageComponentViewModel) {
      final styledSelections =
          _computeStyledSelectionsForUpstreamDownstreamNodes(
              composer: _composer, node: node);

      viewModel
        ..styledSelections = styledSelections
        ..caret = _shouldDocumentShowCaret &&
                styledSelections.isNotEmpty &&
                styledSelections.last.selection.isCollapsed
            ? styledSelections.last.selection.extent
            : null
        ..caretColor = _selectionStyles.caretColor;
    }
    if (viewModel is HorizontalRuleComponentViewModel) {
      final styledSelections =
          _computeStyledSelectionsForUpstreamDownstreamNodes(
              composer: _composer, node: node);

      viewModel
        ..styledSelections = styledSelections
        ..caret = _shouldDocumentShowCaret &&
                styledSelections.isNotEmpty &&
                styledSelections.last.selection.isCollapsed
            ? styledSelections.last.selection.extent
            : null
        ..caretColor = _selectionStyles.caretColor;
    }

    return viewModel;
  }

  List<StyledSelection<TextSelection>> _computeStyledSelectionsForText({
    required DocumentComposer composer,
    required DocumentNode node,
  }) {
    final styledSelections = <StyledSelection<TextSelection>>[];

    for (final nonPrimarySelection in _composer.getAllNonPrimarySelections()) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          nonPrimarySelection.selection.base,
          nonPrimarySelection.selection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection = _computeNodeSelection(
        documentSelection: nonPrimarySelection.selection,
        selectedNodes: selectedNodes,
        node: node,
      );

      if (nodeSelection?.nodeSelection is TextNodeSelection) {
        final textNodeSelection =
            nodeSelection!.nodeSelection as TextNodeSelection;
        final textSelection = TextSelection(
            baseOffset: textNodeSelection.baseOffset,
            extentOffset: textNodeSelection.extentOffset);

        styledSelections.add(StyledSelection(
          textSelection,
          // TODO: the styler decides whether to highlight an empty block, but it shouldn't.
          // That decision needs to be made based on whether the user is selecting multiple
          // blocks.
          _nonPrimarySelectionStyler!(nonPrimarySelection)!,
        ));
      }
    }

    final documentSelection = _composer.selection;
    if (documentSelection != null) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          documentSelection.base,
          documentSelection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection = _computeNodeSelection(
          documentSelection: documentSelection,
          selectedNodes: selectedNodes,
          node: node);

      if (nodeSelection?.nodeSelection is TextNodeSelection) {
        final textNodeSelection =
            nodeSelection!.nodeSelection as TextNodeSelection;
        final textSelection = TextSelection(
            baseOffset: textNodeSelection.baseOffset,
            extentOffset: textNodeSelection.extentOffset);

        styledSelections.add(StyledSelection(
          textSelection,
          SelectionStyles(
            selectionColor: _selectionStyles.selectionColor,
            highlightEmptyTextBlocks: nodeSelection.highlightWhenEmpty,
            caretColor: _selectionStyles.caretColor,
          ),
        ));
      }
    }

    return styledSelections;
  }

  List<StyledSelection<UpstreamDownstreamNodeSelection>>
      _computeStyledSelectionsForUpstreamDownstreamNodes({
    required DocumentComposer composer,
    required DocumentNode node,
  }) {
    final styledSelections =
        <StyledSelection<UpstreamDownstreamNodeSelection>>[];

    for (final nonPrimarySelection in _composer.getAllNonPrimarySelections()) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          nonPrimarySelection.selection.base,
          nonPrimarySelection.selection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection = _computeNodeSelection(
        documentSelection: nonPrimarySelection.selection,
        selectedNodes: selectedNodes,
        node: node,
      );

      if (nodeSelection?.nodeSelection is UpstreamDownstreamNodeSelection) {
        final upstreamDownstreamSelection =
            nodeSelection!.nodeSelection as UpstreamDownstreamNodeSelection;

        styledSelections.add(StyledSelection(
          upstreamDownstreamSelection,
          // TODO: the styler decides whether to highlight an empty block, but it shouldn't.
          // That decision needs to be made based on whether the user is selecting multiple
          // blocks.
          _nonPrimarySelectionStyler!(nonPrimarySelection)!,
        ));
      }
    }

    final documentSelection = _composer.selection;
    if (documentSelection != null) {
      late List<DocumentNode> selectedNodes;
      try {
        selectedNodes = _document.getNodesInside(
          documentSelection.base,
          documentSelection.extent,
        );
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        selectedNodes = [];
      }

      final nodeSelection = _computeNodeSelection(
          documentSelection: documentSelection,
          selectedNodes: selectedNodes,
          node: node);

      if (nodeSelection?.nodeSelection is UpstreamDownstreamNodeSelection) {
        final upstreamDownstreamSelection =
            nodeSelection!.nodeSelection as UpstreamDownstreamNodeSelection;

        styledSelections.add(StyledSelection(
          upstreamDownstreamSelection,
          SelectionStyles(
            selectionColor: _selectionStyles.selectionColor,
            highlightEmptyTextBlocks: nodeSelection.highlightWhenEmpty,
            caretColor: _selectionStyles.caretColor,
          ),
        ));
      }
    }

    return styledSelections;
  }

  /// Computes the [DocumentNodeSelection] for the individual `nodeId` based on
  /// the total list of selected nodes.
  DocumentNodeSelection? _computeNodeSelection({
    required DocumentSelection? documentSelection,
    required List<DocumentNode> selectedNodes,
    required DocumentNode node,
  }) {
    if (documentSelection == null) {
      return null;
    }

    editorLayoutLog.finer('_computeNodeSelection(): ${node.id}');
    editorLayoutLog.finer(' - base: ${documentSelection.base.nodeId}');
    editorLayoutLog.finer(' - extent: ${documentSelection.extent.nodeId}');

    if (documentSelection.base.nodeId == documentSelection.extent.nodeId) {
      editorLayoutLog.finer(' - selection is within 1 node.');
      if (documentSelection.base.nodeId != node.id) {
        // Only 1 node is selected and its not the node we're interested in. Return.
        editorLayoutLog.finer(' - this node is not selected. Returning null.');
        return null;
      }

      editorLayoutLog.finer(' - this node has the selection');
      final baseNodePosition = documentSelection.base.nodePosition;
      final extentNodePosition = documentSelection.extent.nodePosition;
      late NodeSelection? nodeSelection;
      try {
        nodeSelection = node.computeSelection(
            base: baseNodePosition, extent: extentNodePosition);
      } catch (exception) {
        // This situation can happen in the moment between a document change and
        // a corresponding selection change. For example: deleting an image and
        // replacing it with an empty paragraph. Between the doc change and the
        // selection change, the old image selection is applied to the new paragraph.
        // This results in an exception.
        //
        // TODO: introduce a unified event ledger that combines related behaviors
        //       into atomic transactions (#423)
        return null;
      }
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

      if (selectedNodes
              .firstWhereOrNull((selectedNode) => selectedNode.id == node.id) ==
          null) {
        // The document selection does not contain the node we're interested in. Return.
        editorLayoutLog.finer(' - this node is not in the selection');
        return null;
      }

      if (selectedNodes.first.id == node.id) {
        editorLayoutLog.finer(' - this is the first node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the top node in that selection. Therefore, this node is
        // selected from a position down to its bottom.
        final isBase = node.id == documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base:
                isBase ? documentSelection.base.nodePosition : node.endPosition,
            extent: isBase
                ? node.endPosition
                : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
          highlightWhenEmpty: isBase,
        );
      } else if (selectedNodes.last.id == node.id) {
        editorLayoutLog.finer(' - this is the last node in the selection');
        // Multiple nodes are selected and the node that we're interested in
        // is the bottom node in that selection. Therefore, this node is
        // selected from the beginning down to some position.
        final isBase = node.id == documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? node.beginningPosition : node.beginningPosition,
            extent: isBase
                ? documentSelection.base.nodePosition
                : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
          highlightWhenEmpty: isBase,
        );
      } else {
        editorLayoutLog
            .finer(' - this node is fully selected within the selection');
        // Multiple nodes are selected and this node is neither the top
        // or the bottom node, therefore this entire node is selected.
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: node.beginningPosition,
            extent: node.endPosition,
          ),
          highlightWhenEmpty: true,
        );
      }
    }
  }
}

/// Function called to configure [SelectionStyles] for a given [nonPrimarySelection].
///
/// If you don't want to display anything for this selection, return `null`.
typedef NonPrimarySelectionStyler = SelectionStyles? Function(
    NonPrimarySelection nonPrimarySelection);
