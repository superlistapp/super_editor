import 'dart:collection';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/sliver_hybrid_stack.dart';

/// Widget that displays [content] above a number of [underlays], and beneath a number of
/// [overlays].
///
/// This widget is similar in behavior to a `Stack`, except this widget alters the build
/// and layout order to support use-cases where various layers depend upon the layout of
/// a single [content] layer.
///
/// This widget is useful for use-cases where decorations need to be positioned relative
/// to content within the [content] widget. For example, this [ContentLayers] might be
/// used to display a document as [content] and then display text selection as an
/// underlay, the caret as an overlay, and user comments as another overlay.
///
/// The layers are sized to be exactly the same as the [content], and the layers are
/// positioned at the same (x,y) as [content].
///
/// The layers are built after [content] is laid out, so that the layers can inspect the
/// [content] layout during the layers' build phase. This makes it easy, for example, to
/// position a caret on top of a document, using only the widget tree.
class ContentLayers extends RenderObjectWidget {
  const ContentLayers({
    super.key,
    this.underlays = const [],
    required this.content,
    this.overlays = const [],
  });

  /// Layers displayed beneath the [content].
  ///
  /// These layers are placed at the same (x,y) as [content], and they're forced to layout
  /// at the exact same size as [content].
  ///
  /// {@template layers_as_builders}
  /// Layers are structured as [WidgetBuilder]s so that they can be re-built whenever
  /// the content layout changes, without interference from Flutter's standard build system.
  /// Ideally, layers would be pure [Widget]s, but this is a consequence of how Flutter's
  /// [BuildOwner] works. For more details, see https://github.com/flutter/flutter/issues/123305
  /// and https://github.com/superlistapp/super_editor/pull/1239
  /// {@endtemplate}
  final List<ContentLayerWidgetBuilder> underlays;

  /// The primary content displayed in this widget, which determines the size and location
  /// of all [underlays] and [overlays].
  final Widget Function(VoidCallback onBuildScheduled) content;

  /// Layers displayed above the [content].
  ///
  /// These layers are placed at the same (x,y) as [content], and they're forced to layout
  /// at the exact same size as [content].
  ///
  /// {@macro layers_as_builders}
  final List<ContentLayerWidgetBuilder> overlays;

  @override
  RenderObjectElement createElement() {
    return ContentLayersElement(this);
  }

  @override
  RenderContentLayers createRenderObject(BuildContext context) {
    return RenderContentLayers(context as ContentLayersElement);
  }
}

/// `Element` for a [ContentLayers] widget.
///
/// Must have a [renderObject] of type [RenderContentLayers].
class ContentLayersElement extends RenderObjectElement {
  /// The real Flutter framework `onBuildScheduled` callback.
  ///
  /// This property is non-null when one or more [ContentLayersElement]s are in the
  /// tree, and `null` otherwise.
  ///
  /// This callback is held statically, rather than per-instance, because Flutter
  /// might activate a new [ContentLayersElement] before deactivating an old
  /// [ContentLayersElement], or there might be multiple [ContentLayersElement]s
  /// in the tree. In these cases, we can't consistently replace Flutter's
  /// `onBuildScheduled` callback without losing the original callback.
  static VoidCallback? _realOnBuildScheduled;

  /// Listeners that are registered by [ContentLayersElement]s to find out when
  /// the Flutter framework schedules builds, so that [ContentLayerElement]s can
  /// manage their layers to avoid invalid build timing.
  static final _onBuildListeners = <VoidCallback>{};

  /// The Flutter framework has scheduled a build by calling `onBuildScheduled`
  /// on a [BuildOwner].
  ///
  /// This global static method calls build schedule listeners on all instances
  /// of [ContentLayersElement], which registered a listener with [_onBuildListeners].
  static void _globalOnBuildScheduled() {
    // Call the real Flutter onBuildScheduled callback so Flutter works as expected.
    _realOnBuildScheduled!();

    for (final listener in _onBuildListeners) {
      listener();
    }
  }

  ContentLayersElement(ContentLayers widget) : super(widget);

  List<Element> _underlays = <Element>[];
  Element? _content;
  List<Element> _overlays = <Element>[];

