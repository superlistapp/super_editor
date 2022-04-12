import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_text/super_text_logging.dart';

import 'infrastructure/fill_width_if_constrained.dart';
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
  SuperTextState createState() => SuperTextState();
}

@visibleForTesting
class SuperTextState extends State<SuperText> implements TextLayout {
  // GlobalKey that provides access to the RenderParagraph associated
  // with the text that this SuperText widget displays.
  final GlobalKey _textKey = GlobalKey();

  // The above and beneath layers build with the TextLayout inside of
  // this ValueNotifier so that the layers can build independently from
  // the RichText widget.
  final _textLayoutNotifier = ValueNotifier<TextLayout?>(null);

  @override
  void initState() {
    super.initState();

    _updateTextLength();
  }

  @override
  void didUpdateWidget(SuperText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.richText != oldWidget.richText) {
      _updateTextLength();
    }
  }

  // The current length of the text displayed by this widget. The value
  // is cached because computing the length of rich text may have
  // non-trivial performance implications.
  int get _textLength => _cachedTextLength;
  late int _cachedTextLength;
  void _updateTextLength() {
    _cachedTextLength = widget.richText.toPlainText().length;
  }

  double get _estimatedLineHeight {
    final fontSize = widget.richText.style?.fontSize;
    final lineHeight = widget.richText.style?.height;
    return (fontSize ?? 16) * (lineHeight ?? 1.0);
  }

  RenderParagraph? get _renderParagraph =>
      _textKey.currentContext != null ? _textKey.currentContext!.findRenderObject() as RenderParagraph : null;

  @override
  TextPosition? getPositionAtOffset(Offset localOffset) {
    if (_renderParagraph == null) {
      return null;
    }

    if (!_renderParagraph!.size.contains(localOffset)) {
      return null;
    }

    return _renderParagraph!.getPositionForOffset(localOffset);
  }

  @override
  TextPosition getPositionNearestToOffset(Offset localOffset) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    return _renderParagraph!.getPositionForOffset(localOffset);
  }

  @override
  Offset getOffsetAtPosition(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SuperText does not yet have a RenderParagraph. Can\'t getOffsetForPosition().');
    }

    if (_renderParagraph!.hasSize && (kDebugMode && _renderParagraph!.debugNeedsLayout)) {
      // This condition was added because getOffsetForCaret() was throwing
      // an exception when debugNeedsLayout is true. It's unclear what we're
      // supposed to do at our level to ensure that condition doesn't happen
      // so until we figure it out, we'll just return a zero Offset.
      //
      // Later, hasSize was added to this check because it was discovered that
      // debugNeedsLayout can only be accessed in debug mode. The hope is that
      // hasSize will roughly approximate the same information in profile and
      // release modes.
      return Offset.zero;
    }

    return _renderParagraph!.getOffsetForCaret(position, Rect.zero);
  }

  @override
  double getLineHeightAtPosition(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SuperText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }
    if (kDebugMode && _renderParagraph!.debugNeedsLayout) {
      // We can't ask the RenderParagraph for metrics when it's dirty, so we have
      // to estimate the line height based on the text style, if it exists.
      return (widget.richText.style?.fontSize ?? 0.0) * (widget.richText.style?.height ?? 1.0);
    }

    final lineHeightMultiplier = widget.richText.style?.height ?? 1.0;

    // If no text is currently displayed, we can't use a character box
    // to measure, but we may be able to use related metrics.
    if (widget.richText.toPlainText().isEmpty) {
      final estimatedLineHeight =
          _renderParagraph!.getFullHeightForCaret(position) ?? widget.richText.style?.fontSize ?? 0.0;
      return estimatedLineHeight * lineHeightMultiplier;
    }

    // There is some text in this layout. Get the bounding box for the
    // character at the given position and return its height.
    return getCharacterBox(position).toRect().height * lineHeightMultiplier;
  }

  @override
  int getLineCount() {
    if (_renderParagraph == null) {
      throw Exception('SuperText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }
    if (kDebugMode && _renderParagraph!.debugNeedsLayout) {
      return 0;
    }

    return _renderParagraph!
        .getBoxesForSelection(TextSelection(
          baseOffset: 0,
          extentOffset: _textLength,
        ))
        .length;
  }

  @override
  Offset getOffsetForCaret(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SuperText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }

    return _renderParagraph!.getOffsetForCaret(position, Rect.zero);
  }

  @override
  double? getHeightForCaret(TextPosition position) {
    if (_renderParagraph == null) {
      throw Exception('SuperText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }

    return _renderParagraph!.getFullHeightForCaret(position);
  }

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    if (_renderParagraph == null) {
      throw Exception('SuperText does not yet have a RenderParagraph. Can\'t getBoxesForSelection().');
    }

    return _renderParagraph!.getBoxesForSelection(selection);
  }

  @override
  TextBox getCharacterBox(TextPosition position) {
    if (_renderParagraph == null) {
      return const TextBox.fromLTRBD(0, 0, 0, 0, TextDirection.ltr);
    }

    final plainText = widget.richText.toPlainText();
    if (plainText.isEmpty) {
      final lineHeightEstimate = _renderParagraph!.getFullHeightForCaret(const TextPosition(offset: 0)) ?? 0.0;
      return TextBox.fromLTRBD(0, 0, 0, lineHeightEstimate, TextDirection.ltr);
    }

    // Ensure that the given TextPosition does not exceed available text length.
    var characterPosition = position.offset >= plainText.length ? TextPosition(offset: plainText.length - 1) : position;

    var boxes = _renderParagraph!.getBoxesForSelection(TextSelection(
      baseOffset: characterPosition.offset,
      extentOffset: characterPosition.offset + 1,
    ));

    // For any regular character, boxes should return exactly one box
    // for the character. However, emojis don't return any boxes. In that
    // case, we walk the characters up and down the text, hoping to find
    // a non-emoji to measure. If all of the content is emojis, then we can't
    // get a measurement from Flutter.
    //
    // If we don't have any boxes, walk backward in the text to find
    // a character with a box.
    while (boxes.isEmpty && characterPosition.offset > 0) {
      characterPosition = TextPosition(offset: characterPosition.offset - 1);

      boxes = _renderParagraph!.getBoxesForSelection(TextSelection(
        baseOffset: characterPosition.offset,
        extentOffset: characterPosition.offset + 1,
      ));
    }

    // If we still don't have any boxes, walk forward in the text to find
    // a character with a box.
    while (boxes.isEmpty && characterPosition.offset < _textLength - 1) {
      characterPosition = TextPosition(offset: characterPosition.offset + 1);

      boxes = _renderParagraph!.getBoxesForSelection(TextSelection(
        baseOffset: characterPosition.offset,
        extentOffset: characterPosition.offset + 1,
      ));
    }

    return boxes.first;
  }

  @override
  TextPosition getPositionAtStartOfLine(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    final renderParagraph = _renderParagraph!;
    // TODO: use the character box instead of the estimated line height
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final positionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, _estimatedLineHeight / 2);
    final endOfLineOffset = Offset(0, positionOffset.dy);
    return renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  @override
  TextPosition getPositionAtEndOfLine(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    final renderParagraph = _renderParagraph!;
    // TODO: use the character box instead of the estimated line height
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final positionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, _estimatedLineHeight / 2);
    final endOfLineOffset = Offset(renderParagraph.size.width, positionOffset.dy);
    return renderParagraph.getPositionForOffset(endOfLineOffset);
  }

  @override
  TextPosition? getPositionOneLineUp(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return null;
    }

    final renderParagraph = _renderParagraph!;
    // TODO: use the character box instead of the estimated line height
    final lineHeight = _estimatedLineHeight;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineUpOffset = currentSelectionOffset - Offset(0, lineHeight);

    if (oneLineUpOffset.dy < 0) {
      // The first line is selected. There is no line above this.
      return null;
    }

    return renderParagraph.getPositionForOffset(oneLineUpOffset);
  }

  @override
  TextPosition? getPositionOneLineDown(TextPosition currentPosition) {
    if (_renderParagraph == null) {
      return null;
    }

    final renderParagraph = _renderParagraph!;
    // TODO: use the character box instead of the estimated line height
    final lineHeight = _estimatedLineHeight;
    // Note: add half the line height to the current offset to help deal with
    //       line heights that aren't accurate.
    final currentSelectionOffset =
        renderParagraph.getOffsetForCaret(currentPosition, Rect.zero) + Offset(0, lineHeight / 2);
    final oneLineDownOffset = currentSelectionOffset + Offset(0, lineHeight);

    if (oneLineDownOffset.dy > renderParagraph.size.height) {
      // The last line is selected. There is no line below that.
      return null;
    }

    return renderParagraph.getPositionForOffset(oneLineDownOffset);
  }

  @override
  TextPosition getPositionInFirstLineAtX(double x) {
    return getPositionNearestToOffset(Offset(x, 0));
  }

  @override
  TextPosition getPositionInLastLineAtX(double x) {
    if (_renderParagraph == null) {
      return const TextPosition(offset: -1);
    }

    return getPositionNearestToOffset(
      Offset(x, _renderParagraph!.size.height),
    );
  }

  TextSelection getWordSelectionAt(TextPosition position) {
    if (_renderParagraph == null) {
      return const TextSelection.collapsed(offset: -1);
    }

    final wordRange = _renderParagraph!.getWordBoundary(position);
    return TextSelection(
      baseOffset: wordRange.start,
      extentOffset: wordRange.end,
    );
  }

  @override
  TextSelection expandSelection(TextPosition position, TextExpansion expansion, TextAffinity affinity) {
    return expansion(widget.richText.toPlainText(), position, affinity);
  }

  @override
  bool isTextAtOffset(Offset localOffset) {
    if (_renderParagraph == null) {
      return false;
    }

    List<TextBox> boxes = _renderParagraph!.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: _textLength,
      ),
    );

    for (final box in boxes) {
      if (box.toRect().contains(localOffset)) {
        return true;
      }
    }

    return false;
  }

  @override
  TextSelection getSelectionInRect(Offset baseOffset, Offset extentOffset) {
    if (_renderParagraph == null) {
      return const TextSelection.collapsed(offset: -1);
    }

    final renderParagraph = _renderParagraph!;
    final contentHeight = renderParagraph.size.height;
    final textLength = _textLength;

    // We don't know whether the base offset is higher or lower than the
    // extent offset. Regardless, if either offset is above the top of
    // the text then that text position should be 0. If either offset
    // is below the bottom of the text then that offset should be the
    // total length of the text.
    final basePosition = baseOffset.dy < 0
        ? 0
        : baseOffset.dy > contentHeight
            ? textLength
            : renderParagraph.getPositionForOffset(baseOffset).offset;
    final extentPosition = extentOffset.dy < 0
        ? 0
        : extentOffset.dy > contentHeight
            ? textLength
            : renderParagraph.getPositionForOffset(extentOffset).offset;

    final selection = TextSelection(
      baseOffset: basePosition,
      extentOffset: extentPosition,
    );

    return selection;
  }

  bool get _textNeedsLayout {
    if (_renderParagraph == null) {
      return true;
    }

    try {
      // Flutter doesn't expose the layout status of RenderParagraphs. To figure out
      // if the text is laid out, we attempt to use one of the metrics methods and
      // see if it blows up.
      _renderParagraph!.getPositionForOffset(Offset.zero);

      // We successfully accessed the RenderParagraph metrics. It must be laid out.
      return false;
    } catch (exception) {
      // The RenderParagraph blew up when we tried to access text metrics. This means
      // it hasn't laid out yet.
      return true;
    }
  }

  void _schedulePostLayoutFrame() {
    WidgetsBinding.instance!.scheduleFrameCallback((timeStamp) {
      if (!mounted) {
        // This widget no longer exists. No point in doing any more work.
        return;
      }

      if (_textNeedsLayout) {
        // The RenderParagraph still hasn't been laid out. Schedule another frame.
        _schedulePostLayoutFrame();
        return;
      }

      // The RenderParagraph has been laid out. Give the TextLayout to our layers.
      buildsLog.finest("SuperText ($hashCode) text is now laid out. Notifying layers for a build.");
      _textLayoutNotifier.value = this;
    });
  }

  @visibleForTesting
  int get buildCount => _buildCount;
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildsLog.info("Building SuperText ($hashCode)");
    _buildCount += 1;

    if (_textNeedsLayout) {
      buildsLog.info("SuperText ($hashCode) text needs layout. Scheduling followup frame.");
      _textLayoutNotifier.value = null;
      _schedulePostLayoutFrame();
    }

    // The only item in this Stack with intrinsic height is the text.
    // We wrap with IntrinsicHeight so that the layers above and beneath the
    // text have explicit bounds, so that they can position their content
    // relative to the text without inadvertently expanding to take up all
    // available space on the screen.
    return IntrinsicHeight(
      child: IntrinsicWidth(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.layerBeneathBuilder != null)
              Positioned.fill(
                child: _buildLayer(widget.layerBeneathBuilder!),
              ),
            FillWidthIfConstrained(
              child: _buildText(),
            ),
            if (widget.layerAboveBuilder != null)
              Positioned.fill(
                child: _buildLayer(widget.layerAboveBuilder!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildText() {
    buildsLog.info("Building SuperText ($hashCode) internal RichText");

    // If we're re-building the RichText widget then it's probably
    // going to run another text layout. Tell our layers not to render,
    // and schedule a followup frame to get the new layout.
    _textLayoutNotifier.value = null;
    _schedulePostLayoutFrame();

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: _textLength == 0 ? widget.richText.style?.estimatedLineHeight ?? double.infinity : double.infinity,
      ),
      child: RichText(
        key: _textKey,
        text: widget.richText,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
      ),
    );
  }

  Widget _buildLayer(SuperTextLayerBuilder builder) {
    return RepaintBoundary(
      // We build the layer within a ValueListenableBuilder so that we can
      // rebuild the layers without also rebuilding the text widget. If we
      // rebuild the text widget and layers at the same time, then we might
      // end up in an infinite loop where the layers wait a frame for text
      // layout, then call setState(), which causes the text to re-layout,
      // which causes the layers to wait a frame for text layout, on and on.
      child: ValueListenableBuilder(
        valueListenable: _textLayoutNotifier,
        builder: (context, value, child) {
          if (_textLayoutNotifier.value != null) {
            buildsLog.info("Building a SuperText ($hashCode) layer with a TextLayout: ${_textLayoutNotifier.value}");
          }
          return _textLayoutNotifier.value != null ? builder(context, _textLayoutNotifier.value!) : const SizedBox();
        },
      ),
    );
  }
}

extension on TextStyle {
  double get estimatedLineHeight => (fontSize ?? 18.0) * (height ?? 1.0);
}

typedef SuperTextLayerBuilder = Widget Function(BuildContext, TextLayout);

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
