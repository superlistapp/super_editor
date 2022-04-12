import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_text/src/super_text_with_selection.dart';
import 'package:super_text/src/text_selection_layer.dart';

import 'caret_layer.dart';
import 'infrastructure/blink_controller.dart';
import 'super_text.dart';
import 'text_layout.dart';

// /// Displays text with a selection highlight and a caret.
// ///
// /// [SuperSelectableText] does not recognize any user interaction. It's the
// /// responsibility of ancestor widgets to recognize interactions that
// /// should alter this widget's text selection and/or caret position.
// ///
// /// [textSelection] determines the span of text to be painted
// /// with a selection highlight.
// ///
// /// [showCaret] and [textSelection] together determine whether or not the
// /// caret is painted in this [SuperSelectableText]. If [textSelection] is collapsed
// /// with an offset `< 0`, then no caret is displayed. If [showCaret] is
// /// `false` then no caret is displayed. If [textSelection] has a [baseOffset]
// /// or [extentOffset] that is `>= 0` and [showCaret] is `true`, then a caret is
// /// displayed. An explicit [showCaret] control is offered because multiple
// /// [SuperSelectableText] widgets might be displayed together with a selection
// /// spanning multiple [SuperSelectableText] widgets, but only one of the
// /// [SuperSelectableText] widgets displays a caret.
// ///
// /// If [text] is empty, and a [textSelection] with an extent `>= 0` is provided, and
// /// [highlightWhenEmpty] is `true`, then [SuperSelectableText] will paint a small
// /// highlight, despite having no content. This is useful when showing that
// /// one or more empty text areas are selected.
// class SuperSelectableText extends StatefulWidget {
//   /// [SuperSelectableText] that displays plain text (only one text style).
//   SuperSelectableText.plain({
//     Key? key,
//     required String text,
//     required TextStyle style,
//     this.textAlign = TextAlign.left,
//     this.textDirection = TextDirection.ltr,
//     this.textSelection = const TextSelection.collapsed(offset: -1),
//     this.textSelectionDecoration = const TextSelectionDecoration(
//       selectionColor: Color(0xFFACCEF7),
//     ),
//     this.showCaret = false,
//     this.textCaretFactory = const TextCaretFactory(
//       color: Colors.black,
//       width: 1,
//       borderRadius: BorderRadius.zero,
//     ),
//     this.highlightWhenEmpty = false,
//   })  : richText = TextSpan(text: text, style: style),
//         super(key: key);
//
//   /// [SuperSelectableText] that displays styled text.
//   const SuperSelectableText({
//     Key? key,
//     required TextSpan textSpan,
//     this.textAlign = TextAlign.left,
//     this.textDirection = TextDirection.ltr,
//     this.textSelection = const TextSelection.collapsed(offset: -1),
//     this.textSelectionDecoration = const TextSelectionDecoration(
//       selectionColor: Color(0xFFACCEF7),
//     ),
//     this.highlightWhenEmpty = false,
//     this.showCaret = false,
//     this.textCaretFactory = const TextCaretFactory(
//       color: Colors.black,
//       width: 1,
//       borderRadius: BorderRadius.zero,
//     ),
//   })  : richText = textSpan,
//         super(key: key);
//
//   /// The text to display in this [SuperSelectableText] widget.
//   final TextSpan richText;
//
//   /// The alignment to use for [richText] display.
//   final TextAlign textAlign;
//
//   /// The text direction to use for [richText] display.
//   final TextDirection textDirection;
//
//   /// The portion of [richText] to display with the
//   /// [textSelectionDecoration].
//   final TextSelection textSelection;
//
//   /// The visual decoration to apply to the [textSelection].
//   final TextSelectionDecoration textSelectionDecoration;
//
//   /// Builds the visual representation of the caret in this
//   /// [SuperSelectableText] widget.
//   final TextCaretFactory textCaretFactory;
//
//   /// True to show a thin selection highlight when [richText]
//   /// is empty, or false to avoid showing a selection highlight
//   /// when [richText] is empty.
//   ///
//   /// This is useful when multiple [SuperSelectableText] widgets
//   /// are selected and some of the selected [SuperSelectableText]
//   /// widgets are empty.
//   final bool highlightWhenEmpty;
//
//   /// True to display a caret in this [SuperSelectableText] at
//   /// the [extent] of [textSelection], or false to avoid
//   /// displaying a caret.
//   final bool showCaret;
//
//   @override
//   SuperSelectableTextState createState() => SuperSelectableTextState();
// }
//
// class SuperSelectableTextState extends State<SuperSelectableText> implements ProseTextBlock {
//   // [GlobalKey] that provides access to the [RenderParagraph] associated
//   // with the text that this [SuperSelectableText] widget displays.
//   final _textKey = GlobalKey<SuperTextState>();
//
//   @override
//   ProseTextLayout get textLayout => _textKey.currentState as ProseTextLayout;
//
//   RenderParagraph? get _renderParagraph => _textKey.currentContext?.findRenderObject() as RenderParagraph?;
//
//   @override
//   Widget build(BuildContext context) {
//     return SuperTextWithSelection.single(
//       textLayoutKey: _textKey,
//       richText: widget.richText,
//       userSelection: UserSelection(
//         highlightStyle: SelectionHighlightStyle(
//           color: widget.textSelectionDecoration.selectionColor,
//         ),
//         // TODO: update SuperSelectableText widget API to take in CaretStyle
//         caretStyle: const CaretStyle(
//           color: Colors.black,
//         ),
//         selection: widget.textSelection,
//         highlightWhenEmpty: widget.highlightWhenEmpty,
//         hasCaret: widget.showCaret,
//       ),
//     );
//   }
// }
//
class TextSelectionDecoration {
  const TextSelectionDecoration({
    required this.selectionColor,
  });