  // We need to track the children for which framework has called `forgetChild`,
  // these need to be excluded from the visitChildren method until next update().
  // ForgetChild is called for elements that will be reparented to avoid unmounting
  // and remounting them.
  final Set<Element> _forgottenChildren = HashSet<Element>();

  @override
  ContentLayers get widget => super.widget as ContentLayers;

  @override
  RenderContentLayers get renderObject => super.renderObject as RenderContentLayers;

  @override
  void mount(Element? parent, Object? newSlot) {
    contentLayersLog.fine("ContentLayersElement - mounting");
    super.mount(parent, newSlot);

    // Intercept calls to the BuildOwner's onBuildScheduled so that we can hijack an
    // opportunity to check our subtrees for dirty elements before they rebuild.
    if (_realOnBuildScheduled == null) {
      _realOnBuildScheduled = owner!.onBuildScheduled!;
      owner!.onBuildScheduled = _globalOnBuildScheduled;
      _onBuildListeners.add(_onBuildScheduled);
    }

    _content = inflateWidget(widget.content(_onContentBuildScheduled), _contentSlot);
  }

  @override
  void activate() {
    contentLayersLog.fine("ContentLayersElement - activating");
    super.activate();
  }

  @override
  void deactivate() {
    contentLayersLog.fine("ContentLayersElement - deactivating");
    // We have to deactivate the underlays and overlays ourselves, because we
    // intentionally don't visit them in visitChildren().
    for (final underlay in _underlays) {
      deactivateChild(underlay);
    }
    _underlays = const [];

    for (final overlay in _overlays) {
      deactivateChild(overlay);
    }
    _overlays = const [];

    super.deactivate();
  }

  @override
  void unmount() {
    contentLayersLog.fine("ContentLayersElement - unmounting");

    // Remove our intercepting onBuildScheduled callback.
    _onBuildListeners.remove(_onBuildScheduled);
    if (_onBuildListeners.isEmpty) {
      owner!.onBuildScheduled = _realOnBuildScheduled;
    }

    super.unmount();
  }

  void _onBuildScheduled() {
    contentLayersLog.finer("ON BUILD SCHEDULED");

    // Schedule a callback to run at the beginning of the next frame so we can check
    // for dirty subtrees.
    //
    // If the content is dirty, but the layers are clean, then the layers won't attempt
    // to rebuild, and we can let Flutter build the content whenever it wants.
    //
    // If a layer is dirty, but the content is clean, then the content layout is still
    // valid, and we can let Flutter build the layer whenever it wants.
    //
    // However, if both the content and at least one layer are both dirty, then we must
    // make absolutely sure that the content builds first. To do this, we deactivate the
    // layer Elements, preventing Flutter from rebuilding them, and then we reactivate
    // the layers during the next layout pass, after the content is laid out.
    SchedulerBinding.instance.scheduleFrameCallback((timeStamp) {
      contentLayersLog.finer("SCHEDULED FRAME CALLBACK");
      if (!mounted) {
        contentLayersLog.finer("We've unmounted since the end of the frame. Fizzling.");
        return;
      }

      final isContentDirty = _isContentDirty();
      final isAnyLayerDirty = _isAnyLayerDirty();

      if (isContentDirty && isAnyLayerDirty) {
        contentLayersLog.fine("Marking needs build because content and at least one layer are both dirty.");
        _temporarilyForgetLayers();
      }
    });
  }

  bool _isContentDirty() => _isSubtreeDirty(_content!);

  bool _isAnyLayerDirty() {
    contentLayersLog.finer("Checking if any layer is dirty");
    bool hasDirtyElements = false;

    contentLayersLog.finer("Checking underlays");
    for (final underlay in _underlays) {
      contentLayersLog.finer(() => " - Is underlay ($underlay) subtree dirty? ${_isSubtreeDirty(underlay)}");
      hasDirtyElements = hasDirtyElements || _isSubtreeDirty(underlay);
    }

    contentLayersLog.finer("Checking overlays");
    for (final overlay in _overlays) {
      contentLayersLog.finer(() => " - Is overlay ($overlay) subtree dirty? ${_isSubtreeDirty(overlay)}");
      hasDirtyElements = hasDirtyElements || _isSubtreeDirty(overlay);
    }

    return hasDirtyElements;
  }

