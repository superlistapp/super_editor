import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_text/src/text_layout.dart';
import 'package:super_text/super_text_logging.dart';

import 'super_text.dart';

class SuperText extends RenderObjectWidget with SlottedMultiChildRenderObjectWidgetMixin<String> {
  const SuperText({
    Key? key,
    required this.richText,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.layerBeneathBuilder,
    this.layerAboveBuilder,
  }) : super(key: key);

  /// The text to display in this [SuperText] widget.
  final InlineSpan richText;

  /// The alignment to use for [richText] display.
  final TextAlign textAlign;

  /// The text direction to use for [richText] display.
  final TextDirection textDirection;

  /// Builds a widget that appears beneath the text, e.g., to render text
  /// selection boxes.
  final SuperDuperTextLayoutLayer? layerBeneathBuilder;

  /// Builds a widget that appears above the text, e.g., to render a caret.
  final SuperDuperTextLayoutLayer? layerAboveBuilder;

  @override
  SlottedRenderObjectElement<String> createElement() {
    final element = super.createElement();
    print("Creating SuperDuperText element: ${element.runtimeType}");
    return element;
  }

  @override
  SlottedContainerRenderObjectMixin<String> createRenderObject(BuildContext context) {
    return RenderSuperText();
  }

  @override
  Iterable<String> get slots => const [_childText, _childBeneath, _childAbove];

  @override
  Widget? childForSlot(slot) {
    if (slot == _childText) {
      return _ParentInvalidatingRichText(
        text: richText,
        textDirection: textDirection,
        textAlign: textAlign,
      );
    }
    if (slot == _childBeneath) {
      return layerBeneathBuilder;
    }
    if (slot == _childAbove) {
      return layerAboveBuilder;
    }

    errorsLog.warning("SuperText doesn't have a child called: $slot");

    return null;
  }
}

const _childText = "text";
const _childBeneath = "beneath";
const _childAbove = "above";

class RenderSuperText extends RenderBox with SlottedContainerRenderObjectMixin<String> {
  static ProseTextLayout? textLayoutFrom(GlobalKey key) =>
      (key.currentContext?.findRenderObject() as RenderSuperText).textLayout;

  RenderSuperText();

  ProseTextLayout? get textLayout => _textLayout;
  ProseTextLayout? _textLayout;

  RenderParagraph get _renderParagraph => childForSlot(_childText) as RenderParagraph;

  _RenderSuperDuperTextLayerBuilder? get _layerAbove => childForSlot(_childAbove) as _RenderSuperDuperTextLayerBuilder?;
  _RenderSuperDuperTextLayerBuilder? get _layerBeneath =>
      childForSlot(_childBeneath) as _RenderSuperDuperTextLayerBuilder?;

  @override
  Iterable<RenderBox> get children {
    final children = <RenderBox>[];

    final layerAbove = childForSlot(_childAbove);
    if (layerAbove != null) {
      children.add(layerAbove);
    }

    final text = childForSlot(_childText);
    if (text != null) {
      children.add(text);
    }

    final layerBeneath = childForSlot(_childBeneath);
    if (layerBeneath != null) {
      children.add(layerBeneath);
    }

    return children;
  }

  @override
  void performLayout() {
    print("Laying out SuperDuperText: $this");
    print("Children: $children");

    _textLayout = _layoutText();
    _layoutLayerBeneath(_textLayout!);
    _layoutLayerAbove(_textLayout!);

    print("Done laying out SuperDuperText");
  }

  ProseTextLayout _layoutText() {
    _renderParagraph.layout(constraints, parentUsesSize: true);
    print("Done laying out RenderParagraph: $_renderParagraph");

    size = _renderParagraph.size;

    return RenderParagraphProseTextLayout(
      richText: _renderParagraph.text,
      renderParagraph: _renderParagraph,
    );
  }

  void _layoutLayerBeneath(ProseTextLayout textLayout) {
    if (_layerBeneath != null) {
      print("Laying out layer beneath: $_layerBeneath");
      print("Status of render paragraph: $_renderParagraph");
    }

    _layerBeneath
      ?..textLayout = textLayout
      ..layout(BoxConstraints.tight(size));
  }