  final Color selectionColor;

  Widget build({
    required BuildContext context,
    required RenderParagraph renderParagraph,
    required TextSelection selection,
    required bool isTextEmpty,
    required bool highlightWhenEmpty,
    required double emptyLineHeight,
  }) {
    return CustomPaint(
      painter: _TextSelectionPainter(
        renderParagraph: renderParagraph,
        selection: selection,
        selectionColor: selectionColor,
        isTextEmpty: isTextEmpty,
        highlightWhenEmpty: highlightWhenEmpty,
        emptySelectionHeight: emptyLineHeight,
      ),
    );
  }
}

class _TextSelectionPainter extends CustomPainter {
  _TextSelectionPainter({
    required this.isTextEmpty,
    required this.renderParagraph,
    required this.selection,
    required this.emptySelectionHeight,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  }) : selectionPaint = Paint()..color = selectionColor;

  final bool isTextEmpty;
  final RenderParagraph renderParagraph;
  final TextSelection selection;
  final double emptySelectionHeight;
  // When true, an empty, collapsed selection will be highlighted
  // for the purpose of showing a highlighted empty line.
  final bool highlightWhenEmpty;
  final Color selectionColor;
  final Paint selectionPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (isTextEmpty && highlightWhenEmpty && selection.isCollapsed && selection.extentOffset == 0) {
      //&& highlightWhenEmpty) {
      // This is an empty paragraph, which is selected. Paint a small selection.
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 5, 20),
        selectionPaint,
      );
    }

    final selectionBoxes = renderParagraph.getBoxesForSelection(selection);

    for (final box in selectionBoxes) {
      final rawRect = box.toRect();
      final rect = Rect.fromLTWH(rawRect.left, rawRect.top - 2, rawRect.width, rawRect.height + 4);

      canvas.drawRect(
        // Note: If the rect has no width then we've selected an empty line. Give
        //       that line a slight width for visibility.
        rect.width > 0 ? rect : Rect.fromLTWH(rect.left, rect.top, 5, rect.height),
        selectionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TextSelectionPainter oldDelegate) {
    return renderParagraph != oldDelegate.renderParagraph || selection != oldDelegate.selection;
  }
}

class TextCaretFactory {
  const TextCaretFactory({
    required Color color,
    double width = 1.0,
    BorderRadius borderRadius = BorderRadius.zero,
  })  : _color = color,
        _width = width,
        _borderRadius = borderRadius;

  final Color _color;
  final double _width;
  final BorderRadius _borderRadius;

  Widget build({
    required BuildContext context,
    required TextLayout textLayout,
    required TextSelection selection,
    required bool isTextEmpty,
    required bool showCaret,
  }) {
    return BlinkingTextCaret(
      textLayout: textLayout,
      color: _color,
      width: _width,
      borderRadius: _borderRadius,
      textPosition: selection.extent,
      isTextEmpty: isTextEmpty,
      showCaret: showCaret,
    );
  }
}

class BlinkingTextCaret extends StatefulWidget {
  const BlinkingTextCaret({
    Key? key,
    required this.textLayout,
    required this.color,
    required this.width,
    required this.borderRadius,
    required this.textPosition,
    required this.isTextEmpty,
    required this.showCaret,
  }) : super(key: key);

  final TextLayout textLayout;
  final Color color;
  final double width;
  final BorderRadius borderRadius;
  final TextPosition textPosition;
  final bool isTextEmpty;
  final bool showCaret;

