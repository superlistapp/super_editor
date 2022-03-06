import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

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
/// First, a [SingleColumnLayoutComponentViewModel] is created for every
/// [DocumentNode] in the given [document], using the [componentViewModelBuilders].
/// These component view models are assembled into a [SingleColumnLayoutViewModel].
///
/// The view model is styled by passing it through a series of "style phases",
/// known as a [pipeline]. The final, styled, [SingleColumnLayoutViewModel] is
/// available via the [viewModel] property.
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
    required List<ComponentBuilder> componentBuilders,
    required List<SingleColumnLayoutStylePhase> pipeline,
  })  : _document = document,
        _componentBuilders = componentBuilders,
        _pipeline = pipeline {
    _assemblePipeline();
    _viewModel = _createNewViewModel();
    _document.addListener(_onDocumentChange);
  }

  void dispose() {
    _listeners.clear();
    _document.removeListener(_onDocumentChange);
    _disassemblePipeline();
  }

  final Document _document;
  final List<ComponentBuilder> _componentBuilders;
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

  void _onDocumentChange() {
    editorLayoutLog.info("The document changed. Marking the presenter dirty.");
    final wasDirty = isDirty;

    _earliestDirtyPhase = 0;

    if (!wasDirty) {
      // The presenter just went from clean to dirty. Notify listeners.
      for (final listener in _listeners) {
        listener.onPresenterMarkedDirty();
      }
    }
  }

  void _assemblePipeline() {
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

    if (newViewModel == null) {
      // The document changed. All view models were invalidated. Create a
      // new base document view model.
      final components = <SingleColumnLayoutComponentViewModel>[];
      for (int i = 0; i < _document.nodes.length; i += 1) {
        SingleColumnLayoutComponentViewModel? component;
        for (final builder in _componentBuilders) {
          component = builder.createViewModel(_document, _document.nodes[i]);
          if (component != null) {
            break;
          }
        }
        if (component == null) {
          throw Exception("Couldn't find styler to create component for document node: ${_document.nodes[i]}");
        }
        components.add(component);
      }

      newViewModel = SingleColumnLayoutViewModel(
        componentViewModels: components,
      );
    }

    // Style the document view model.
    for (int i = _earliestDirtyPhase; i < _pipeline.length; i += 1) {
      editorLayoutLog.fine("Running phase $i: ${_pipeline[i]}");
      newViewModel = _pipeline[i].style(_document, newViewModel!);
      editorLayoutLog.fine("Storing phase $i view model");
      _phaseViewModels[i] = newViewModel;
    }
    // We're all clean.
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
      editorLayoutLog.fine("Nothing has changed in the view model. Not notifying any listeners.");
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

/// Creates view models and components to display various [DocumentNode]s
/// in a [Document].
abstract class ComponentBuilder {
  /// Produces a [SingleColumnLayoutComponentViewModel] with default styles for the given
  /// [node], or returns `null` if this builder doesn't apply to the given node.
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node);

  /// Creates a visual component that renders the given [viewModel],
  /// or returns `null` if this builder doesn't apply to the given [viewModel].
  ///
  /// Returned widgets should be [StatefulWidget]s that mix in [DocumentComponent].
  ///
  /// This method might be invoked with a type of [viewModel] that it
  /// doesn't know how to work with. When this happens, the method should
  /// return `null`, indicating that it doesn't know how to build a component
  /// for the given [viewModel].
  ///
  /// See [ComponentContext] for expectations about how to use the context
  /// to build a component widget.
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel);
}

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

  /// Styles a [SingleColumnLayoutViewModel] by adjusting the given viewModel.
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel);
}

/// [AttributionStyleBuilder] that returns a default `TextStyle`, for
/// use when creating baseline view models before the text styles are
/// configured.
TextStyle noStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle(
    // Even though this a "no style" builder, we supply a font size
    // and line height because there are a number of places in the editor
    // where these details are needed for layout calculations.
    fontSize: 16,
    height: 1.0,
  );
}

/// Style phase that applies a given [Stylesheet] to the document view model.
class SingleColumnStylesheetStyler extends SingleColumnLayoutStylePhase {
  SingleColumnStylesheetStyler({
    required Stylesheet stylesheet,
  }) : _stylesheet = stylesheet;

