import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styles.dart';
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
  SingleColumnLayoutComponentViewModel,
);

/// Information that is provided to a [ComponentBuilder] to
/// construct an appropriate [DocumentComponent] widget.
class SingleColumnDocumentComponentContext {
  /// Creates a component context.
  const SingleColumnDocumentComponentContext({
    required this.context,
    required this.componentKey,
  });

  /// The [BuildContext] for the parent of the [DocumentComponent]
  /// that needs to be built.
  final BuildContext context;

  /// A [GlobalKey] that must be assigned to the [DocumentComponent]
  /// widget returned by a [ComponentBuilder].
  ///
  /// The [componentKey] is used by the [DocumentLayout] to query for
  /// node-specific information, like node positions and selections.
  final GlobalKey componentKey;
}

/// Produces [SingleColumnLayoutViewModel]s to be displayed by a
/// [SingleColumnDocumentLayout].
///
/// The view model is computed by passing the given [Document] through a
/// series of "style phases", known as a [pipeline].
///
/// When the [document] changes, the entire pipeline is re-run to produce
/// a new [SingleColumnLayoutViewModel].
///
/// The output from each phase of the pipeline is cached so that when
/// something other than the document changes, like the user's selection,
/// only some of the pipeline phases are re-run. For this reason, the most
/// volatile phases should be placed at the end of the [pipeline].
class SingleColumnLayoutPresenter {
  SingleColumnLayoutPresenter({
    required Document document,
    required List<SingleColumnLayoutStylePhase> pipeline,
  })  : _document = document,
        _pipeline = pipeline {
    _assemblePipeline();
    _viewModel = _createNewViewModel();
  }

  void dispose() {
    _listeners.clear();
    _disassemblePipeline();
  }

  final Document _document;
  final List<SingleColumnLayoutStylePhase> _pipeline;
  final List<SingleColumnLayoutViewModel?> _phaseViewModels = [];
  int _earliestDirtyPhase = 0;

  bool get isDirty => _earliestDirtyPhase < _pipeline.length;

  late SingleColumnLayoutViewModel _viewModel;
  SingleColumnLayoutViewModel get viewModel => _viewModel;

  final _listeners = <SingleColumnLayoutPresenterChangeListener>{};

  void addChangeListener(SingleColumnLayoutPresenterChangeListener listener) {
    _listeners.add(listener);
  }

  void removeChangeListener(SingleColumnLayoutPresenterChangeListener listener) {
    _listeners.remove(listener);
  }

  void _assemblePipeline() {
    // Insert the phase that creates the baseline view models for every node.
    _pipeline.insert(0, SingleColumnLayoutBaselineStyler(document: _document));
    // Create an empty placeholder for cached view models for this phase.
    _phaseViewModels.add(null);

    // Add all the phases that were provided by the client.
    for (int i = 0; i < _pipeline.length; i += 1) {
      // Create an empty placeholder for cached view models for this phase.
      _phaseViewModels.add(null);

      // Listen for all dirty phase notifications.
      _pipeline[i].dirtyCallback = () {
        final phaseIndex = i;
        if (phaseIndex < 0) {
          throw Exception("A phase marked itself as dirty, but that phase isn't in the pipeline. Index: $phaseIndex");
        }

        final wasDirty = isDirty;
        if (phaseIndex < _earliestDirtyPhase) {
          _earliestDirtyPhase = phaseIndex;
        }

        editorLayoutLog.info("Presenter phase ($phaseIndex) is dirty.");

        if (!wasDirty) {
          // The presenter just went from clean to dirty. Notify listeners.
          for (final listener in _listeners) {
            listener.onPresenterMarkedDirty();
          }
        }
      };
    }
  }

  void _disassemblePipeline() {
    for (final phase in _pipeline) {
      phase.dispose();
    }
  }

  void updateViewModel() {
    editorLayoutLog.info("Calculating an updated view model for document layout.");
    if (_earliestDirtyPhase == _pipeline.length) {
      editorLayoutLog.fine("The presenter is already up to date");
      return;
    }

    editorLayoutLog.fine("Earliest dirty phase is: $_earliestDirtyPhase. Phase count: ${_pipeline.length}");

    final oldViewModel = _viewModel;
    _viewModel = _createNewViewModel();

    editorLayoutLog.info("Done calculating new document layout view model");

    _notifyListenersOfChanges(
      oldViewModel: oldViewModel,
      newViewModel: _viewModel,
    );
  }

