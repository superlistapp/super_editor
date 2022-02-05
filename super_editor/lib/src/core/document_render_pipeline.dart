import 'package:flutter/foundation.dart';

import 'document.dart';

/// A processing pipeline that goes from a logical [Document] to a list
/// of [ComponentMetadata] that're ready to be displayed in a document layout.
///
/// The concepts related to this pipeline are as follows:
///
///  * [Document]: A logical representation of a document, independent from
///    how that document is laid out or painted.
///  * [DocumentLayout]: Layout algorithm for the overall document.
///  * [ComponentMetadata]: How an individual content item should be presented.
///    For example, there might be an `ImageComponentMetadata` with a `maxWidth`
///    property that the [DocumentLayout] is expected to honor.
///
/// When the client `pump()`s this pipeline, it inspects each [DocumentNode] in the
/// given [Document], creates a [ComponentMetadata] for that node, and then allows
/// a [ComponentConfiguration] to adjust the metadata as it sees fit. Finally, all
/// the [ComponentMetadata]s are made available in [componentsMetadata];
///
/// The following is an example of how a single node might become a component metadata:
///
///   1. Start with an `ImageNode` that has an image URL.
///   2. The [ComponentMetadataFactory] creates a `ImageComponentMetadata` with a copy
///      of the image URL from the `ImageNode`.
///   3. The [ComponentConfiguration] decides that this image should be displayed
///      full-bleed, so the `ImageComponentMetadata` is adjusted to have a `maxWidth`
///      of `double.infinity`.
///   4. The [ComponentConfiguration] also decides that this image should be displayed
///      in a selected state, so the `ImageComponentMetadata` is adjusted so that
///      `isSelected` is `true`.
///   5. The final `ImageComponentMetadata` is placed in [componentsMetadata].
///   6. This process is repeated for all other nodes in the `Document`.
///
/// Different [DocumentLayout]s might require different component metadata.
/// Therefore, the specific type of metadata that this pipeline works with
/// is configurable via the generic [MetadataType].
class DocumentRenderPipeline<MetadataType extends ComponentMetadata> {
  DocumentRenderPipeline({
    required ComponentMetadataFactory<MetadataType> metadataFactory,
    required ComponentConfiguration<MetadataType> metadataConfiguration,
  })  : _metadataFactory = metadataFactory,
        _metadataConfiguration = metadataConfiguration,
        _layoutMetadata = _LayoutMetadata();

  void dispose() {
    _layoutMetadata.dispose();
  }

  final ComponentMetadataFactory<MetadataType> _metadataFactory;
  final ComponentConfiguration<MetadataType> _metadataConfiguration;

  /// The component metadata, used to layout and display each piece of
  /// content in the document.
  ///
  /// The component metadata needs to be regenerated any time the corresponding
  /// [Document] changes. To regenerate the metadata, call [pump].
  List<MetadataType> get componentsMetadata => _layoutMetadata.componentsMetadata;
  final _LayoutMetadata<MetadataType> _layoutMetadata;

  /// (Re)generates all the metadata components for the given [document], and makes
  /// the metadata available in [componentsMetadata].
  ///
  /// All layout and component change listeners are notified of any changes since
  /// the last time `pump()` was executed.
  void pump(Document document) {
    final nodes = document.nodes;

    final componentsMetadata = <MetadataType>[];
    for (final node in nodes) {
      // Create the base version of the metadata for this node.
      var componentMetadata = _metadataFactory.createComponentConfig(node);

      // Adjust the base metadata, e.g., add text selection, caret, text style, etc.
      componentMetadata = _metadataConfiguration.configureComponentMetadata(document, node, componentMetadata);

      componentsMetadata.add(componentMetadata);
    }
    // Update the metadata cache. We cache the metadata so that we only notify
    // listeners of changes, rather than assuming everything changed.
    _layoutMetadata.updateComponents(componentsMetadata);

    // Notify listeners of any changes to the metadata.
    _layoutMetadata.notifyChangeListenersAndClearDirty();
  }

  /// Adds a callback that's invoked whenever new components are added,
  /// or old components are removed from the component metadata.
  void addLayoutChangeCallback(VoidCallback callback) {
    _layoutMetadata.addLayoutChangeCallback(callback);
  }

  /// Removes a callback that was added in [addLayoutChangeCallback].
  void removeLayoutChangeCallback(VoidCallback callback) {
    _layoutMetadata.removeLayoutChangeCallback(callback);
  }

  /// Adds a callback that's invoked when the component metadata that corresponds
  /// to the [DocumentNode] with the given [nodeId] changes.
  void addComponentChangeCallback(String nodeId, ComponentChangeCallback<MetadataType> callback) {
    _layoutMetadata.addComponentChangeCallback(nodeId, callback);
  }

  /// Removes a callback that was added with [addComponentChangeCallback()].
  void removeComponentChangeCallback(String nodeId, ComponentChangeCallback<MetadataType> callback) {
    _layoutMetadata.removeComponentChangeCallback(nodeId, callback);
  }
}

