import 'package:flutter/widgets.dart';

import 'infrastructure/blink_controller.dart';
import 'text_layout.dart';

class TextLayoutCaret extends StatefulWidget {
  const TextLayoutCaret({
    Key? key,
    required this.textLayout,
    this.blinkController,
    this.blinkTimingMode = BlinkTimingMode.ticker,
    this.blinkCaret = true,
    required this.style,
    required this.position,
    this.caretTracker,
  }) : super(key: key);

  final TextLayout textLayout;
  final BlinkController? blinkController;
  final BlinkTimingMode blinkTimingMode;
  final bool blinkCaret;
  final CaretStyle style;
  final TextPosition? position;
  final LayerLink? caretTracker;

  @override
  State<TextLayoutCaret> createState() => TextLayoutCaretState();
}

@visibleForTesting
class TextLayoutCaretState extends State<TextLayoutCaret> with TickerProviderStateMixin {
  late BlinkController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = _obtainBlinkController();
    if (widget.blinkCaret) {
      _blinkController.startBlinking();
    }
  }

  @override
  void didUpdateWidget(TextLayoutCaret oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.blinkController != oldWidget.blinkController) {
      if (oldWidget.blinkController == null) {
        // Dispose the old internal BlinkController. We do this in a post-frame callback
        // so that the CaretPainter has time to detach itself as a listener from the old
        // BlinkController before we dispose it. If we dispose immediately, then the
        // CaretPainter will throw an exception when it deregister itself.
        // TODO: ask the Flutter community if there's a common solution to this situation
        final oldBlinkController = _blinkController;
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          oldBlinkController.dispose();
        });
      }
      _blinkController = _obtainBlinkController();
    }

    if (widget.position != oldWidget.position && widget.blinkCaret) {
      // The caret moved to a new position. Go back to a fully opaque
      // caret and start the blink timer over again.
      _blinkController.jumpToOpaque();
    }
  }

  @override
  void dispose() {
    if (widget.blinkController == null) {
      _blinkController.dispose();
    }

    super.dispose();
  }

  BlinkController _obtainBlinkController() {
    if (widget.blinkController != null) {
      return widget.blinkController!;
    }

    switch (widget.blinkTimingMode) {
      case BlinkTimingMode.ticker:
        return BlinkController(tickerProvider: this);
      case BlinkTimingMode.timer:
        return BlinkController.withTimer();
    }
  }

  @visibleForTesting
  bool get isCaretPresent => widget.position != null && widget.position!.offset >= 0;

  @visibleForTesting
  Offset? get caretOffset => isCaretPresent
      ? widget.textLayout.getOffsetForCaret(widget.position!).translate(-widget.style.width / 2, 0.0)
      : null;

  @visibleForTesting
  double? get caretHeight => isCaretPresent
      ? widget.textLayout.getHeightForCaret(widget.position!) ??
          widget.textLayout.getLineHeightAtPosition(widget.position!)
      : null;

  @visibleForTesting
  Rect? get localCaretGeometry => isCaretPresent ? caretOffset! & Size(widget.style.width, caretHeight!) : null;

  Rect? get globalCaretGeometry {
    if (!isCaretPresent) {
      return null;
    }

    final topLeftInGlobalSpace = (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero);
    return localCaretGeometry!.translate(topLeftInGlobalSpace.dx, topLeftInGlobalSpace.dy);
  }

  @override
  Widget build(BuildContext context) {
    final offset = caretOffset;
    final height = caretHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            size: Size(widget.style.width, height ?? 0),
            painter: CaretPainter(
              blinkController: _blinkController,
              caretStyle: widget.style,
              offset: offset,
              height: height,
            ),
          ),
        ),
        if (widget.caretTracker != null && offset != null)
          Positioned(
            left: offset.dx,
            top: offset.dy,
            width: widget.style.width,
            height: height,
            child: CompositedTransformTarget(
              link: widget.caretTracker!,
            ),
          ),
      ],
    );
  }
}

class CaretPainter extends CustomPainter {
  CaretPainter({
    this.blinkController,
    required CaretStyle caretStyle,
    this.offset,
    required double? height,
  })  : _caretStyle = caretStyle,
        _height = height,
        super(repaint: blinkController);

  @visibleForTesting
  final BlinkController? blinkController;
  final CaretStyle _caretStyle;
  @visibleForTesting
  final Offset? offset;
  final double? _height;

  @override
  void paint(Canvas canvas, Size size) {
    if (offset == null || _height == null) {
      // No caret to paint.
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset!.dx, offset!.dy, _caretStyle.width, _height!),
        // TODO: either change `Caret` to only support circular radius, or
        //       update painter to support generic geometry
        _caretStyle.borderRadius.resolve(TextDirection.ltr).topLeft,
      ),
      Paint()..color = _caretStyle.color.withValues(alpha: blinkController?.opacity ?? 1.0),
    );
  }

  @override
  bool shouldRepaint(CaretPainter oldDelegate) {
    return blinkController != oldDelegate.blinkController ||
        _caretStyle != oldDelegate._caretStyle ||
        offset != oldDelegate.offset ||
        _height != oldDelegate._height;
  }
}

class CaretStyle {
  const CaretStyle({
    this.color = const Color(0xFF000000),
    this.width = 2,
    this.borderRadius = BorderRadius.zero,
  });

  final Color color;
  final double width;
  final BorderRadiusGeometry borderRadius;

  CaretStyle copyWith({
    Color? color,
    double? width,
    BorderRadiusGeometry? borderRadius,
  }) {
    return CaretStyle(
      color: color ?? this.color,
      width: width ?? this.width,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