  SingleColumnLayoutViewModel _createNewViewModel() {
    editorLayoutLog.fine("Running layout presenter pipeline");
    // (Re)generate all dirty phases.
    SingleColumnLayoutViewModel? newViewModel = _getCleanCachedViewModel();
    for (int i = _earliestDirtyPhase; i < _pipeline.length; i += 1) {
      editorLayoutLog.fine("Running phase $i: ${_pipeline[i]}");
      newViewModel = _pipeline[i].produceViewModel(newViewModel);
      editorLayoutLog.fine("Storing phase $i view model");
      _phaseViewModels[i] = newViewModel;
    }
    // No more dirty phases.
    _earliestDirtyPhase = _pipeline.length;

    return newViewModel!;
  }

  SingleColumnLayoutViewModel? _getCleanCachedViewModel() {
    return _earliestDirtyPhase > 0 && _earliestDirtyPhase < _phaseViewModels.length
        ? _phaseViewModels[_earliestDirtyPhase - 1]
        : null;
  }

  void _notifyListenersOfChanges({
    required SingleColumnLayoutViewModel oldViewModel,
    required SingleColumnLayoutViewModel newViewModel,
  }) {
    final addedComponents = <String>[];
    final removedComponents = <String>[];
    final changedComponents = <String>[];

    final nodeIdToComponentMap = <String, SingleColumnLayoutComponentViewModel>{};
    // Maps a component's node ID to a change code:
    //  -1 - the component was removed
    //   0 - the component is unchanged
    //   1 - the component changed
    //   2 - the component was added
    final changeMap = <String, int>{};
    for (final oldComponent in oldViewModel.componentViewModels) {
      final nodeId = oldComponent.nodeId;
      nodeIdToComponentMap[nodeId] = oldComponent;
      changeMap[nodeId] = -1;
    }
    for (final newComponent in newViewModel.componentViewModels) {
      final nodeId = newComponent.nodeId;
      if (nodeIdToComponentMap.containsKey(nodeId)) {
        if (nodeIdToComponentMap[nodeId] == newComponent) {
          // The component hasn't changed.
          changeMap[nodeId] = 0;
        } else if (nodeIdToComponentMap[nodeId].runtimeType == newComponent.runtimeType) {
          // The component still exists, but it changed.
          changeMap[nodeId] = 1;
        } else {
          // The component has changed type, e.g., from an Image to a
          // Paragraph. This can happen as a result of deletions. Treat
          // this as a component removal.
          changeMap[nodeId] = -1;
          editorLayoutLog.fine("Component node changed type. Assuming this is a removal: $nodeId");
        }
      } else {
        // This component is new.
        changeMap[nodeId] = 2;
      }
    }

    // Convert the change map to lists of changes.
    for (final entry in changeMap.entries) {
      switch (entry.value) {
        case -1:
          removedComponents.add(entry.key);
          break;
        case 0:
          // Component was unchanged. Do nothing.
          break;
        case 1:
          changedComponents.add(entry.key);
          break;
        case 2:
          addedComponents.add(entry.key);
          break;
        default:
          if (kDebugMode) {
            throw Exception("Unknown component change value: ${entry.value}");
          }
          break;
      }
    }

    if (addedComponents.isEmpty && changedComponents.isEmpty && removedComponents.isEmpty) {
      // No changes to report.
      return;
    }

    editorLayoutLog.fine("Notifying layout presenter listeners of changes:");
    editorLayoutLog.fine(" - added: $addedComponents");
    editorLayoutLog.fine(" - changed: $changedComponents");
    editorLayoutLog.fine(" - removed: $removedComponents");
    for (final listener in _listeners.toList()) {
      listener.onViewModelChange(
        addedComponents: addedComponents,
        changedComponents: changedComponents,
        removedComponents: removedComponents,
      );
    }
  }
}

class SingleColumnLayoutPresenterChangeListener {
  const SingleColumnLayoutPresenterChangeListener({
    VoidCallback? onPresenterMarkedDirty,
    _ViewModelChangeCallback? onViewModelChange,
  })  : _onPresenterMarkedDirty = onPresenterMarkedDirty,
        _onViewModelChange = onViewModelChange;

  final VoidCallback? _onPresenterMarkedDirty;
  final _ViewModelChangeCallback? _onViewModelChange;

