import 'package:flutter/widgets.dart';
import 'package:super_text/src/text_layout.dart';

import 'infrastructure/blink_controller.dart';

class TextLayoutCaret extends StatefulWidget {
  const TextLayoutCaret({
    Key? key,
    required this.textLayout,
    this.blinkController,
    this.blinkCaret = true,
    required this.style,
    required this.position,
    this.follower,
  }) : super(key: key);

  final TextLayout textLayout;
  final BlinkController? blinkController;
  final bool blinkCaret;
  final CaretStyle style;
  final TextPosition? position;
  final LayerLink? follower;

  @override
  State<TextLayoutCaret> createState() => _TextLayoutCaretState();
}

class _TextLayoutCaretState extends State<TextLayoutCaret> with TickerProviderStateMixin {
  late BlinkController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = widget.blinkController ?? BlinkController(tickerProvider: this);
    if (widget.blinkCaret) {
      print("Starting caret blinking");
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
        WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
          oldBlinkController.dispose();
        });
      }
      _blinkController = widget.blinkController ?? BlinkController(tickerProvider: this);
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

  @override
  Widget build(BuildContext context) {
    print("Building caret. Text layout: ${widget.textLayout}");
    final offset = widget.position != null ? widget.textLayout.getOffsetForCaret(widget.position!) : null;
    final height = widget.position != null
        ? widget.textLayout.getHeightForCaret(widget.position!) ??
            widget.textLayout.getLineHeightAtPosition(widget.position!)
        : null;
    print("Offset: $offset, height: $height, follower: ${widget.follower}");
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: CaretPainter(
              blinkController: _blinkController,
              caretStyle: widget.style,
              offset: offset,
              height: height,
            ),
          ),
        ),
        if (widget.follower != null && offset != null)
          Positioned(
            left: offset.dx,
            top: offset.dy,
            width: widget.style.width,
            height: height,
            child: CompositedTransformTarget(
              link: widget.follower!,
              child: ColoredBox(color: const Color(0xFF00FF00)),
            ),
          ),
      ],
    );
  }
}

class CaretPainter extends CustomPainter {
  CaretPainter({
    BlinkController? blinkController,
    required CaretStyle caretStyle,
    required Offset? offset,
    required double? height,
  })  : _blinkController = blinkController,
        _caretStyle = caretStyle,
        _offset = offset,
        _height = height,
        super(repaint: blinkController);

  final BlinkController? _blinkController;
  final CaretStyle _caretStyle;
  final Offset? _offset;
  final double? _height;

  @override
  void paint(Canvas canvas, Size size) {
    print("Painting caret");
    if (_offset == null || _height == null) {
      // No caret to paint.
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_offset!.dx, _offset!.dy, _caretStyle.width, _height!),
        // TODO: either change `Caret` to only support circular radius, or
        //       update painter to support generic geometry
        _caretStyle.borderRadius.resolve(TextDirection.ltr).topLeft,
      ),
      Paint()..color = _caretStyle.color.withOpacity(_blinkController?.opacity ?? 1.0),
    );
  }

  @override
  bool shouldRepaint(CaretPainter oldDelegate) {
    return _blinkController != oldDelegate._blinkController ||
        _caretStyle != oldDelegate._caretStyle ||
        _offset != oldDelegate._offset ||
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