  final Stylesheet _stylesheet;

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    return SingleColumnLayoutViewModel(
      padding: _stylesheet.documentPadding ?? viewModel.padding,
      componentViewModels: [
        for (final componentViewModel in viewModel.componentViewModels)
          _styleComponent(
            document,
            document.getNodeById(componentViewModel.nodeId)!,
            componentViewModel.copy(),
          ),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _styleComponent(
    Document document,
    DocumentNode node,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    // Combine all applicable style rules into a single set of styles
    // for this component.
    final aggregateStyles = <String, dynamic>{};
    for (final rule in _stylesheet.rules) {
      if (rule.selector.matches(document, node)) {
        _mergeStyles(
          existingStyles: aggregateStyles,
          newStyles: rule.styler(document, node),
        );
      }
    }

    viewModel
      ..maxWidth = aggregateStyles["maxWidth"] ?? double.infinity
      ..padding = (aggregateStyles["padding"] as CascadingPadding?)?.toEdgeInsets() ?? EdgeInsets.zero;

    // Apply the aggregate styles to this component.
    if (viewModel is TextComponentViewModel) {
      viewModel.textStyleBuilder = (attributions) {
        final baseStyle = aggregateStyles["textStyle"] ?? noStyleBuilder({});
        return _stylesheet.inlineTextStyler(attributions, baseStyle);
      };
    }
    if (viewModel is BlockquoteComponentViewModel) {
      viewModel
        ..backgroundColor = aggregateStyles["backgroundColor"] ?? Colors.transparent
        ..borderRadius = aggregateStyles["borderRadius"] ?? BorderRadius.zero;
    }

    return viewModel;
  }

  void _mergeStyles({
    required Map<String, dynamic> existingStyles,
    required Map<String, dynamic> newStyles,
  }) {
    for (final entry in newStyles.entries) {
      if (existingStyles.containsKey(entry.key)) {
        // Try to merge. If we can't, then overwrite.
        final oldValue = existingStyles[entry.key];
        final newValue = entry.value;

        if (oldValue is TextStyle && newValue is TextStyle) {
          existingStyles[entry.key] = oldValue.merge(newValue);
        } else if (oldValue is CascadingPadding && newValue is CascadingPadding) {
          existingStyles[entry.key] = newValue.applyOnTopOf(oldValue);
        }
      } else {
        // This is a new entry, just set it.
        existingStyles[entry.key] = entry.value;
      }
    }
  }
}

/// [SingleColumnLayoutStylePhase] that applies custom styling to specific
/// components.
///
/// Each per-component style should be defined within a [SingleColumnLayoutComponentStyles]
/// and then stored within the given [DocumentNode]'s metadata.
///
/// Every time a [DocumentNode]'s metadata changes, this phase needs to re-run so
/// that it picks up any style related changes. Given that the entire style pipeline
/// re-runs every time the document changes, this phase automatically runs at the
/// appropriate time.
class SingleColumnLayoutCustomComponentStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutCustomComponentStyler();

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    editorLayoutLog.info("(Re)calculating custom component styles view model for document layout");
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels)
          _applyLayoutStyles(
            document.getNodeById(previousViewModel.nodeId)!,
            previousViewModel.copy(),
          ),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _applyLayoutStyles(
    DocumentNode node,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    final componentStyles = SingleColumnLayoutComponentStyles.fromMetadata(node);

    viewModel
      ..maxWidth = componentStyles.width ?? viewModel.maxWidth
      ..padding = componentStyles.padding ?? viewModel.padding;

    editorLayoutLog
        .warning("Tried to apply custom component styles to unknown layout component view model: $viewModel");
    return viewModel;
  }
}

class SingleColumnLayoutComponentStyles {
  static const _metadataKey = "singleColumnLayout";
  static const _widthKey = "width";
  static const _paddingKey = "padding";

  factory SingleColumnLayoutComponentStyles.fromMetadata(DocumentNode node) {
    return SingleColumnLayoutComponentStyles(
      width: node.metadata[_metadataKey]?[_widthKey],
      padding: node.metadata[_metadataKey]?[_paddingKey],
    );
  }

  const SingleColumnLayoutComponentStyles({
    this.width,
    this.padding,
  });

  final double? width;
  final EdgeInsetsGeometry? padding;

  void applyTo(DocumentNode node) {
    node.putMetadataValue(_metadataKey, {
      _widthKey: width,
      _paddingKey: padding,
    });
  }

  Map<String, dynamic> toMetadata() => {
        _metadataKey: {
          _widthKey: width,
          _paddingKey: padding,
        },
      };