  @override
  State<BlinkingTextCaret> createState() => _BlinkingTextCaretState();
}

class _BlinkingTextCaretState extends State<BlinkingTextCaret> {
  Offset? _caretOffset;

  @override
  Widget build(BuildContext context) {
    if (widget.textPosition.offset < 0) {
      return const SizedBox();
    }

    final lineHeight = widget.textLayout.getLineHeightAtPosition(widget.textPosition);
    late double caretHeight;
    try {
      caretHeight = widget.textLayout.getHeightForCaret(widget.textPosition) ?? lineHeight;
    } catch (exception) {
      // In debug mode, if we try to getHeightForCaret() when RenderParagraph
      // is dirty, Flutter throws an assertion error. We have no way to query
      // this information, nor force a layout pass, so the best we can do is
      // catch the exception and recover.
      caretHeight = lineHeight;
    }

    late Offset caretOffset;
    try {
      caretOffset = widget.isTextEmpty
          ? Offset(0, (lineHeight - caretHeight) / 2)
          : widget.textLayout.getOffsetForCaret(TextPosition(offset: widget.textPosition.offset));
    } catch (exception) {
      // In debug mode, if we try to getOffsetForCaret() when RenderParagraph
      // is dirty, Flutter throws an assertion error. We have no way to query
      // this information, nor force a layout pass, so the best we can do is
      // catch the exception and recover.
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        if (mounted) {
          // Trigger another build after the current layout pass.
          setState(() {});
        }
      });

      return const SizedBox();
    }

    // This is a hack to solve super_editor bug #369.
    //
    // In profile/release mode, we don't get assertion errors when we try to
    // measure against a dirty text layout. In fact, there's no signal at all
    // that we measured against a dirty text layout. In practice, measuring
    // while dirty results in the caret position thinking that the final word
    // in a single-line of text is wrapped to a 2nd line, causing the caret to
    // sit below the line of text.
    //
    // To deal with this (temporarily), we force the caret offset to be the same
    // for 2 frames before we draw anything. This causes flickering, but that
    // flickering is tolerable because carets blink, normally.
    //
    // See #370 for the ticket that aims to fix all similar timing issues.
    if (_caretOffset != caretOffset) {
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        if (mounted) {
          // Trigger another build after the current layout pass.
          setState(() {
            _caretOffset = caretOffset;
          });
        }
      });
      return const SizedBox();
    }

    return BlinkingCaret(
      caretHeight: caretHeight,
      caretOffset: caretOffset,
      color: widget.color,
      width: widget.width,
      borderRadius: widget.borderRadius,
      isTextEmpty: widget.isTextEmpty,
      showCaret: widget.showCaret && widget.textPosition.offset >= 0,
    );
  }
}

class BlinkingCaret extends StatefulWidget {
  const BlinkingCaret({
    Key? key,
    this.controller,
    this.caretOffset,
    this.caretHeight,
    required this.color,
    required this.width,
    this.borderRadius = BorderRadius.zero,
    this.isTextEmpty = false,
    this.showCaret = true,
  }) : super(key: key);

  final BlinkController? controller;
  final double? caretHeight;
  final Offset? caretOffset;
  final Color color;
  final double width;
  final BorderRadius borderRadius;
  final bool isTextEmpty;
  final bool showCaret;

  @override
  BlinkingCaretState createState() => BlinkingCaretState();
}

class BlinkingCaretState extends State<BlinkingCaret> with SingleTickerProviderStateMixin {
  // Controls the blinking caret animation.
  late BlinkController _caretBlinkController;

  @override
  void initState() {
    super.initState();

    _caretBlinkController = widget.controller ??
        BlinkController(
          tickerProvider: this,
        );
    if (widget.caretOffset != null) {
      _caretBlinkController.jumpToOpaque();
    }
  }