  static bool _isDirty = false;

  bool _isSubtreeDirty(Element element) {
    _isDirty = false;
    element.visitChildren(_isSubtreeDirtyVisitor);
    return _isDirty;
  }

// This is intentionally static to prevent closure allocation during
  // the traversal of the element tree.
  static void _isSubtreeDirtyVisitor(Element element) {
    // Can't use the () => message syntax because it allocates a closure.
    assert(() {
      if (contentLayersLog.isLoggable(Level.FINEST)) {
        contentLayersLog.finest("Finding dirty children for: $element");
      }
      return true;
    }());
    if (element.dirty) {
      assert(() {
        if (contentLayersLog.isLoggable(Level.FINEST)) {
          contentLayersLog.finest("Found a dirty child: $element");
        }
        return true;
      }());
      _isDirty = true;
      return;
    }
    element.visitChildren(_isSubtreeDirtyVisitor);
  }

  void _onContentBuildScheduled() {
    _temporarilyForgetLayers();
  }

  @override
  void markNeedsBuild() {
    contentLayersLog.finer("ContentLayersElement - marking needs build");
    super.markNeedsBuild();
  }

  void buildLayers() {
    contentLayersLog.finer("ContentLayersElement - (re)building layers");

    owner!.buildScope(this, () {
      _buildLayersWithExistingScope();
    });
  }

  /// Builds the underlays and overlays without establishing a new build scope.
  ///
  /// We build the layers in two situations:
  ///
  /// 1. When the content's layout is dirty. This happens during layout phase, when we need to
  ///    establish a build scope. This is done when [buildLayers] is called.
  /// 2. When the content's layout is clean. This happens when [update] is called, but only
  ///    non-layout changes happened, like changing a color. In this case, we are already
  ///    inside a build scope, so we can't try to establish a new one.
  ///
  /// See [BuildOwner.buildScope] for more information.
  void _buildLayersWithExistingScope() {
    final List<Element> underlays = List<Element>.filled(widget.underlays.length, _NullElement.instance);
    for (int i = 0; i < underlays.length; i += 1) {
      late final Element child;
      if (i > _underlays.length - 1) {
        child = inflateWidget(widget.underlays[i](this), _UnderlaySlot(i));
      } else {
        child = super.updateChild(_underlays[i], widget.underlays[i](this), _UnderlaySlot(i))!;
      }
      underlays[i] = child;
    }
    _underlays = underlays;

    final List<Element> overlays = List<Element>.filled(widget.overlays.length, _NullElement.instance);
    for (int i = 0; i < overlays.length; i += 1) {
      late final Element child;
      if (i > _overlays.length - 1) {
        child = inflateWidget(widget.overlays[i](this), _OverlaySlot(i));
      } else {
        child = super.updateChild(_overlays[i], widget.overlays[i](this), _OverlaySlot(i))!;
      }
      overlays[i] = child;
    }
    _overlays = overlays;
  }

  @override
  Element inflateWidget(Widget newWidget, Object? newSlot) {
    final Element newChild = super.inflateWidget(newWidget, newSlot);

    assert(_debugCheckHasAssociatedRenderObject(newChild));

    return newChild;
  }

  /// Forgets the overlay and underlay children so that they don't run build at a
  /// problematic time, but the same layers can be brought back later, with retained
  /// `Element` and `State` objects.
  ///
  /// Note: If the layers are deactivated, rather than forgotten, new `Element`s and
  /// `State`s will be created on every build, which prevents layer `State` objects
  /// from retaining information across builds, thus defeating the purpose of using
  /// a `StatefulWidget`.
  void _temporarilyForgetLayers() {
    contentLayersLog.finer("ContentLayersElement - temporarily forgetting layers");
    for (final underlay in _underlays) {
      // Calling super.forgetChild directly to avoid adding it to _forgottenChildren.
      // We're doing this to prevent the children from building, but not from
      // being enumerated in visitChildren, which would happen with this.forgetChild.
      super.forgetChild(underlay);
    }

    for (final overlay in _overlays) {
      // Calling super.forgetChild directly to avoid adding it to _forgottenChildren.
      // We're doing this to prevent the children from building, but not from
      // being enumerated in visitChildren, which would happen with this.forgetChild.
      super.forgetChild(overlay);
    }
  }