  SingleColumnLayoutComponentStyles copyWith({
    double? width,
    EdgeInsetsGeometry? padding,
  }) {
    return SingleColumnLayoutComponentStyles(
      width: width ?? this.width,
      padding: padding ?? this.padding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleColumnLayoutComponentStyles &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          padding == other.padding;

  @override
  int get hashCode => width.hashCode ^ padding.hashCode;
}

/// [SingleColumnLayoutStylePhase] that applies visual selections to each component,
/// e.g., text selections, image selections, caret positioning.
class SingleColumnLayoutSelectionStyler extends SingleColumnLayoutStylePhase {
  SingleColumnLayoutSelectionStyler({
    required Document document,
    required DocumentComposer composer,
    required SelectionStyles selectionStyles,
  })  : _document = document,
        _composer = composer,
        _selectionStyles = selectionStyles {
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
  final SelectionStyles _selectionStyles;

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
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    editorLayoutLog.info("(Re)calculating selection view model for document layout");
    editorLayoutLog.fine("Applying selection to components: ${_composer.selection}");
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) //
          _applySelection(previousViewModel.copy()),
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
      final highlightWhenEmpty =
          nodeSelection == null ? false : nodeSelection.highlightWhenEmpty && _selectionStyles.highlightEmptyTextBlocks;

      editorLayoutLog.finer(' - ${node.id}: $nodeSelection');
      if (showCaret) {
        editorLayoutLog.finer('   - ^ showing caret');
      }

      editorLayoutLog.finer(' - building a paragraph with selection:');
      editorLayoutLog.finer('   - base: ${textSelection?.base}');
      editorLayoutLog.finer('   - extent: ${textSelection?.extent}');

      if (viewModel is TextComponentViewModel) {
        viewModel
          ..selection = textSelection
          ..selectionColor = _selectionStyles.selectionColor
          ..caret = showCaret ? textSelection?.extent : null
          ..caretColor = _selectionStyles.caretColor
          ..highlightWhenEmpty = highlightWhenEmpty;
      }
    }
    if (viewModel is ImageComponentViewModel) {
      final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as UpstreamDownstreamNodeSelection;

      viewModel
        ..selection = selection
        ..selectionColor = _selectionStyles.selectionColor
        ..caret = _shouldDocumentShowCaret && selection != null && selection.isCollapsed ? selection.extent : null
        ..caretColor = _selectionStyles.caretColor;
    }
    if (viewModel is HorizontalRuleComponentViewModel) {
      final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as UpstreamDownstreamNodeSelection;

      viewModel
        ..selection = selection
        ..selectionColor = _selectionStyles.selectionColor
        ..caret = _shouldDocumentShowCaret && selection != null && selection.isCollapsed ? selection.extent : null
        ..caretColor = _selectionStyles.selectionColor;
    }

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
            extent: isBase ? documentSelection.base.nodePosition : documentSelection.extent.nodePosition,
          ),
          isBase: isBase,
          isExtent: !isBase,
          highlightWhenEmpty: isBase,
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
          highlightWhenEmpty: true,
        );
      }
    }
  }
}

/// View model for an entire [SingleColumnDocumentLayout].
class SingleColumnLayoutViewModel {
  SingleColumnLayoutViewModel({
    this.padding = EdgeInsets.zero,
    required List<SingleColumnLayoutComponentViewModel> componentViewModels,
  })  : _componentViewModels = componentViewModels,
        _viewModelsByNodeId = {} {
    for (final componentViewModel in _componentViewModels) {
      _viewModelsByNodeId[componentViewModel.nodeId] = componentViewModel;
    }
  }

  final EdgeInsetsGeometry padding;

  final List<SingleColumnLayoutComponentViewModel> _componentViewModels;
  List<SingleColumnLayoutComponentViewModel> get componentViewModels => _componentViewModels;

  final Map<String, SingleColumnLayoutComponentViewModel> _viewModelsByNodeId;
  SingleColumnLayoutComponentViewModel? getComponentViewModelByNodeId(String nodeId) => _viewModelsByNodeId[nodeId];
}

/// Base class for a component view model that appears within a
/// [SingleColumnDocumentLayout].
abstract class SingleColumnLayoutComponentViewModel {
  SingleColumnLayoutComponentViewModel({
    required this.nodeId,
    this.maxWidth,
    required this.padding,
  });

  final String nodeId;

  /// The maximum width of this component in the layout, or `null` to
  /// defer to the layout's preference.
  double? maxWidth;

  /// The padding applied around this component.
  EdgeInsetsGeometry padding;

  SingleColumnLayoutComponentViewModel copy();

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

mixin TextComponentViewModel on SingleColumnLayoutComponentViewModel {
  AttributionStyleBuilder get textStyleBuilder;
  set textStyleBuilder(AttributionStyleBuilder styleBuilder);

  TextDirection get textDirection;
  set textDirection(TextDirection direction);

  TextAlign get textAlignment;
  set textAlignment(TextAlign alignment);

  TextSelection? get selection;
  set selection(TextSelection? selection);

  Color get selectionColor;
  set selectionColor(Color color);

  TextPosition? get caret;
  set caret(TextPosition? position);

  Color get caretColor;
  set caretColor(Color color);

  bool get highlightWhenEmpty;
  set highlightWhenEmpty(bool highlight);
}