  @override
  void didUpdateWidget(BlinkingCaret oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.caretOffset != oldWidget.caretOffset) {
      if (widget.caretOffset != null) {
        _caretBlinkController.jumpToOpaque();
      } else {
        _caretBlinkController.stopBlinking();
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _caretBlinkController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CaretPainter(
        blinkController: _caretBlinkController,
        caretHeight: widget.caretHeight,
        caretOffset: widget.caretOffset,
        width: widget.width,
        borderRadius: widget.borderRadius,
        caretColor: widget.color,
        isTextEmpty: widget.isTextEmpty,
        showCaret: widget.showCaret,
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({
    required this.blinkController,
    required this.caretHeight,
    required this.caretOffset,
    required this.width,
    required this.borderRadius,
    required this.caretColor,
    required this.isTextEmpty,
    required this.showCaret,
  })  : caretPaint = Paint()..color = caretColor,
        super(repaint: blinkController);

  final BlinkController blinkController;
  final double? caretHeight;
  final Offset? caretOffset;
  final double width;
  final BorderRadius borderRadius;
  final bool isTextEmpty;
  final bool showCaret;
  final Color caretColor;
  final Paint caretPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (!showCaret) {
      return;
    }

    if (caretOffset == null) {
      return;
    }

    caretPaint.color = caretColor.withOpacity(blinkController.opacity);

    final height = caretHeight?.roundToDouble() ?? size.height;

    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        caretOffset!.dx.roundToDouble(),
        caretOffset!.dy.roundToDouble(),
        caretOffset!.dx.roundToDouble() + width,
        caretOffset!.dy.roundToDouble() + height,
        topLeft: borderRadius.topLeft,
        topRight: borderRadius.topRight,
        bottomLeft: borderRadius.bottomLeft,
        bottomRight: borderRadius.bottomRight,
      ),
      caretPaint,
    );
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) {
    return caretHeight != oldDelegate.caretHeight ||
        caretOffset != oldDelegate.caretOffset ||
        isTextEmpty != oldDelegate.isTextEmpty ||
        showCaret != oldDelegate.showCaret;
  }
}

// /// Wraps a given [SuperTextWithSelection] and paints extra decoration
// /// to visualize text boundaries.
// class DebugSelectableTextDecorator extends StatefulWidget {
//   const DebugSelectableTextDecorator({
//     Key? key,
//     required this.selectableTextKey,
//     required this.textLength,
//     required this.child,
//     this.showDebugPaint = false,
//   }) : super(key: key);
//
//   final GlobalKey selectableTextKey;
//   final int textLength;
//   final SuperTextWithSelection child;
//   final bool showDebugPaint;
//
//   @override
//   _DebugSelectableTextDecoratorState createState() => _DebugSelectableTextDecoratorState();
// }
//
// class _DebugSelectableTextDecoratorState extends State<DebugSelectableTextDecorator> {
//   RenderParagraph? get _renderParagraph => widget.selectableTextKey.currentState as ?._renderParagraph;
//
//   List<Rect> _computeTextRectangles(RenderParagraph renderParagraph) {
//     return renderParagraph
//         .getBoxesForSelection(TextSelection(
//           baseOffset: 0,
//           extentOffset: widget.textLength,
//         ))
//         .map((box) => box.toRect())
//         .toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         if (widget.showDebugPaint) _buildDebugPaint(),
//         widget.child,
//       ],
//     );
//   }
//
//   Widget _buildDebugPaint() {
//     if (_selectableTextState == null) {
//       // Schedule another frame so we can compute the debug paint.
//       WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
//         setState(() {});
//       });
//       return const SizedBox();
//     }
//     if (_renderParagraph == null) {
//       // Schedule another frame so we can compute the debug paint.
//       WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
//         setState(() {});
//       });
//       return const SizedBox();
//     }
//     if (_renderParagraph!.hasSize && (kDebugMode && _renderParagraph!.debugNeedsLayout)) {
//       // Schedule another frame so we can compute the debug paint.
//       WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
//         setState(() {});
//       });
//       return const SizedBox();
//     }
//
//     return Positioned.fill(
//       child: CustomPaint(
//         painter: _DebugTextPainter(
//           textRectangles: _computeTextRectangles(_renderParagraph!),
//         ),
//         size: Size.infinite,
//       ),
//     );
//   }
// }
//
// class _DebugTextPainter extends CustomPainter {
//   _DebugTextPainter({
//     required this.textRectangles,
//   });
//
//   final List<Rect> textRectangles;
//   final Paint leftBoundaryPaint = Paint()..color = const Color(0xFFCCCCCC);
//   final Paint textBoxesPaint = Paint()
//     ..color = const Color(0xFFCCCCCC)
//     ..style = PaintingStyle.stroke
//     ..strokeWidth = 1;
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     for (final rect in textRectangles) {
//       canvas.drawRect(
//         rect,
//         textBoxesPaint,
//       );
//     }
//
//     // Paint left boundary.
//     canvas.drawRect(
//       Rect.fromLTWH(-6, 0, 2, size.height),
//       leftBoundaryPaint,
//     );
//   }
//
//   @override
//   bool shouldRepaint(_DebugTextPainter oldDelegate) {
//     return textRectangles != oldDelegate.textRectangles;
//   }
// }
