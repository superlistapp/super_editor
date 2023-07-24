import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

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
  final List<WidgetBuilder> underlays;

  /// The primary content displayed in this widget, which determines the size and location
  /// of all [underlays] and [overlays].
  final Widget Function(VoidCallback onBuildScheduled) content;

  /// Layers displayed above the [content].
  ///
  /// These layers are placed at the same (x,y) as [content], and they're forced to layout
  /// at the exact same size as [content].
  ///
  /// {@macro layers_as_builders}
  final List<WidgetBuilder> overlays;

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
  ContentLayersElement(RenderObjectWidget widget) : super(widget);

  List<Element> _underlays = <Element>[];
  Element? _content;
  List<Element> _overlays = <Element>[];

  @override
  ContentLayers get widget => super.widget as ContentLayers;

  @override
  RenderContentLayers get renderObject => super.renderObject as RenderContentLayers;

  @override
  void mount(Element? parent, Object? newSlot) {
    contentLayersLog.fine("ContentLayersElement - mounting");
    super.mount(parent, newSlot);

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
    super.unmount();
  }

  void _onContentBuildScheduled() {
    _deactivateLayers();
  }

  void checkContent() {
    contentLayersLog.finer("ContentLayersElement - checkContent(). Is content dirty? ${_content?.dirty}");
  }

  @override
  void markNeedsBuild() {
    contentLayersLog.finer("ContentLayersElement - marking needs build");
    // Deactivate the layers whenever we rebuild, to make sure that the layers don't run
    // their build methods before `RenderContentLayers` runs layout.
    _deactivateLayers();
    super.markNeedsBuild();
  }

  void buildLayers() {
    contentLayersLog.finer("ContentLayersElement - (re)building layers");

    owner!.buildScope(this, () {
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
    });
  }

  @override
  Element inflateWidget(Widget newWidget, Object? newSlot) {
    final Element newChild = super.inflateWidget(newWidget, newSlot);

    assert(_debugCheckHasAssociatedRenderObject(newChild));

    return newChild;
  }

  void _deactivateLayers() {
    contentLayersLog.finer("ContentLayersElement - deactivating layers");
    for (final underlay in _underlays) {
      deactivateChild(underlay);
    }
    _underlays = [];

    for (final overlay in _overlays) {
      deactivateChild(overlay);
    }
    _overlays = [];
  }

  @override
  void update(ContentLayers newWidget) {
    super.update(newWidget);

    final newContent = widget.content(_onContentBuildScheduled);

    assert(widget == newWidget);
    assert(!debugChildrenHaveDuplicateKeys(widget, [newContent]));

    _content = updateChild(_content, newContent, _contentSlot);
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
    assert(child is RenderBox);
    assert(slot != null);
    assert(_isContentLayersSlot(slot!), "Invalid ContentLayers slot: $slot");

    renderObject.insertChild(child as RenderBox, slot!);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(child is RenderBox);
    assert(child.parent == renderObject);
    assert(oldSlot != null);
    assert(newSlot != null);
    assert(_isContentLayersSlot(oldSlot!), "Invalid ContentLayers slot: $oldSlot");
    assert(_isContentLayersSlot(newSlot!), "Invalid ContentLayers slot: $newSlot");

    if (oldSlot == _contentSlot) {
      renderObject.moveChildContentToLayer(child as RenderBox, newSlot!);
    } else if (newSlot == _contentSlot) {
      renderObject.moveChildFromLayerToContent(child as RenderBox, oldSlot!);
    } else {
      renderObject.moveChildLayer(child as RenderBox, oldSlot!, newSlot!);
    }
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(child is RenderBox);
    assert(child.parent == renderObject);
    assert(slot != null);
    assert(_isContentLayersSlot(slot!), "Invalid ContentLayers slot: $slot");

    renderObject.removeChild(child as RenderBox, slot!);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_content != null) {
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
        visitor(child);
      }

      for (final Element child in _overlays) {
        visitor(child);
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
class RenderContentLayers extends RenderBox {
  RenderContentLayers(this._element);

  @override
  void dispose() {
    _element = null;
    super.dispose();
  }

  ContentLayersElement? _element;

  final _underlays = <RenderBox>[];
  RenderBox? _content;
  final _overlays = <RenderBox>[];

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

  void insertChild(RenderBox child, Object slot) {
    assert(_isContentLayersSlot(slot));

    if (slot == _contentSlot) {
      _content = child;
    } else if (slot is _UnderlaySlot) {
      _underlays.insert(slot.index, child);
    } else if (slot is _OverlaySlot) {
      _overlays.insert(slot.index, child);
    }

    adoptChild(child);
  }

  void moveChildContentToLayer(RenderBox child, Object newSlot) {
    assert(newSlot is _UnderlaySlot || newSlot is _OverlaySlot);

    _content = null;

    if (newSlot is _UnderlaySlot) {
      _underlays.insert(newSlot.index, child);
    } else if (newSlot is _OverlaySlot) {
      _overlays.insert(newSlot.index, child);
    }
  }

  void moveChildFromLayerToContent(RenderBox child, Object oldSlot) {
    assert(oldSlot is _UnderlaySlot || oldSlot is _OverlaySlot);

    if (oldSlot is _UnderlaySlot) {
      assert(_underlays.contains(child));
      _underlays.remove(child);
    } else if (oldSlot is _OverlaySlot) {
      assert(_overlays.contains(child));
      _overlays.remove(child);
    }

    _content = child;
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

  void removeChild(RenderBox child, Object slot) {
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
  Size computeDryLayout(BoxConstraints constraints) => _content?.computeDryLayout(constraints) ?? Size.zero;

  @override
  void performLayout() {
    contentLayersLog.info("Laying out ContentLayers");
    if (_content == null) {
      size = Size.zero;
      return;
    }

    // Always layout the content first, so that layers can inspect the content layout.
    contentLayersLog.fine("Laying out content - $_content");
    _content!.layout(constraints, parentUsesSize: true);

    // The size of the layers, and the our size, is exactly the same as the content.
    size = _content!.size;

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

    contentLayersLog.fine("Laying out layers (${_underlays.length} underlays, ${_overlays.length} overlays");
    // Layout the layers below and above the content.
    final layerConstraints = BoxConstraints.tight(size);

    for (final underlay in _underlays) {
      underlay.layout(layerConstraints);
    }
    for (final overlay in _overlays) {
      overlay.layout(layerConstraints);
    }
    contentLayersLog.finer("Done laying out layers");
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_content == null) {
      return false;
    }

    // Run hit tests in reverse-paint order.
    bool didHit = false;

    // First, hit-test overlays.
    for (final overlay in _overlays) {
      didHit = overlay.hitTest(result, position: position);
      if (didHit) {
        return true;
      }
    }

    // Second, hit-test the content.
    didHit = _content!.hitTest(result, position: position);
    if (didHit) {
      return true;
    }

    // Third, hit-test the underlays.
    for (final underlay in _underlays) {
      didHit = underlay.hitTest(result, position: position) || didHit;
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

    // First, paint the underlays.
    for (final underlay in _underlays) {
      context.paintChild(underlay, offset);
    }

    // Second, paint the content.
    context.paintChild(_content!, offset);

    // Third, paint the overlays.
    for (final overlay in _overlays) {
      context.paintChild(overlay, offset);
    }
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