  void onPresenterMarkedDirty() {
    _onPresenterMarkedDirty?.call();
  }

  void onViewModelChange({
    required List<String> addedComponents,
    required List<String> changedComponents,
    required List<String> removedComponents,
  }) {
    _onViewModelChange?.call(
      addedComponents: addedComponents,
      changedComponents: changedComponents,
      removedComponents: removedComponents,
    );
  }
}

typedef _ViewModelChangeCallback = void Function({
  required List<String> addedComponents,
  required List<String> changedComponents,
  required List<String> removedComponents,
});

/// A single phase of style rules, which are applied in a pipeline to
/// a baseline [SingleColumnLayoutViewModel].
///
/// Each such phase takes an incoming layout view model, copies it,
/// makes any desired style changes, and then returns it.
///
/// Example:
///
/// (baseline) --> (text styles) --> (selection styles) --> (layout)
abstract class SingleColumnLayoutStylePhase {
  void dispose() {
    _dirtyCallback = null;
  }

  VoidCallback? _dirtyCallback;
  set dirtyCallback(VoidCallback? newCallback) => _dirtyCallback = newCallback;

  /// Marks this phase as needing to re-run its view model calculations.
  @protected
  void markDirty() {
    editorLayoutLog.info("Marking a layout phase as dirty: $runtimeType");
    _dirtyCallback?.call();
  }

  /// Produces a [SingleColumnLayoutViewModel] with adjustments applied
  /// by this style phase.
  SingleColumnLayoutViewModel produceViewModel(SingleColumnLayoutViewModel? viewModel);
}

/// The first phase in a single-column layout presentation pipeline.
///
/// This style phase creates baseline view models for each node within
/// the given [Document].
///
/// This style phase automatically marks itself dirty whenever the given
/// [Document] reports changes.
class SingleColumnLayoutBaselineStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutBaselineStyler({
    required Document document,
  }) : _document = document {
    // The baseline needs to be recomputed whenever the document changes.
    _document.addListener(markDirty);
  }

  @override
  void dispose() {
    _document.removeListener(markDirty);
    super.dispose();
  }

  final Document _document;

  @override
  SingleColumnLayoutViewModel produceViewModel(SingleColumnLayoutViewModel? viewModel) {
    editorLayoutLog.fine("Producing view model for phase: $this");

    editorLayoutLog.info("(Re)calculating baseline view model for document layout");
    return SingleColumnLayoutViewModel(componentViewModels: [
      for (final previousViewModel in _document.nodes) //
        _createBaselineViewModel(previousViewModel),
    ]);
  }

  SingleColumnLayoutComponentViewModel _createBaselineViewModel(DocumentNode node) {
    if (node is ParagraphNode) {
      final textDirection = getParagraphDirection(node.text.text);

      TextAlign textAlign = (textDirection == TextDirection.ltr) ? TextAlign.left : TextAlign.right;
      final textAlignName = node.getMetadata('textAlign');
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

      final isBlockquote = node.getMetadata('blockType') == blockquoteAttribution;
      if (isBlockquote) {
        return BlockquoteComponentViewModel(
          nodeId: node.id,
          text: node.text,
          textStyleBuilder: _noStyleBuilder,
          backgroundColor: const Color(0x00000000),
          borderRadius: BorderRadius.zero,
          textDirection: textDirection,
          textAlignment: textAlign,
          selectionColor: const Color(0x00000000),
          caretColor: const Color(0x00000000),
        );
      }

      return ParagraphComponentViewModel(
        nodeId: node.id,
        blockType: node.getMetadata('blockType'),
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
        DocumentNode? nodeAbove = _document.getNodeBefore(node);
        while (nodeAbove != null &&
            nodeAbove is ListItemNode &&
            nodeAbove.type == ListItemType.ordered &&
            nodeAbove.indent >= node.indent) {
          if (nodeAbove.indent == node.indent) {
            ordinalValue = ordinalValue! + 1;
          }
          nodeAbove = _document.getNodeBefore(nodeAbove);
        }
      }

      return ListItemComponentViewModel(
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
      return ImageComponentViewModel(
        nodeId: node.id,
        imageUrl: node.imageUrl,
        selectionColor: const Color(0x00000000),
        caretColor: const Color(0x00000000),
      );
    }
    if (node is HorizontalRuleNode) {
      return HorizontalRuleComponentViewModel(
        nodeId: node.id,
        selectionColor: const Color(0x00000000),
        caretColor: const Color(0x00000000),
      );
    }

    throw Exception("Super Editor doesn't know how to style node: ${node.runtimeType}");
  }
}