  @override
  void update(ContentLayers newWidget) {
    super.update(newWidget);

    final newContent = widget.content(_onContentBuildScheduled);

    assert(widget == newWidget);
    assert(!debugChildrenHaveDuplicateKeys(widget, [newContent]));

    _content = updateChild(_content, newContent, _contentSlot);

    if (!renderObject.contentNeedsLayout) {
      // Layout has already run. No layout bounds changed. There might be a
      // non-layout change that needs to be painted, e.g., change to theme brightness.
      // Re-build all layers, which is safe to do because no layout constraints changed.
      _buildLayersWithExistingScope();
    }
    // Else, dirty content layout will cause this whole widget to re-layout. The
    // layers will be re-built during that layout pass.

    // super.update() and updateChild() is where the framework reparents
    // forgotten children. Therefore, at this point, the framework is
    // done with the concept of forgotten children, so we clear our
    // local cache of them, too.
    _forgottenChildren.clear();
  }

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    if (newSlot != _contentSlot) {
      // Never update underlays or overlays because they MUST only build during
      // layout.
      return null;
    }

    return super.updateChild(child, newWidget, newSlot);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(slot != null);
    assert(_isContentLayersSlot(slot!), "Invalid ContentLayers slot: $slot");

    renderObject.insertChild(child, slot!);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(child.parent == renderObject);
    assert(oldSlot != null);
    assert(newSlot != null);
    assert(_isContentLayersSlot(oldSlot!), "Invalid ContentLayers slot: $oldSlot");
    assert(_isContentLayersSlot(newSlot!), "Invalid ContentLayers slot: $newSlot");

    // Can't move renderBox children to and from content slot (which is a sliver)
    if (oldSlot == _contentSlot || newSlot == _contentSlot) {
      assert(false);
    } else {
      renderObject.moveChildLayer(child as RenderBox, oldSlot!, newSlot!);
    }
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(child.parent == renderObject);
    assert(slot != null);
    assert(_isContentLayersSlot(slot!), "Invalid ContentLayers slot: $slot");

    renderObject.removeChild(child, slot!);
  }

  @override
  void forgetChild(Element child) {
    _forgottenChildren.add(child);
    super.forgetChild(child);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    // It is the responsibility of `visitChildren` to skip over forgotten children.
    if (_content != null && !_forgottenChildren.contains(_content)) {
      visitor(_content!);
    }

    // WARNING: Do not visit underlays or overlays when "locked". If you do, then the pipeline
    // owner will collect those children for rebuild, e.g., for hot reload, and the
    // pipeline owner will tell them to build before the content is laid out. We only
    // want the underlays and overlays to build during the layout phase, after the
    // content is laid out.

    // FIXME: locked is supposed to be private. We're using it as a proxy indication for when
    //        the build owner wants to build. Find an appropriate way to distinguish this.
    // ignore: invalid_use_of_protected_member
    if (!WidgetsBinding.instance.locked) {
      for (final Element child in _underlays) {
        if (!_forgottenChildren.contains(child)) {
          visitor(child);
        }
      }

      for (final Element child in _overlays) {
        if (!_forgottenChildren.contains(child)) {
          visitor(child);
        }
      }
    }
  }

  bool _debugCheckHasAssociatedRenderObject(Element newChild) {
    assert(() {
      if (newChild.renderObject == null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('The children of `ContentLayersElement` must each have an associated render object.'),
              ErrorHint(
                'This typically means that the `${newChild.widget}` or its children\n'
                'are not a subtype of `RenderObjectWidget`.',
              ),
              newChild.describeElement('The following element does not have an associated render object'),
              DiagnosticsDebugCreator(DebugCreator(newChild)),
            ]),
          ),
        );
      }
      return true;
    }());
    return true;
  }
}

/// `RenderObject` for a [ContentLayers] widget.
///
/// Must be associated with an `Element` of type [ContentLayersElement].
class RenderContentLayers extends RenderSliver with RenderSliverHelpers {
  RenderContentLayers(this._element);

  @override
  void dispose() {
    _element = null;
    super.dispose();
  }

