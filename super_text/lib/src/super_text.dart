import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'text_layout.dart';

/// Displays text with a visual layer above the text, and a visual layer
/// beneath the text, which can be used to add text decorations, like
/// selections and carets.
///
/// To display a widget that includes standard text selection display, as well
/// as typical selection gestures, see [SuperSelectableText].
///
/// The layers in a [SuperText] are built by provided [SuperTextLayerBuilder]s.
/// These builders are similar to a typical `WidgetBuilder`, except that
/// [SuperTextLayerBuilder]s are also given a reference to the [TextLayout]
/// within this [SuperText]. The layer builders can then use the [TextLayout] to
/// position widgets and paint coordinates near lines and characters in the text.
///
/// If you discover performance issues with your [SuperText], consider wrapping
/// the [SuperTextLayerBuilder] content with [RepaintBoundary]s, which might prevent
/// unnecessary repaints between your layers and the text content.
class SuperText extends StatefulWidget {
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
  final SuperTextLayerBuilder? layerBeneathBuilder;

  /// Builds a widget that appears above the text, e.g., to render a caret.
  final SuperTextLayerBuilder? layerAboveBuilder;

  @override
  State<SuperText> createState() => _SuperTextState();
}

class _SuperTextState extends State<SuperText> {
  RenderLayoutAwareParagraph? _paragraph;

  void _invalidateParagraph() => _paragraph = null;

  @override
  Widget build(BuildContext context) {
    return _SuperTextLayout(
      state: this,
      text: _LayoutAwareRichText(
        text: widget.richText,
        onMarkNeedsLayout: _invalidateParagraph,
      ),
      background: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final background = widget.layerBeneathBuilder;
          if (background != null && _paragraph != null) {
            return background(
              context,
              RenderParagraphProseTextLayout(
                richText: widget.richText,
                renderParagraph: _paragraph!,
              ),
            );
          } else {
            return const SizedBox();
          }
        },
      ),
      foreground: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final foreground = widget.layerAboveBuilder;
          if (foreground != null && _paragraph != null) {
            return foreground(
              context,
              RenderParagraphProseTextLayout(
                richText: widget.richText,
                renderParagraph: _paragraph!,
              ),
            );
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }
}

class _SuperTextLayout extends MultiChildRenderObjectWidget {
  _SuperTextLayout({
    Key? key,
    required this.state,
    required _LayoutAwareRichText text,
    required Widget foreground,
    required Widget background,
  }) : super(key: key, children: [background, text, foreground]);

  final _SuperTextState state;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderSuperTextLayout(state: state);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSuperTextLayout renderObject) {
    renderObject.state = state;
  }
}

class _SuperTextLayoutParentData extends ContainerBoxParentData<RenderBox> {}

class RenderSuperTextLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SuperTextLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SuperTextLayoutParentData> {
  /// Returns the [ProseTextLayout] within a [SuperTextLayout] that's connected
  /// to the given [key].
  static ProseTextLayout? textLayoutFrom(GlobalKey key) {
    final renderTextLayout = key.currentContext?.findRenderObject() as RenderSuperTextLayout;
    if (renderTextLayout.state._paragraph == null) {
      return null;
    }

    return RenderParagraphProseTextLayout(
      richText: renderTextLayout.state.widget.richText,
      renderParagraph: renderTextLayout.state._paragraph!,
    );
  }

  RenderSuperTextLayout({
    required _SuperTextState state,
  }) : _state = state;

  _SuperTextState? _state;

  _SuperTextState get state => _state!;

  set state(_SuperTextState value) {
    if (_state != value) {
      _state = value;
      markNeedsLayout();
      markNeedsPaint();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SuperTextLayoutParentData) {
      child.parentData = _SuperTextLayoutParentData();
    }
  }

  @override
  void performLayout() {
    print("Super text, performing layout");
    final children = getChildrenAsList();
    final background = children[0];
    final text = children[1];
    final foreground = children[2];

    text.layout(constraints, parentUsesSize: true);
    state._paragraph = text as RenderLayoutAwareParagraph;
    print("Done laying out RenderParagraph: ${state._paragraph}");
    final layerConstraints = constraints.copyWith(maxHeight: text.size.height);

    background.layout(layerConstraints, parentUsesSize: true);
    foreground.layout(layerConstraints, parentUsesSize: true);

    size = text.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// A version of [RichText] that notifies clients when the underlying
/// [RenderParagraph] invalidates its layout, so that clients can avoid
/// accessing properties when the layout is invalid.
class _LayoutAwareRichText extends RichText {
  _LayoutAwareRichText({
    Key? key,
    required InlineSpan text,
    required this.onMarkNeedsLayout,
  }) : super(key: key, text: text);

  /// Callback invoked when the underlying [RenderParagraph] invalidates
  /// its layout.
  final VoidCallback onMarkNeedsLayout;

  @override
  RenderLayoutAwareParagraph createRenderObject(BuildContext context) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    return RenderLayoutAwareParagraph(
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
      onMarkNeedsLayout: onMarkNeedsLayout,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLayoutAwareParagraph renderObject) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..textDirection = textDirection ?? Directionality.of(context)
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaleFactor = textScaleFactor
      ..maxLines = maxLines
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..onMarkNeedsLayout = onMarkNeedsLayout;
  }
}

/// A [RenderParagraph] that publicly reports whether or not its
/// layout is valid, and also accepts a callback to notify a listener
/// when the layout is marked invalid.
class RenderLayoutAwareParagraph extends RenderParagraph {
  RenderLayoutAwareParagraph(
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
    TextHeightBehavior? textHeightBehavior,
    List<RenderBox>? children,
    VoidCallback? onMarkNeedsLayout,
  })  : _onMarkNeedsLayout = onMarkNeedsLayout,
        super(
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

  VoidCallback? get onMarkNeedsLayout => _onMarkNeedsLayout;
  VoidCallback? _onMarkNeedsLayout;
  set onMarkNeedsLayout(VoidCallback? value) {
    if (_onMarkNeedsLayout != value) {
      _onMarkNeedsLayout = value;
    }
  }

  bool get needsLayout => _needsLayout;
  bool _needsLayout = true;

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    _needsLayout = true;
    _onMarkNeedsLayout?.call();
  }

  @override
  void performLayout() {
    super.performLayout();
    _needsLayout = false;
  }
}

extension on TextStyle {
  double get estimatedLineHeight => (fontSize ?? 18.0) * (height ?? 1.0);
}

typedef SuperTextLayerBuilder = Widget Function(BuildContext, TextLayout textLayout);

/// A [SuperTextLayerBuilder] that combines multiple other layers into a single
/// layer, to be displayed above or beneath [SuperText].
///
/// The layers are drawn bottom-to-top, with the bottom layer being the first
/// layer in the list of layers.
class MultiLayerBuilder {
  const MultiLayerBuilder(this._layers);

  final List<SuperTextLayerBuilder> _layers;

  Widget build(BuildContext context, TextLayout textLayout) {
    return Stack(
      children: [
        for (final layer in _layers) //
          layer(context, textLayout),
      ],
    );
  }
}