/// [AttributionStyleBuilder] that returns a default `TextStyle`, for
/// use when creating baseline view models before the text styles are
/// configured.
TextStyle _noStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle();
}

/// [SingleColumnLayoutStylePhase] that applies layout-wide styles.
class SingleColumnLayoutStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutStyler({
    required SingleColumnLayoutStylesheet stylesheet,
  }) : _stylesheet = stylesheet;

  SingleColumnLayoutStylesheet _stylesheet;
  set stylesheet(SingleColumnLayoutStylesheet newStylesheet) {
    if (newStylesheet == _stylesheet) {
      return;
    }

    _stylesheet = newStylesheet;
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel produceViewModel(SingleColumnLayoutViewModel? viewModel) {
    if (viewModel == null) {
      throw Exception("This phase must receive a non-null view model: $this");
    }

    editorLayoutLog.info("(Re)calculating spacing view model for document layout");
    return SingleColumnLayoutViewModel(
      margin: _stylesheet.margin,
      componentViewModels: [
        for (int i = 0; i < viewModel.componentViewModels.length; i += 1) //
          _applyLayoutStyles(i, viewModel.componentViewModels[i]),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applyLayoutStyles(int index, SingleColumnLayoutComponentViewModel viewModel) {
    final standardWidth = _stylesheet.standardContentWidth;
    final basePadding = _stylesheet.blockStyles.standardPadding;
    if (viewModel is ParagraphComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: _stylesheet.blockStyles.textBlockStyleByAttribution(viewModel.blockType)?.maxWidth ?? standardWidth,
        padding: (_stylesheet.blockStyles.textBlockStyleByAttribution(viewModel.blockType)?.paddingAdjustment ??
                EdgeInsets.zero)
            .add(basePadding),
        textStyleBuilder: (attributions) {
          final baseStyle =
              _stylesheet.blockStyles.textBlockStyleByAttribution(viewModel.blockType)?.textStyle ?? const TextStyle();
          return _stylesheet.inlineTextStyler(attributions, baseStyle);
        },
      );
    }
    if (viewModel is BlockquoteComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: _stylesheet.blockStyles.blockquote.maxWidth ?? standardWidth,
        padding: (_stylesheet.blockStyles.blockquote.paddingAdjustment ?? EdgeInsets.zero).add(basePadding),
        textStyleBuilder: (attributions) {
          final baseStyle = _stylesheet.blockStyles.blockquote.textStyle ?? const TextStyle();
          return _stylesheet.inlineTextStyler(attributions, baseStyle);
        },
        backgroundColor: _stylesheet.blockStyles.blockquote.backgroundColor,
        borderRadius: _stylesheet.blockStyles.blockquote.borderRadius,
      );
    }
    if (viewModel is ListItemComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: _stylesheet.blockStyles.listItem.maxWidth ?? standardWidth,
        padding: (_stylesheet.blockStyles.listItem.paddingAdjustment ?? EdgeInsets.zero).add(basePadding),
        textStyleBuilder: (attributions) {
          final baseStyle = _stylesheet.blockStyles.listItem.textStyle ?? const TextStyle();
          return _stylesheet.inlineTextStyler(attributions, baseStyle);
        },
      );
    }
    if (viewModel is ImageComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: _stylesheet.blockStyles.image.maxWidth ?? standardWidth,
        padding: (_stylesheet.blockStyles.image.paddingAdjustment ?? EdgeInsets.zero).add(basePadding),
      );
    }
    if (viewModel is HorizontalRuleComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: _stylesheet.blockStyles.hr.maxWidth ?? standardWidth,
        padding: (_stylesheet.blockStyles.hr.paddingAdjustment ?? EdgeInsets.zero).add(basePadding),
      );
    }

    editorLayoutLog.warning("Tried to apply spacing to unknown layout component view model: $viewModel");
    return viewModel;
  }
}