  ContentLayersElement? _element;

  final _underlays = <RenderBox>[];
  RenderSliver? _content;
  final _overlays = <RenderBox>[];

  /// Whether this render object's layout information or its content
  /// layout information is dirty.
  ///
  /// This is set to `true` when `markNeedsLayout` is called and it's
  /// set to `false` after laying out the content.
  bool get contentNeedsLayout => _contentNeedsLayout;
  bool _contentNeedsLayout = true;

  /// Whether we are at the middle of a [performLayout] call.
  bool _runningLayout = false;

  @override
  void attach(PipelineOwner owner) {
    contentLayersLog.info("Attaching RenderContentLayers to owner: $owner");
    super.attach(owner);

    visitChildren((child) {
      child.attach(owner);
    });
  }

  @override
  void detach() {
    contentLayersLog.info("detach()'ing RenderContentLayers from pipeline");
    // IMPORTANT: we must detach ourselves before detaching our children.
    // This is a Flutter framework requirement.
    super.detach();

    // Detach our children.
    visitChildren((child) {
      child.detach();
    });
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();

    if (_runningLayout) {
      // We are already in a layout phase.
      // When we call ContentLayerElement.buildLayers, markNeedsLayout is called again.
      // We don't to mark the content as dirty, because otherwise the layers will never build.
      return;
    }
    _contentNeedsLayout = true;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final childDiagnostics = <DiagnosticsNode>[];

    if (_content != null) {
      childDiagnostics.add(_content!.toDiagnosticsNode(name: "content"));
    }

    for (int i = 0; i < _underlays.length; i += 1) {
      childDiagnostics.add(_underlays[i].toDiagnosticsNode(name: "underlay-$i"));
    }
    for (int i = 0; i < _overlays.length; i += 1) {
      childDiagnostics.add(_overlays[i].toDiagnosticsNode(name: "overlay-#$i"));
    }

    return childDiagnostics;
  }

  void insertChild(RenderObject child, Object slot) {
    assert(_isContentLayersSlot(slot));

    if (slot == _contentSlot) {
      _content = child as RenderSliver;
    } else if (slot is _UnderlaySlot) {
      _underlays.insert(slot.index, child as RenderBox);
    } else if (slot is _OverlaySlot) {
      _overlays.insert(slot.index, child as RenderBox);
    }

    adoptChild(child);
  }

  void moveChildLayer(RenderBox child, Object oldSlot, Object newSlot) {
    assert(oldSlot is _UnderlaySlot || oldSlot is _OverlaySlot);
    assert(newSlot is _UnderlaySlot || newSlot is _OverlaySlot);

    if (oldSlot is _UnderlaySlot) {
      assert(_underlays.contains(child));
      _underlays.remove(child);
    } else if (oldSlot is _OverlaySlot) {
      assert(_overlays.contains(child));
      _overlays.remove(child);
    }

    if (newSlot is _UnderlaySlot) {
      _underlays.insert(newSlot.index, child);
    } else if (newSlot is _OverlaySlot) {
      _overlays.insert(newSlot.index, child);
    }
  }

  void removeChild(RenderObject child, Object slot) {
    assert(_isContentLayersSlot(slot));

    if (slot == _contentSlot) {
      _content = null;
    } else if (slot is _UnderlaySlot) {
      _underlays.remove(child);
    } else if (slot is _OverlaySlot) {
      _overlays.remove(child);
    }

    dropChild(child);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_content != null) {
      visitor(_content!);
    }

    for (final RenderBox child in _underlays) {
      visitor(child);
    }

