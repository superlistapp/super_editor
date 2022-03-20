import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

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
/// A [SingleColumnLayoutComponentViewModel] is created for every [DocumentNode]
/// in the given [document], using the [ComponentBuilder]s. These component
/// view models are assembled into a [SingleColumnLayoutViewModel].
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
/// makes any desired style changes, and then returns the new view model.
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

  void applyStyles(Map<String, dynamic> styles) {
    maxWidth = styles["maxWidth"] ?? double.infinity;
    padding = (styles["padding"] as CascadingPadding?)?.toEdgeInsets() ?? EdgeInsets.zero;
  }

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