/// [SingleColumnLayoutStylePhase] that applies custom styling to specific
/// components.
class SingleColumnLayoutCustomComponentStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutCustomComponentStyler({
    SingleColumnCustomComponentStyles? styles,
  }) : _perComponentStyles = styles ?? const SingleColumnCustomComponentStyles();

  SingleColumnCustomComponentStyles _perComponentStyles;

  set styles(SingleColumnCustomComponentStyles? newStyles) {
    if (newStyles == _perComponentStyles) {
      return;
    }

    _perComponentStyles = newStyles ?? const SingleColumnCustomComponentStyles();
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel produceViewModel(SingleColumnLayoutViewModel? viewModel) {
    if (viewModel == null) {
      throw Exception("This phase must receive a non-null view model: $this");
    }

    editorLayoutLog.info("(Re)calculating custom component styles view model for document layout");
    editorLayoutLog.fine("Widths: ${_perComponentStyles.widths}");
    return SingleColumnLayoutViewModel(
      margin: viewModel.margin,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) _applyLayoutStyles(previousViewModel),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applyLayoutStyles(SingleColumnLayoutComponentViewModel viewModel) {
    final componentWidth = _perComponentStyles.getWidth(viewModel.nodeId) ?? viewModel.maxWidth;
    final componentPadding = _perComponentStyles.getPadding(viewModel.nodeId) ?? viewModel.padding;

    if (viewModel is ParagraphComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: componentWidth,
        padding: componentPadding,
      );
    }
    if (viewModel is BlockquoteComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: componentWidth,
        padding: componentPadding,
      );
    }
    if (viewModel is ListItemComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: componentWidth,
        padding: componentPadding,
      );
    }
    if (viewModel is ImageComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: componentWidth,
        padding: componentPadding,
      );
    }
    if (viewModel is HorizontalRuleComponentViewModel) {
      return viewModel.copyWith(
        maxWidth: componentWidth,
        padding: componentPadding,
      );
    }

    editorLayoutLog
        .warning("Tried to apply custom component styles to unknown layout component view model: $viewModel");
    return viewModel;
  }
}