/// Base class for component metadata, which represents how a single piece of
/// document content should be presented, e.g., a paragraph or image.
abstract class ComponentMetadata {
  String get nodeId;
}

/// Creates a [ComponentMetadata] for a given [DocumentNode].
///
/// The mapping from a [DocumentNode] to a specific type of [ComponentMetadata]
/// might be different for different layouts. For example, a single-column document
/// layout might support a `SingleColumnImageComponentMetadata` configuration with a
/// `fullBleed` property, whereas a newspaper-style document layout might support a
/// `NewspaperImageComponentMetadata`, which doesn't have a `fullBleed` property.
abstract class ComponentMetadataFactory<MetadataType extends ComponentMetadata> {
  /// Creates a [ComponentMetadata] to present the given [node], with a default
  /// configuration.
  MetadataType createComponentConfig(DocumentNode node);
}

/// Adjusts given [ComponentMetadata]s based on style rules and editor interaction.
///
/// For example, a `ComponentConfiguration` implementation might include all the
/// style rules for headers, paragraphs, and blockquotes. It might also include
/// knowledge of the user's current selection, thereby configuring [ComponentMetadata]
/// to show selected text, or a selected image.
abstract class ComponentConfiguration<MetadataType extends ComponentMetadata> {
  /// Returns an adjusted copy of [componentMetadata] based on any style rules,
  /// user selections, or any other editor interaction that impacts the presentation
  /// of this piece of content.
  MetadataType configureComponentMetadata(Document document, DocumentNode node, MetadataType componentMetadata);
}

/// Cache of [ComponentMetadata] that notifies listeners when the metadata changes.
class _LayoutMetadata<MetadataType extends ComponentMetadata> {
  void dispose() {
    _layoutChangeCallbacks.clear();
    _componentChangeCallbacks.clear();
  }

  final Map<String, MetadataType> _nodeIdToMetadata = {};
  final _componentsMetadata = <MetadataType>[];
  List<MetadataType> get componentsMetadata => _componentsMetadata;

  bool _isDirty = false;
  final _dirtyComponents = <String>{};

  /// Replaces the cached metadata with [componentsMetadata], and marks all
  /// changed metadata as dirty so that listeners can be notified, when desired.
  ///
  /// This method doesn't notify any listeners.
  void updateComponents(List<MetadataType> componentsMetadata) {
    for (final componentMetadata in componentsMetadata) {
      _updateComponentMetadata(componentMetadata);
    }

    _componentsMetadata
      ..clear()
      ..addAll(componentsMetadata);

    _removeOldMetadataInNodeMap();
  }

  void _updateComponentMetadata(MetadataType componentMetadata) {
    final existingMetadata = _nodeIdToMetadata[componentMetadata.nodeId];
    if (existingMetadata == componentMetadata) {
      // We're already up-to-date. Return.
      return;
    }

    if (existingMetadata == null) {
      _isDirty = true;
    }

    _nodeIdToMetadata[componentMetadata.nodeId] = componentMetadata;
    _dirtyComponents.add(componentMetadata.nodeId);
  }

  void _removeOldMetadataInNodeMap() {
    for (final entry in _nodeIdToMetadata.entries) {
      if (_componentsMetadata.indexWhere((element) => element.nodeId == entry.key) < 0) {
        _nodeIdToMetadata.remove(entry.key);
      }
    }
  }

  /// Notifies listeners of relevant changes and then clears all dirty flags.
  ///
  /// Component metadata change listeners are notified if their respective
  /// component metadata was marked dirty in a previous call to [updateComponents].
  ///
  /// If component metadatas were added or removed in a previous call to
  /// [updateComponents], then layout change listeners are notified, too.
  void notifyChangeListenersAndClearDirty() {
    for (final dirtyComponentNodeId in _dirtyComponents) {
      _notifyComponentChangeCallbacks(_nodeIdToMetadata[dirtyComponentNodeId]!);
    }

    if (_isDirty) {
      _notifyLayoutChangeCallbacks();
    }

    _dirtyComponents.clear();
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

  final _componentChangeCallbacks = <String, Set<ComponentChangeCallback<MetadataType>>>{};

  void addComponentChangeCallback(String nodeId, ComponentChangeCallback<MetadataType> callback) {
    _componentChangeCallbacks[nodeId] ??= <ComponentChangeCallback<MetadataType>>{};
    _componentChangeCallbacks[nodeId]!.add(callback);
  }

  void removeComponentChangeCallback(String nodeId, ComponentChangeCallback<MetadataType> callback) {
    _componentChangeCallbacks[nodeId]?.remove(callback);
  }

  void _notifyComponentChangeCallbacks(MetadataType componentMetadata) {
    if (_componentChangeCallbacks[componentMetadata.nodeId] == null) {
      return;
    }

    final callbacksCopy = Set.from(_componentChangeCallbacks[componentMetadata.nodeId]!);
    for (final callback in callbacksCopy) {
      callback(componentMetadata);
    }
  }
}

/// Callback invoked when a specific [ComponentMetadata] changes.
typedef ComponentChangeCallback<T extends ComponentMetadata> = void Function(T componentMetadata);