    for (final RenderBox child in _overlays) {
      visitor(child);
    }
  }

  @override
  void performLayout() {
    contentLayersLog.info("Laying out ContentLayers");
    if (_content == null) {
      geometry = SliverGeometry.zero;
      _contentNeedsLayout = false;
      return;
    }

    _runningLayout = true;

    // Always layout the content first, so that layers can inspect the content layout.
    contentLayersLog.fine("Laying out content - $_content");
    (_content!.parentData! as SliverLogicalParentData).layoutOffset = 0.0;
    _content!.layout(constraints, parentUsesSize: true);
    contentLayersLog.fine("Content after layout: $_content");

    // The size of the layers, and the our size, is exactly the same as the content.
    final SliverGeometry sliverLayoutGeometry = _content!.geometry!;
    if (sliverLayoutGeometry.scrollOffsetCorrection != null) {
      geometry = SliverGeometry(
        scrollOffsetCorrection: sliverLayoutGeometry.scrollOffsetCorrection,
      );
      return;
    }
    geometry = SliverGeometry(
      scrollExtent: sliverLayoutGeometry.scrollExtent,
      paintExtent: sliverLayoutGeometry.paintExtent,
      maxPaintExtent: sliverLayoutGeometry.maxPaintExtent,
      maxScrollObstructionExtent: sliverLayoutGeometry.maxScrollObstructionExtent,
      cacheExtent: sliverLayoutGeometry.cacheExtent,
      hasVisualOverflow: sliverLayoutGeometry.hasVisualOverflow,
    );

    _contentNeedsLayout = false;

    // Build the underlay and overlays during the layout phase so that they can inspect an
    // up-to-date content layout.
    //
    // This behavior is what allows us to avoid layers that are always one frame behind the
    // content changes.
    contentLayersLog.fine("Building layers");
    invokeLayoutCallback((constraints) {
      _element!.buildLayers();
    });
    contentLayersLog.finer("Done building layers");

    contentLayersLog.fine("Laying out layers (${_underlays.length} underlays, ${_overlays.length} overlays)");
    // Layout the layers below and above the content.
    final layerConstraints = ScrollingBoxConstraints(
      minWidth: constraints.crossAxisExtent,
      maxWidth: constraints.crossAxisExtent,
      minHeight: sliverLayoutGeometry.scrollExtent,
      maxHeight: sliverLayoutGeometry.scrollExtent,
      scrollOffset: constraints.scrollOffset,
    );

    for (final underlay in _underlays) {
      final childParentData = underlay.parentData! as SliverLogicalParentData;
      childParentData.layoutOffset = -constraints.scrollOffset;
      contentLayersLog.fine("Laying out underlay: $underlay");
      underlay.layout(layerConstraints);
    }
    for (final overlay in _overlays) {
      final childParentData = overlay.parentData! as SliverLogicalParentData;
      childParentData.layoutOffset = -constraints.scrollOffset;
      contentLayersLog.fine("Laying out overlay: $overlay");
      overlay.layout(layerConstraints);
    }

    _runningLayout = false;
    contentLayersLog.finer("Done laying out layers");
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (_content == null) {
      return false;
    }

    // Run hit tests in reverse-paint order.
    bool didHit = false;

    final boxResult = BoxHitTestResult.wrap(result);

    // First, hit-test overlays.
    for (final overlay in _overlays) {
      didHit =
          hitTestBoxChild(boxResult, overlay, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
      if (didHit) {
        return true;
      }
    }

    // Second, hit-test the content.
    didHit = _content!.hitTest(result, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
    if (didHit) {
      return true;
    }

    // Third, hit-test the underlays.
    for (final underlay in _underlays) {
      didHit = hitTestBoxChild(boxResult, underlay,
          mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
      if (didHit) {
        return true;
      }
    }

    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_content == null) {
      return;
    }

    void paintChild(RenderObject child) {
      final childParentData = child.parentData! as SliverLogicalParentData;
      context.paintChild(
        child,
        offset + Offset(0, childParentData.layoutOffset!),
      );
    }

    // First, paint the underlays.
    for (final underlay in _underlays) {
      paintChild(underlay);
    }

    // Second, paint the content.
    paintChild(_content!);

    // Third, paint the overlays.
    for (final overlay in _overlays) {
      paintChild(overlay);
    }
  }

  @override
  void applyPaintTransform(covariant RenderObject child, Matrix4 transform) {
    final childParentData = child.parentData! as SliverLogicalParentData;
    transform.translate(0.0, childParentData.layoutOffset!);
  }

  @override
  double childMainAxisPosition(covariant RenderObject child) {
    final childParentData = child.parentData! as SliverLogicalParentData;
    return childParentData.layoutOffset!;
  }

  @override
  void setupParentData(covariant RenderObject child) {
    child.parentData = _ChildParentData();
  }
}

bool _isContentLayersSlot(Object slot) => slot == _contentSlot || slot is _UnderlaySlot || slot is _OverlaySlot;

const _contentSlot = "content";

class _UnderlaySlot extends _IndexedSlot {
  const _UnderlaySlot(int index) : super(index);

  @override
  String toString() => "[$_UnderlaySlot] - underlay index: $index";
}

class _OverlaySlot extends _IndexedSlot {
  const _OverlaySlot(int index) : super(index);

  @override
  String toString() => "[$_OverlaySlot] - overlay index: $index";
}

class _IndexedSlot {
  const _IndexedSlot(this.index);

  final int index;
}

/// Used as a placeholder in [List<Element>] objects when the actual
/// elements are not yet determined.
///
/// Copied from the framework.
class _NullElement extends Element {
  _NullElement() : super(const _NullWidget());

  static _NullElement instance = _NullElement();

  @override
  bool get debugDoingBuild => throw UnimplementedError();
}

class _NullWidget extends Widget {
  const _NullWidget();

  @override
  Element createElement() => throw UnimplementedError();
}

/// A widget builder, which builds a [ContentLayerWidget].
typedef ContentLayerWidgetBuilder = ContentLayerWidget Function(BuildContext context);

/// A widget that can be displayed as a layer in a [ContentLayers] widget.
///
/// [ContentLayers] uses a special type of layer widget to avoid timing issues with
/// Flutter's build order. This timing issue is only a concern when a layer
/// widget inspects content layout within [ContentLayers]. However, to prevent
/// developer confusion and mistakes, all layer widgets are forced to be
/// [ContentLayerWidget]s.
///
/// Extend [ContentLayerStatefulWidget] to create a layer that's based on the
/// content layout within the ancestor [ContentLayers], and requires mutable state.
///
/// Extend [ContentLayerStatelessWidget] to create a layer that's based on the
/// content layout within the ancestor [ContentLayers], but doesn't require mutable
/// state.
///
/// To quickly and easily build a layer from a traditional widget tree, create a
/// [ContentLayerProxyWidget] with the desired subtree. This approach is a
/// quicker and more convenient alternative to [ContentLayerStatelessWidget]
/// for the simplest of layer trees.
abstract class ContentLayerWidget implements Widget {
  // Marker interface.
}

/// A [ContentLayerWidget] that displays nothing.
///
/// Useful when a layer should conditionally display content. An [EmptyContentLayer] can
/// be returned in cases where no visuals are desired.
class EmptyContentLayer extends ContentLayerStatelessWidget {
  const EmptyContentLayer({super.key});

  @override
  Widget doBuild(BuildContext context, Element? contentElement, RenderObject? contentLayout) {
    return const SizedBox();
  }
}

/// Widget that builds a [ContentLayers] layer based on a traditional widget
/// subtree, as represented by the given [child].
///
/// The [child] subtree must NOT access the content layout within [ContentLayers].
///
/// This widget is an escape hatch to easily display traditional widget subtrees
/// as content layers, when those layers don't care about the layout of the content.
class ContentLayerProxyWidget extends ContentLayerStatelessWidget {
  const ContentLayerProxyWidget({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget doBuild(BuildContext context, Element? contentElement, RenderObject? contentLayout) {
    return child;
  }
}

/// Widget that builds a stateless [ContentLayers] layer, which is given access
/// to the ancestor [ContentLayers] content [Element] and [RenderObject].
abstract class ContentLayerStatelessWidget extends StatelessWidget implements ContentLayerWidget {
  const ContentLayerStatelessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final contentLayers = (context as Element).findAncestorContentLayers();
    final contentElement = contentLayers?._content;
    final contentLayout = contentElement?.findRenderObject();

    return doBuild(context, contentElement, contentLayout);
  }

  @protected
  Widget doBuild(BuildContext context, Element? contentElement, RenderObject? contentLayout);
}

/// Widget that builds a stateful [ContentLayers] layer, which is given access
/// to the ancestor [ContentLayers] content [Element] and [RenderObject].
///
/// See [ContentLayerState] for information about why a special type of [StatefulWidget]
/// is required for use within [ContentLayers].
abstract class ContentLayerStatefulWidget<LayoutDataType> extends StatefulWidget implements ContentLayerWidget {
  const ContentLayerStatefulWidget({super.key});

  @override
  StatefulElement createElement() => ContentLayerStatefulElement(this);

  @override
  ContentLayerState<ContentLayerStatefulWidget, LayoutDataType> createState();
}

/// A [StatefulElement] that looks for an ancestor [ContentLayersElement] and marks
/// that element as needing to rebuild any time that this [ContentLayerStatefulElement]
/// needs to rebuild.
///
/// In effect, this [Element] connects its dirty state to an ancestor [ContentLayersElement].
class ContentLayerStatefulElement extends StatefulElement {
  ContentLayerStatefulElement(super.widget);

  bool _isActive = false;

  @override
  void activate() {
    super.activate();
    _isActive = true;
  }

  @override
  void deactivate() {
    _isActive = false;
    super.deactivate();
  }

  @override
  void markNeedsBuild() {
    if (_isActive && mounted) {
      // Our Element is attached to the tree. Mark our ancestor ContentLayers as
      // needing to build, too.
      //
      // Flutter blows up if we try to climb the Element tree when this Element
      // isn't active, because when this Element is deactivated, it's technically
      // detached from the tree until its reactivated or disposed.
      findAncestorContentLayers()?.markNeedsBuild();
    }

    super.markNeedsBuild();
  }
}

extension on Element {
  /// Finds and returns a [ContentLayersElement] by walking up the [Element] tree,
  /// beginning with this [Element].
  ContentLayersElement? findAncestorContentLayers() {
    ContentLayersElement? contentLayersElement;

    visitAncestorElements((element) {
      if (element is ContentLayersElement) {
        contentLayersElement = element;
        return false;
      }

      return true;
    });

    return contentLayersElement;
  }
}

/// A state object for a [ContentLayerStatefulWidget].
///
/// A [ContentLayerState] needs to be implemented a little bit differently than
/// a traditional [StatefulWidget]. Calling `setState()` will cause this widget
/// to rebuild, but the ancestor [ContentLayers] has no control over WHEN this
/// widget will rebuild. This widget might rebuild before the content layer can
/// run its layout. If this widget then attempts to query the content layout,
/// Flutter throws an exception.
///
/// To work around the rebuild timing issues, a [ContentLayerState] separates
/// layout inspection from the build process. A [ContentLayerState] should
/// collect all the layout information it needs in [computeLayoutData] and then
/// it should build its subtree in [doBuild].
///
/// A [ContentLayerState] should NOT implement [build] - that implementation is
/// handled on your behalf, and it coordinates between [computeLayoutData] and
/// [doBuild].
abstract class ContentLayerState<WidgetType extends ContentLayerStatefulWidget, LayoutDataType>
    extends State<WidgetType> {
  @protected
  LayoutDataType? get layoutData => _layoutData;
  LayoutDataType? _layoutData;

  /// Traditional build method for this widget - this method should not be overridden
  /// in subclasses.
  @override
  Widget build(BuildContext context) {
    final contentLayers = (context as Element).findAncestorContentLayers();
    final contentElement = contentLayers?._content;
    final contentLayout = contentElement?.findRenderObject();

    if (contentLayers != null && !contentLayers.renderObject.contentNeedsLayout) {
      _layoutData = computeLayoutData(contentElement, contentLayout);
    }

    return doBuild(context, _layoutData);
  }

  /// Computes and returns cached layout data, derived from the content layer's [Element]
  /// and [RenderObject].
  ///
  /// Subclasses can choose what action to take when the [contentElement] or [contentLayout]
  /// are `null`, and therefore unavailable.
  LayoutDataType? computeLayoutData(Element? contentElement, RenderObject? contentLayout);

  /// Composes and returns the subtree for this widget.
  ///
  /// This method should be treated as the replacement for the traditional [build] method.
  ///
  /// [doBuild] is provided with the latest available layout data, which was computed
  /// by [computeLayoutData].
  @protected
  Widget doBuild(BuildContext context, LayoutDataType? layoutData);
}

class _ChildParentData extends SliverLogicalParentData with ContainerParentDataMixin<RenderObject> {}
