import 'package:flutter/foundation.dart';

import 'document.dart';

/// A processing pipeline that goes from a logical [Document] to a list
/// of [ComponentViewModel]s that are ready to be displayed in a document layout.
///
/// The concepts related to this pipeline are as follows:
///
///  * [Document]: A logical representation of a document, independent from
///    how that document is laid out or painted.
///  * [DocumentLayout]: Layout algorithm for the overall document.
///  * [ComponentViewModel]: How an individual content item should be presented.
///    For example, there might be an `ImageComponentViewModel` with a `maxWidth`
///    property that the [DocumentLayout] is expected to honor.
///
/// When the client `pump()`s this pipeline, it inspects each [DocumentNode] in the
/// given [Document], creates a [ComponentViewModel] for that node, and then allows
/// a [ComponentStyler] to adjust the view models as it sees fit. Finally, all
/// the [ComponentViewModel]s are made available in [componentsViewModel];
///
/// The following is an example of how a single node might become a component view model:
///
///   1. Start with an `ImageNode` that has an image URL.
///   2. The [ComponentViewModelFactory] creates a `ImageComponentViewModel` with a copy
///      of the image URL from the `ImageNode`.
///   3. The [ComponentStyler] decides that this image should be displayed
///      full-bleed, so the `ImageComponentViewModel` is adjusted to have a `maxWidth`
///      of `double.infinity`.
///   4. The [ComponentStyler] also decides that this image should be displayed
///      in a selected state, so the `ImageComponentViewModel` is adjusted so that
///      `isSelected` is `true`.
///   5. The final `ImageComponentViewModel` is placed in [componentsViewModel].
///   6. This process is repeated for all other nodes in the `Document`.
///
/// Different [DocumentLayout]s might require different component view models.
/// Therefore, the specific type of view model that this pipeline works with
/// is configurable via the generic [ViewModelType].
class DocumentRenderPipeline<ViewModelType extends ComponentViewModel> {
  DocumentRenderPipeline({
    required ComponentViewModelFactory<ViewModelType> viewModelFactory,
    required ComponentStyler<ViewModelType> componentStyler,
  })  : _viewModelFactory = viewModelFactory,
        _viewModelStyler = componentStyler,
        _viewModelCache = _LayoutViewModelCache();

  void dispose() {
    _viewModelCache.dispose();
  }

  final ComponentViewModelFactory<ViewModelType> _viewModelFactory;
  final ComponentStyler<ViewModelType> _viewModelStyler;

  /// The component view models, used to layout and display each piece of
  /// content in the document.
  ///
  /// The component view models need to be regenerated any time the corresponding
  /// [Document] changes. To regenerate the view models, call [pump].
  List<ViewModelType> get componentViewModels => _viewModelCache.componentViewModels;
  final _LayoutViewModelCache<ViewModelType> _viewModelCache;

  /// (Re)generates all the component view models for the given [document], and makes
  /// the view models available in [componentViewModels].
  ///
  /// All layout and component change listeners are notified of any changes since
  /// the last time `pump()` was executed.
  void pump(Document document) {
    final nodes = document.nodes;

    final componentViewModels = <ViewModelType>[];
    for (final node in nodes) {
      // Create the base version of the view model for this node.
      var viewModel = _viewModelFactory.createComponentViewModel(document, node);

      // Adjust the base view model, e.g., add text selection, caret, text style, etc.
      viewModel = _viewModelStyler.styleComponentViewModel(document, node, viewModel);

      componentViewModels.add(viewModel);
    }
    // Update the view model cache. We cache the view models so that we only notify
    // listeners of changes, rather than assuming everything changed.
    _viewModelCache.updateComponents(componentViewModels);

    // Notify listeners of any changes to the view models.
    _viewModelCache.notifyChangeListenersAndClearDirty();
  }

  /// Adds a callback that's invoked whenever new components are added,
  /// or old components are removed from the component view model.
  void addLayoutChangeCallback(VoidCallback callback) {
    _viewModelCache.addLayoutChangeCallback(callback);
  }

  /// Removes a callback that was added in [addLayoutChangeCallback].
  void removeLayoutChangeCallback(VoidCallback callback) {
    _viewModelCache.removeLayoutChangeCallback(callback);
  }

  /// Adds a callback that's invoked when the component view model that corresponds
  /// to the [DocumentNode] with the given [nodeId] changes.
  void addComponentChangeCallback(String nodeId, ComponentChangeCallback<ViewModelType> callback) {
    _viewModelCache.addComponentChangeCallback(nodeId, callback);
  }

  /// Removes a callback that was added with [addComponentChangeCallback()].
  void removeComponentChangeCallback(String nodeId, ComponentChangeCallback<ViewModelType> callback) {
    _viewModelCache.removeComponentChangeCallback(nodeId, callback);
  }
}

/// Base class for component metadata, which represents how a single piece of
/// document content should be presented, e.g., a paragraph or image.
abstract class ComponentViewModel {
  String get nodeId;
}