  void _layoutLayerAbove(ProseTextLayout textLayout) {
    if (_layerAbove != null) {
      print("Laying out layer above: $_layerAbove");
      print("Status of render paragraph: $_renderParagraph");
    }

    _layerAbove
      ?..textLayout = textLayout
      ..layout(BoxConstraints.tight(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    print("Painting SuperDuperText...");
    print("Painting layer beneath");
    _layerBeneath?.paint(context, offset);

    print("Painting render paragraph");
    _renderParagraph.paint(context, offset);

    print("Painting layer above");
    _layerAbove?.paint(context, offset);
  }
}

class _ParentInvalidatingRichText extends RichText {
  _ParentInvalidatingRichText({
    Key? key,
    required InlineSpan text,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    double textScaleFactor = 1.0,
    int? maxLines,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    TextHeightBehavior? textHeightBehavior,
  }) : super(
          key: key,
          text: text,
          textAlign: textAlign,
          textDirection: textDirection,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          locale: locale,
          strutStyle: strutStyle,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
        );

  @override
  RenderParagraph createRenderObject(BuildContext context) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    return _ParentInvalidatingRenderParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale ?? Localizations.maybeLocaleOf(context),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: TextAlign.start));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(FlagProperty('softWrap',
        value: softWrap,
        ifTrue: 'wrapping at box width',
        ifFalse: 'no wrapping except at line break characters',
        showName: true));
    properties.add(EnumProperty<TextOverflow>('overflow', overflow, defaultValue: TextOverflow.clip));
    properties.add(DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: 1.0));
    properties.add(IntProperty('maxLines', maxLines, ifNull: 'unlimited'));
    properties.add(EnumProperty<TextWidthBasis>('textWidthBasis', textWidthBasis, defaultValue: TextWidthBasis.parent));
    properties.add(StringProperty('text', text.toPlainText()));
    properties.add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null));
    properties.add(DiagnosticsProperty<StrutStyle>('strutStyle', strutStyle, defaultValue: null));
    properties
        .add(DiagnosticsProperty<TextHeightBehavior>('textHeightBehavior', textHeightBehavior, defaultValue: null));
  }
}

class _ParentInvalidatingRenderParagraph extends RenderParagraph {
  _ParentInvalidatingRenderParagraph(
    InlineSpan text, {
    TextAlign textAlign = TextAlign.start,
    required TextDirection textDirection,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    double textScaleFactor = 1.0,
    int? maxLines,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    ui.TextHeightBehavior? textHeightBehavior,
    List<RenderBox>? children,
  }) : super(
          text,
          textAlign: textAlign,
          textDirection: textDirection,
          softWrap: softWrap,
          overflow: overflow,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          locale: locale,
          strutStyle: strutStyle,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          children: children,
        );

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    markParentNeedsLayout();
  }
}

class SuperDuperTextLayoutLayer extends RenderObjectWidget {
  const SuperDuperTextLayoutLayer({
    Key? key,
    required this.builder,
  }) : super(key: key);

  /// Called at layout time to construct the widget tree.
  final SuperTextLayerBuilder builder;

  @override
  RenderObjectElement createElement() => _SuperDuperTextLayerBuilderElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSuperDuperTextLayerBuilder();
}

class _SuperDuperTextLayerBuilderElement extends RenderObjectElement {
  _SuperDuperTextLayerBuilderElement(
    SuperDuperTextLayoutLayer widget,
  ) : super(widget);

  Element? _child;

  @override
  SuperDuperTextLayoutLayer get widget => super.widget as SuperDuperTextLayoutLayer;

  @override
  _RenderSuperDuperTextLayerBuilder get renderObject => super.renderObject as _RenderSuperDuperTextLayerBuilder;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot); // Creates the renderObject.
    renderObject.updateCallback(_layout);
  }

  @override
  void update(SuperDuperTextLayoutLayer newWidget) {
    assert(widget != newWidget);
    super.update(newWidget);
    assert(widget == newWidget);

    renderObject.updateCallback(_layout);
    // Force the callback to be called, even if the layout constraints are the
    // same, because the logic in the callback might have changed.
    renderObject.markNeedsBuild();
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void performRebuild() {
    // This gets called if markNeedsBuild() is called on us.
    // That might happen if, e.g., our builder uses Inherited widgets.

    // Force the callback to be called, even if the layout constraints are the
    // same. This is because that callback may depend on the updated widget
    // configuration, or an inherited widget.
    renderObject.markNeedsBuild();
    super.performRebuild(); // Calls widget.updateRenderObject (a no-op in this case).
  }

  @override
  void unmount() {
    renderObject.updateCallback(null);
    super.unmount();
  }

  void _layout(TextLayout textLayout) {
    @pragma('vm:notify-debugger-on-exception')
    void layoutCallback() {
      Widget built;
      try {
        built = widget.builder(this, textLayout);
        debugWidgetBuilderValue(widget, built);
      } catch (e, stack) {
        built = ErrorWidget.builder(
          _debugReportException(
            ErrorDescription('building $widget'),
            e,
            stack,
            informationCollector: () => <DiagnosticsNode>[
              if (kDebugMode) DiagnosticsDebugCreator(DebugCreator(this)),
            ],
          ),
        );
      }
      try {
        _child = updateChild(_child, built, null);
        assert(_child != null);
      } catch (e, stack) {
        built = ErrorWidget.builder(
          _debugReportException(
            ErrorDescription('building $widget'),
            e,
            stack,
            informationCollector: () => <DiagnosticsNode>[
              if (kDebugMode) DiagnosticsDebugCreator(DebugCreator(this)),
            ],
          ),
        );
        _child = updateChild(null, built, slot);
      }
    }

    owner!.buildScope(this, layoutCallback);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    final RenderObjectWithChildMixin<RenderObject> renderObject = this.renderObject;
    assert(slot == null);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
    assert(renderObject == this.renderObject);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    final _RenderSuperDuperTextLayerBuilder renderObject = this.renderObject;
    assert(renderObject.child == child);
    renderObject.child = null;
    assert(renderObject == this.renderObject);
  }
}

