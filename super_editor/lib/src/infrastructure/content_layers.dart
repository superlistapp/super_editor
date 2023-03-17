import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Widget that displays [content] above a number of [underlays], and beneath a number of
/// [overlays], sizing those layers to be exactly the same size as the [content], and
/// building those layers after [content] is laid out, so that the layers can inspect the
/// [content].
class ContentLayers extends RenderObjectWidget {
  const ContentLayers({
    this.underlays = const [],
    required this.content,
    this.overlays = const [],
  });

  final List<Widget> underlays;
  final Widget content;
  final List<Widget> overlays;

  @override
  RenderObjectElement createElement() {
    // print("ContentLayers - createElement()");
    return ContentLayersElement(this);
  }

  @override
  RenderContentLayers createRenderObject(BuildContext context) {
    // print("ContentLayers - createRenderObject()");
    return RenderContentLayers(context as ContentLayersElement);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    // print("ContentLayers - updateRenderObject");
  }

  @override
  void didUnmountRenderObject(RenderObject renderObject) {
    // print("ContentLayers - didUnmountRenderObject");
    super.didUnmountRenderObject(renderObject);
  }
}

// For reference to similar framework implementations:
// MultiChildRenderObjectElement
// ContainerRenderObjectMixin

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
    super.mount(parent, newSlot);

    _content = inflateWidget(widget.content, _contentSlot);
  }

  @override
  void deactivate() {
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

  void buildLayers() {
    print("Building layers in ContentLayersElement");
    // FIXME: To get the layers to rebuild, we have to deactivate the existing layer Element and re-inflate
    //        the layer's widget. This probably creates a lot of extra work for layers that don't
    //        need to be rebuilt. Create a way for layers to opt-in to this behavior.

    owner!.buildScope(this, () {
      for (final underlay in _underlays) {
        print("Deactivating underlay: $underlay");
        deactivateChild(underlay);
      }
      final List<Element> underlays = List<Element>.filled(widget.underlays.length, _NullElement.instance);
      for (int i = 0; i < underlays.length; i += 1) {
        final Element newChild = inflateWidget(widget.underlays[i], _UnderlaySlot(i));
        underlays[i] = newChild;
      }
      _underlays = underlays;

      for (final overlay in _overlays) {
        print("Deactivating overlay: $overlay");
        deactivateChild(overlay);
      }
      final List<Element> overlays = List<Element>.filled(widget.overlays.length, _NullElement.instance);
      for (int i = 0; i < overlays.length; i += 1) {
        final Element newChild = inflateWidget(widget.overlays[i], _OverlaySlot(i));
        overlays[i] = newChild;
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

  @override
  void update(ContentLayers newWidget) {
    // print("update() - new widget: $newWidget");
    super.update(newWidget);

    assert(widget == newWidget);
    assert(!debugChildrenHaveDuplicateKeys(widget, [widget.content]));
    assert(!debugChildrenHaveDuplicateKeys(widget, widget.underlays));
    assert(!debugChildrenHaveDuplicateKeys(widget, widget.overlays));

    _content = updateChild(_content, widget.content, _contentSlot);
    // _underlays = updateChildren(_underlays, widget.underlays,
    //     slots: List.generate(widget.underlays.length, (index) => _UnderlaySlot(index)));
    // _overlays = updateChildren(_overlays, widget.overlays,
    //     slots: List.generate(widget.overlays.length, (index) => _OverlaySlot(index)));
  }

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    // print("updateChild - element: $child, widget: $newWidget, slot: $newSlot");
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
    print("Remove RenderObject child from element: $slot -> $child");
    assert(child is RenderBox);
    assert(child.parent == renderObject);
    assert(slot != null);
    assert(_isContentLayersSlot(slot!), "Invalid ContentLayers slot: $slot");

    renderObject.removeChild(child as RenderBox, slot!);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    // print(
    //     "ContentLayersElement - visitChildren() - pipeline phase: ${WidgetsBinding.instance.schedulerPhase}, is locked: ${WidgetsBinding.instance.locked}");
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
    if (!WidgetsBinding.instance.locked) {
      for (final Element child in _underlays) {
        // print("Visiting underlay: $child");
        visitor(child);
      }

      for (final Element child in _overlays) {
        // print("Visiting overlay: $child");
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
    // print("Attaching RenderContentLayers to owner: $owner");
    super.attach(owner);

    visitChildren((child) {
      child.attach(owner);
    });
  }

  @override
  void detach() {
    // print("detach()'ing RenderContentLayers from pipeline");
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
    // print("Inserting $slot - $child");
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
    print("Removing $slot - $child");
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
    // print(
    //     "RenderContentLayers visitChildren() - pipeline phase: ${WidgetsBinding.instance.schedulerPhase}, is locked: ${WidgetsBinding.instance.locked}");
    // print(" ^ visitor: $visitor");

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
    if (_content == null) {
      size = Size.zero;
      return;
    }

    // Always layout the content first, so that layers can inspect the content layout.
    _content!.layout(constraints, parentUsesSize: true);
    // print("Content after layout: $_content");

    // The size of the layers, and the our size, is exactly the same as the content.
    size = _content!.size;

    // Build the underlay and overlays during the layout phase so that they can inspect an
    // up-to-date content layout.
    //
    // This behavior is what allows us to avoid layers that are always one frame behind the
    // content changes.
    invokeLayoutCallback((constraints) {
      // print("Building layers");
      _element!.buildLayers();
    });

    // print("Laying out ContentLayers with ${_underlays.length} underlays and ${_overlays.length} overlays");
    // for (final overlay in _overlays) {
    //   print(" - overlay: $overlay");
    // }

    // Layout the layers below and above the content.
    final layerConstraints = BoxConstraints.tight(size);

    // print("Laying out underlays");
    for (final underlay in _underlays) {
      underlay.layout(layerConstraints);
    }
    // print("Laying out overlays");
    for (final overlay in _overlays) {
      overlay.layout(layerConstraints);
    }
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
        // print("Hit overlay: $overlay");
        return true;
      }
    }

    // Second, hit-test the content.
    didHit = _content!.hitTest(result, position: position);
    if (didHit) {
      // print("Hit content");
      return true;
    }

    // Third, hit-test the underlays.
    for (final underlay in _underlays) {
      didHit = underlay.hitTest(result, position: position) || didHit;
      if (didHit) {
        // print("Hit underlay: $underlay");
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

    // print("Painting ContentLayers with ${_underlays.length} underlays and ${_overlays.length} overlays");

    // First, paint the underlays.
    // print("Painting underlays");
    for (final underlay in _underlays) {
      context.paintChild(underlay, offset);
    }

    // Second, paint the content.
    // print("Painting content");
    context.paintChild(_content!, offset);

    // Third, paint the overlays.
    // print("Painting overlays");
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
