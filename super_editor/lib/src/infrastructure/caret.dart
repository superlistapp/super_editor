import 'dart:async';

import 'package:flutter/material.dart';

import 'text_layout.dart';

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

  final CaretBlinkController? controller;
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
  late CaretBlinkController _caretBlinkController;

  @override
  void initState() {
    super.initState();

    _caretBlinkController = widget.controller ??
        CaretBlinkController(
          tickerProvider: this,
        );
    if (widget.caretOffset != null) {
      _caretBlinkController.onCaretPlaced();
    }
  }

  @override
  void didUpdateWidget(BlinkingCaret oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.caretOffset != oldWidget.caretOffset) {
      if (widget.caretOffset != null) {
        _caretBlinkController.onCaretMoved();
      } else {
        _caretBlinkController.onCaretRemoved();
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
      painter: _CursorPainter(
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

class _CursorPainter extends CustomPainter {
  _CursorPainter({
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

  final CaretBlinkController blinkController;
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

    if (borderRadius == BorderRadius.zero) {
      canvas.drawRect(
        Rect.fromLTWH(
          caretOffset!.dx.roundToDouble(),
          caretOffset!.dy.roundToDouble(),
          width,
          height,
        ),
        caretPaint,
      );
    } else {
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
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) {
    return caretHeight != oldDelegate.caretHeight ||
        caretOffset != oldDelegate.caretOffset ||
        isTextEmpty != oldDelegate.isTextEmpty ||
        showCaret != oldDelegate.showCaret;
  }
}

class CaretBlinkController with ChangeNotifier {
  CaretBlinkController({
    required TickerProvider tickerProvider,
    Duration flashPeriod = const Duration(milliseconds: 500),
  }) : _flashPeriod = flashPeriod;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final Duration _flashPeriod;
  Timer? _timer;

  bool _isBlinkingEnabled = true;
  set isBlinkingEnabled(bool newValue) {
    if (newValue == _isBlinkingEnabled) {
      return;
    }

    _isBlinkingEnabled = newValue;
    if (!_isBlinkingEnabled) {
      _timer?.cancel();
    }
    notifyListeners();
  }

  bool _isVisible = true;
  double get opacity => _isVisible ? 1.0 : 0.0;

  void startBlinking() {
    _startTimer();
  }

  void stopBlinking() {
    _isVisible = true; // If we're not blinking then we need to be visible
    _stopTimer();
  }

  /// Clients should call this method when the caret first appears
  /// in the content so that this controller immediately makes the
  /// caret visible.
  void onCaretPlaced() {
    onCaretMoved();
  }

  /// Clients should call this method whenever the caret moves within
  /// the content so that the caret is made fully opaque and the blink
  /// timer restarts.
  void onCaretMoved() {
    // Immediately make the caret visible whenever the position
    // changes, e.g., when the user adds/removes a character.
    _isVisible = true;

    _timer?.cancel();

    if (!_isBlinkingEnabled) {
      return;
    }

    _startTimer();
  }

  /// Clients should call this method when the caret is removed from
  /// the content so that this controller can cancel the blink timer.
  void onCaretRemoved() {
    _stopTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(_flashPeriod, _onToggleTimer);
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _onToggleTimer() {
    _isVisible = !_isVisible;
    notifyListeners();

    if (_isBlinkingEnabled) {
      _timer = Timer(_flashPeriod, _onToggleTimer);
    }
  }
}
