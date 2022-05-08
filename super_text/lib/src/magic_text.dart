import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_text/src/text_layout.dart';

typedef MagicParagraph = TextLayout? Function();
typedef MagicTextLayer = Widget Function(BuildContext context, TextLayout? Function() getTextLayout);

@immutable
class SuperText extends StatelessWidget {
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
  final MagicTextLayer? layerBeneathBuilder;

  /// Builds a widget that appears above the text, e.g., to render a caret.
  final MagicTextLayer? layerAboveBuilder;

  @override
  Widget build(BuildContext context) {
    return MagicTextParent(
      text: richText,
      background: layerBeneathBuilder,
      foreground: layerAboveBuilder,
    );
  }
}

@immutable
class MagicTextParent extends StatefulWidget {
  const MagicTextParent({
    Key? key,
    required this.text,
    this.background,
    this.foreground,
  }) : super(key: key);

  final InlineSpan text;
  final MagicTextLayer? background;
  final MagicTextLayer? foreground;

  @override
  State<MagicTextParent> createState() => _MagicTextParentState();
}

class _MagicTextParentState extends State<MagicTextParent> {
  RenderLayoutAwareParagraph? _paragraph;

  void _invalidateParagraph() => _paragraph = null;

  @override
  void reassemble() {
    print("_MagicTextParentState reassemble, paragraph: $_paragraph");
    super.reassemble();
  }

  @override
  Widget build(BuildContext context) {
    return _MagicTextLayout(
      state: this,
      text: _NotifyingRichText(
        text: widget.text,
        onMarkNeedsLayout: _invalidateParagraph,
      ),
      background: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final background = widget.background;
          if (background != null && _paragraph != null) {
            return background(context, () {
              return _paragraph != null && !_paragraph!.needsLayout
                  ? RenderParagraphProseTextLayout(
                      richText: widget.text,
                      renderParagraph: _paragraph!,
                    )
                  : null;
            });
          } else {
            return const SizedBox();
          }
        },
      ),
      foreground: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final foreground = widget.foreground;
          if (foreground != null && _paragraph != null) {
            return foreground(context, () {
              print("Returning text layout for foreground");
              return _paragraph != null && !_paragraph!.needsLayout
                  ? RenderParagraphProseTextLayout(
                      richText: widget.text,
                      renderParagraph: _paragraph!,
                    )
                  : null;
            });
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }
}

class _MagicTextLayout extends MultiChildRenderObjectWidget {
  _MagicTextLayout({
    Key? key,
    required this.state,
    required _NotifyingRichText text,
    required Widget foreground,
    required Widget background,
  }) : super(key: key, children: [background, text, foreground]);

  final _MagicTextParentState state;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderMagicTextLayout(state: state);
  }

  @override
  void updateRenderObject(BuildContext context, RenderMagicTextLayout renderObject) {
    renderObject.state = state;
  }
}

class _MagicTextLayoutParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMagicTextLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MagicTextLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MagicTextLayoutParentData> {
  static ProseTextLayout? textLayoutFrom(GlobalKey key) {
    final renderTextLayout = key.currentContext?.findRenderObject() as RenderMagicTextLayout;
    if (renderTextLayout.state._paragraph == null) {
      return null;
    }

    return RenderParagraphProseTextLayout(
      richText: renderTextLayout.state.widget.text,
      renderParagraph: renderTextLayout.state._paragraph!,
    );
  }

  RenderMagicTextLayout({
    required _MagicTextParentState state,
  }) : _state = state;

  _MagicTextParentState? _state;

  _MagicTextParentState get state => _state!;

  set state(_MagicTextParentState value) {
    if (_state != value) {
      _state = value;
      markNeedsLayout();
      markNeedsPaint();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MagicTextLayoutParentData) {
      child.parentData = _MagicTextLayoutParentData();
    }
  }

  @override
  void performLayout() {
    print("Magic text, performing layout");
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

class _NotifyingRichText extends RichText {
  _NotifyingRichText({
    Key? key,
    required InlineSpan text,
    required this.onMarkNeedsLayout,
  }) : super(key: key, text: text);

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
    ui.TextHeightBehavior? textHeightBehavior,
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

  VoidCallback? _onMarkNeedsLayout;

  VoidCallback? get onMarkNeedsLayout => _onMarkNeedsLayout;

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