/// Creates a [ComponentViewModel] for a given [DocumentNode].
///
/// The mapping from a [DocumentNode] to a specific type of [ComponentViewModel]
/// might be different for different layouts. For example, a single-column document
/// layout might support a `SingleColumnImageComponentViewModel` configuration with a
/// `fullBleed` property, whereas a newspaper-style document layout might support a
/// `NewspaperImageComponentViewModel`, which doesn't have a `fullBleed` property.
abstract class ComponentViewModelFactory<ViewModelType extends ComponentViewModel> {
  /// Creates a [ComponentViewModel] to present the given [node], with a default
  /// configuration.
  ViewModelType createComponentViewModel(Document document, DocumentNode node);
}

/// Adjusts given [ComponentViewModel]s based on style rules and editor interaction.
///
/// For example, a `ComponentStyler` implementation might include all the
/// style rules for headers, paragraphs, and blockquotes. It might also include
/// knowledge of the user's current selection, thereby configuring a [ComponentViewModel]
/// to show selected text, or a selected image.
abstract class ComponentStyler<ViewModelType extends ComponentViewModel> {
  /// Returns an adjusted copy of [componentViewModel] based on any style rules,
  /// user selections, or any other editor interaction that impacts the presentation
  /// of this piece of content.
  ViewModelType styleComponentViewModel(Document document, DocumentNode node, ViewModelType componentViewModel);
}

/// Cache of [ComponentViewModel]s that notifies listeners when the view models change.
class _LayoutViewModelCache<ViewModelType extends ComponentViewModel> {
  void dispose() {
    _layoutChangeCallbacks.clear();
    _componentChangeCallbacks.clear();
  }

  final Map<String, ViewModelType> _nodeIdToViewModel = {};
  final _viewModels = <ViewModelType>[];
  List<ViewModelType> get componentViewModels => _viewModels;

  bool _isDirty = false;
  final _dirtyViewModels = <String>{};

  /// Replaces the cached view models with [componentViewModels], and marks all
  /// changed view models as dirty so that listeners can be notified, when desired.
  ///
  /// This method doesn't notify any listeners.
  void updateComponents(List<ViewModelType> componentViewModels) {
    for (final viewModel in componentViewModels) {
      _updateComponentViewModel(viewModel);
    }

    _viewModels
      ..clear()
      ..addAll(componentViewModels);

    _removeOldViewModelsInNodeMap();
  }

  void _updateComponentViewModel(ViewModelType viewModel) {
    final existingViewModel = _nodeIdToViewModel[viewModel.nodeId];
    if (existingViewModel == viewModel) {
      // We're already up-to-date. Return.
      return;
    }

    if (existingViewModel == null) {
      _isDirty = true;
    }

    _nodeIdToViewModel[viewModel.nodeId] = viewModel;
    _dirtyViewModels.add(viewModel.nodeId);
  }

  void _removeOldViewModelsInNodeMap() {
    for (final entry in _nodeIdToViewModel.entries) {
      if (_viewModels.indexWhere((element) => element.nodeId == entry.key) < 0) {
        _nodeIdToViewModel.remove(entry.key);
      }
    }
  }

  /// Notifies listeners of relevant changes and then clears all dirty flags.
  ///
  /// Component view model change-listeners are notified if their respective
  /// component view model was marked dirty in a previous call to [updateComponents].
  ///
  /// If component view models were added or removed in a previous call to
  /// [updateComponents], then layout change listeners are notified, too.
  void notifyChangeListenersAndClearDirty() {
    for (final dirtyComponentNodeId in _dirtyViewModels) {
      _notifyComponentChangeCallbacks(_nodeIdToViewModel[dirtyComponentNodeId]!);
    }

    if (_isDirty) {
      _notifyLayoutChangeCallbacks();
    }

    _dirtyViewModels.clear();
    _isDirty = false;
  }

  final _layoutChangeCallbacks = <VoidCallback>{};

  void addLayoutChangeCallback(VoidCallback callback) {
    _layoutChangeCallbacks.add(callback);
  }

  void removeLayoutChangeCallback(VoidCallback callback) {
    _layoutChangeCallbacks.remove(callback);
  }

  void _notifyLayoutChangeCallbacks() {
    final callbacksCopy = Set.from(_layoutChangeCallbacks);
    for (final callback in callbacksCopy) {
      callback();
    }
  }

  final _componentChangeCallbacks = <String, Set<ComponentChangeCallback<ViewModelType>>>{};

  void addComponentChangeCallback(String nodeId, ComponentChangeCallback<ViewModelType> callback) {
    _componentChangeCallbacks[nodeId] ??= <ComponentChangeCallback<ViewModelType>>{};
    _componentChangeCallbacks[nodeId]!.add(callback);
  }

  void removeComponentChangeCallback(String nodeId, ComponentChangeCallback<ViewModelType> callback) {
    _componentChangeCallbacks[nodeId]?.remove(callback);
  }

  void _notifyComponentChangeCallbacks(ViewModelType viewModel) {
    if (_componentChangeCallbacks[viewModel.nodeId] == null) {
      return;
    }

    final callbacksCopy = Set.from(_componentChangeCallbacks[viewModel.nodeId]!);
    for (final callback in callbacksCopy) {
      callback(viewModel);
    }
  }
}

/// Callback invoked when a specific [ComponentViewModel] changes.
typedef ComponentChangeCallback<T extends ComponentViewModel> = void Function(T componentViewModel);