/// [SingleColumnLayoutStylePhase] that applies visual selections to each component,
/// e.g., text selections, image selections, caret positioning.
class SingleColumnLayoutSelectionStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutSelectionStyler({
    required Document document,
    required DocumentComposer composer,
    required Color selectionColor,
    required Color caretColor,
  })  : _document = document,
        _composer = composer,
        _selectionColor = selectionColor,
        _caretColor = caretColor {
    // Our styles need to be re-applied whenever the document selection changes.
    _composer.selectionNotifier.addListener(markDirty);
  }

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(markDirty);
    super.dispose();
  }

  final Document _document;
  final DocumentComposer _composer;
  final Color _selectionColor;
  final Color _caretColor;

  bool _shouldDocumentShowCaret = false;
  set shouldDocumentShowCaret(bool newValue) {
    if (newValue == _shouldDocumentShowCaret) {
      return;
    }

    _shouldDocumentShowCaret = newValue;
    editorLayoutLog.fine("Change to 'document should show caret': $_shouldDocumentShowCaret");
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel produceViewModel(SingleColumnLayoutViewModel? viewModel) {
    if (viewModel == null) {
      throw Exception("This phase must receive a non-null view model: $this");
    }

    editorLayoutLog.info("(Re)calculating selection view model for document layout");
    editorLayoutLog.fine("Applying selection to components: ${_composer.selection}");
    return SingleColumnLayoutViewModel(
      margin: viewModel.margin,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applySelection(previousViewModel),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applySelection(SingleColumnLayoutComponentViewModel viewModel) {
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
      nodeSelection =
          _computeNodeSelection(documentSelection: documentSelection, selectedNodes: selectedNodes, node: node);
    }

    editorLayoutLog.fine("Node selection (${node.id}): $nodeSelection");
    if (node is TextNode) {
      final textSelection = nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
          ? null
          : nodeSelection.nodeSelection as TextSelection;
      if (nodeSelection != null && nodeSelection.nodeSelection is! TextSelection) {
        editorLayoutLog.shout(
            'ERROR: Building a paragraph component but the selection is not a TextSelection. Node: ${node.id}, Selection: ${nodeSelection.nodeSelection}');
      }
      final showCaret = _shouldDocumentShowCaret && nodeSelection != null ? nodeSelection.isExtent : false;
      final highlightWhenEmpty = nodeSelection == null ? false : nodeSelection.highlightWhenEmpty;

      editorLayoutLog.finer(' - ${node.id}: $nodeSelection');
      if (showCaret) {
        editorLayoutLog.finer('   - ^ showing caret');
      }

      editorLayoutLog.finer(' - building a paragraph with selection:');
      editorLayoutLog.finer('   - base: ${textSelection?.base}');
      editorLayoutLog.finer('   - extent: ${textSelection?.extent}');

      if (viewModel is ParagraphComponentViewModel) {
        final newViewModel = viewModel.copyWith(
          selection: textSelection,
          selectionColor: _selectionColor,
          caret: showCaret ? textSelection?.extent : null,
          caretColor: _caretColor,
          highlightWhenEmpty: highlightWhenEmpty,
        );

        if (textSelection != null) {
          editorLayoutLog.fine("View model with selection: ${newViewModel.hashCode}");
        }

        return newViewModel;
      }
      if (viewModel is BlockquoteComponentViewModel) {
        return viewModel.copyWith(
          selection: textSelection,
          selectionColor: _selectionColor,
          caret: showCaret ? textSelection?.extent : null,
          caretColor: _caretColor,
          highlightWhenEmpty: highlightWhenEmpty,
        );
      }
      if (viewModel is ListItemComponentViewModel) {
        return viewModel.copyWith(
          selection: textSelection,
          selectionColor: _selectionColor,
          caret: showCaret ? textSelection?.extent : null,
          caretColor: _caretColor,
        );
      }
    }
    if (viewModel is ImageComponentViewModel) {
      final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as UpstreamDownstreamNodeSelection;

      return viewModel.copyWith(
        selection: selection,
        selectionColor: _selectionColor,
        caret: _shouldDocumentShowCaret && selection != null && selection.isCollapsed ? selection.extent : null,
        caretColor: _caretColor,
      );
    }
    if (viewModel is HorizontalRuleComponentViewModel) {
      final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as UpstreamDownstreamNodeSelection;

      return viewModel.copyWith(
        selection: selection,
        selectionColor: _selectionColor,
        caret: _shouldDocumentShowCaret && selection != null && selection.isCollapsed ? selection.extent : null,
        caretColor: _caretColor,
      );
    }

    // We don't know what kind of component this is. Return it, unmodified.
    return viewModel;
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
        nodeSelection = node.computeSelection(base: baseNodePosition, extent: extentNodePosition);
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
        final isBase = node.id == documentSelection.base.nodeId;
        return DocumentNodeSelection(
          nodeId: node.id,
          nodeSelection: node.computeSelection(
            base: isBase ? documentSelection.base.nodePosition : node.endPosition,
            extent: isBase ? node.endPosition : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
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
            extent: isBase ? documentSelection.base.nodePosition : documentSelection.extent.nodePosition,
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
class SingleColumnLayoutViewModel {
  SingleColumnLayoutViewModel({
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    required List<SingleColumnLayoutComponentViewModel> componentViewModels,
  })  : _margin = margin,
        _componentViewModels = componentViewModels,
        _viewModelsByNodeId = {} {
    for (final componentViewModel in _componentViewModels) {
      _viewModelsByNodeId[componentViewModel.nodeId] = componentViewModel;
    }
  }

  final EdgeInsetsGeometry _margin;
  EdgeInsetsGeometry get margin => _margin;

  final List<SingleColumnLayoutComponentViewModel> _componentViewModels;
  List<SingleColumnLayoutComponentViewModel> get componentViewModels => _componentViewModels;

  final Map<String, SingleColumnLayoutComponentViewModel> _viewModelsByNodeId;
  SingleColumnLayoutComponentViewModel? getComponentViewModelByNodeId(String nodeId) => _viewModelsByNodeId[nodeId];
}

/// Base class for a component view model that appears within a
/// [SingleColumnDocumentLayout].
abstract class SingleColumnLayoutComponentViewModel {
  const SingleColumnLayoutComponentViewModel({
    required this.nodeId,
    this.maxWidth,
    required this.padding,
  });

  final String nodeId;

  /// The maximum width of this component in the layout, or `null` to
  /// defer to the layout's preference.
  final double? maxWidth;

  /// The padding applied around this component.
  final EdgeInsetsGeometry padding;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleColumnLayoutComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          maxWidth == other.maxWidth &&
          padding == other.padding;

  @override
  int get hashCode => nodeId.hashCode ^ maxWidth.hashCode ^ padding.hashCode;
}