class _RenderSuperDuperTextLayerBuilder extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  set textLayout(TextLayout? textLayout) {
    _textLayout = textLayout;
    _needsBuild = true;
    // Note: we can't call markNeedsLayout() here because the TextLayout
    // is probably set by our parent's layout() method. You can't call
    // markNeedsLayout() from within a layout() pass. Instead we use special
    // behavior in rebuildIfNecessary() to rebuild our subtree during our layout.
  }

  TextLayout? _textLayout;

  //---- Start from RenderConstrainedLayoutBuilder ----
  void Function(TextLayout)? _callback;

  /// Change the layout callback.
  void updateCallback(void Function(TextLayout)? value) {
    if (value == _callback) {
      return;
    }
    _callback = value;
    _needsBuild = true;
    markNeedsLayout();
  }

  bool _needsBuild = true;

  /// Marks this layout builder as needing to rebuild.
  ///
  /// The layout build rebuilds automatically when the TextLayout changes.
  /// However, we must also rebuild when the widget updates, e.g. after
  /// [State.setState], or [State.didChangeDependencies], even when the layout
  /// constraints remain unchanged.
  ///
  /// See also:
  ///
  ///  * [SuperDuperTextLayoutLayer.builder], which is called during the rebuild.
  void markNeedsBuild() {
    // Do not call the callback directly. It must be called during the layout
    // phase, when the TextLayout is available. Calling `markNeedsLayout`
    // will cause it to be called at the right time.
    _needsBuild = true;
    markNeedsLayout();
  }

  /// Invoke the callback supplied via [updateCallback].
  ///
  /// Typically this results in [SuperDuperTextLayoutLayer.builder] being called
  /// during layout.
  void rebuildIfNecessary() {
    assert(_callback != null);
    // Unlike LayoutBuilder, we always rebuild our subtree, because the fact
    // that this method is called, means that we're running layout(). If we're
    // running layout() then the TextLayout may have (and probably) changed.

    if (_needsBuild) {
      _needsBuild = false;
      invokeLayoutCallback((constraints) {
        if (_textLayout == null) {
          return;
        }

        _callback?.call(_textLayout!);
      });
    }
  }
  //---- End from RenderConstrainedLayoutBuilder ----

  //---- Start from RenderLayoutBuilder ---
  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(
      reason: 'Calculating the dry layout would require running the layout callback '
          'speculatively, which might mutate the live render object tree.',
    ));
    return Size.zero;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    rebuildIfNecessary();
    if (child != null) {
      child!.layout(constraints);
    }

    size = constraints.biggest;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (child != null) {
      return child!.getDistanceToActualBaseline(baseline);
    }
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    print("Painting layer: $this");
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }

  bool _debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw FlutterError(
          '_SuperTextLayoutBuilder does not support returning intrinsic dimensions.\n'
          'Calculating the intrinsic dimensions would require running the layout '
          'callback speculatively, which might mutate the live render object tree.',
        );
      }
      return true;
    }());

    return true;
  }
  //---- End from RenderLayoutBuilder ---
}

FlutterErrorDetails _debugReportException(
  DiagnosticsNode context,
  Object exception,
  StackTrace stack, {
  InformationCollector? informationCollector,
}) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stack,
    library: 'super_text',
    context: context,
    informationCollector: informationCollector,
  );
  FlutterError.reportError(details);
  return details;
}
