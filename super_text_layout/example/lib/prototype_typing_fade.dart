import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  runApp(const _FadeWhileTypingApp());
}

class _FadeWhileTypingApp extends StatelessWidget {
  const _FadeWhileTypingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _FadeWhileTypingDemo(),
          ),
        ),
      ),
    );
  }
}

class _FadeWhileTypingDemo extends StatefulWidget {
  @override
  _FadeWhileTypingDemoState createState() => _FadeWhileTypingDemoState();
}

class _FadeWhileTypingDemoState extends State<_FadeWhileTypingDemo> with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  String _plainText = "";
  TextSpan _richText = const TextSpan(text: "", style: _textStyle);

  final _characterHighlightAlpha = <int, double>{};
  late Ticker _ticker;

  late TypingRobot _robot;

  @override
  void initState() {
    super.initState();

    _ticker = createTicker(_onTick);

    _controller = TextEditingController()
      ..addListener(() {
        if (_controller.text != _plainText && mounted) {
          setState(() {
            _plainText = _controller.text;
            _richText = TextSpan(text: _plainText, style: _textStyle);

            // We know that the typing robot only adds text in this demo,
            // so the last character in the text was just typed. Give it
            // a highlight.
            _characterHighlightAlpha[_plainText.length - 1] = 1.0;
            if (!_ticker.isTicking) {
              _ticker.start();
            }
          });
        }
      });

    _robot = TypingRobot(
      textEditingController: _controller,
    )
      ..placeCaret(const TextPosition(offset: 0))
      ..typeText(_textMessage)
      ..start();
  }

  @override
  void dispose() {
    _robot.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsedTime) {
    setState(() {
      for (final entry in _characterHighlightAlpha.entries) {
        _characterHighlightAlpha[entry.key] = entry.value - 0.01;
      }
      _characterHighlightAlpha.removeWhere((key, value) => value <= 0.0);

      if (_characterHighlightAlpha.isEmpty) {
        _ticker.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // return _buildBoxHighlightsExample();
    // return _buildCustomPainterGradientExample();
    return Container(
      color: const Color(0xFF222222),
      // color: Colors.white,
      child: RepaintBoundary(
        child: _buildCustomPainterGradientShaderExample(),
      ),
    );
  }

  // Example that displays a different Container behind every character
  // and fades them out, individually.
  Widget _buildBoxHighlightsExample() {
    return SuperText(
      richText: _richText,
      layerBeneathBuilder: (context, textLayout) {
        return Stack(
          children: [
            for (final highlight in _characterHighlightAlpha.entries)
              Positioned.fromRect(
                rect: textLayout.getCharacterBox(TextPosition(offset: highlight.key)).toRect(),
                child: Opacity(
                  opacity: highlight.value.clamp(0.0, 1.0),
                  child: Container(
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Example that uses a custom painter to draw a continuous rectangle
  // per line of text with a continuous highlight gradient across the line.
  Widget _buildCustomPainterGradientExample() {
    return SuperText(
      richText: _richText,
      layerBeneathBuilder: (context, textLayout) {
        return CustomPaint(
          painter: _GradientHighlightPainter(
            textLayout,
            _characterHighlightAlpha,
            applyToText: false,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  // Example that applies a gradient to the text beneath it
  Widget _buildCustomPainterGradientShaderExample() {
    return SuperText(
      richText: _richText,
      // richText: const TextSpan(text: _textMessage, style: _textStyle),
      layerAboveBuilder: (context, textLayout) {
        return CustomPaint(
          painter: _GradientHighlightPainter(
            textLayout,
            // {
            //   0: 0.0,
            //   100: 1.0,
            // },
            _characterHighlightAlpha,
            applyToText: true,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GradientHighlightPainter extends CustomPainter {
  _GradientHighlightPainter(
    this.textLayout,
    this.characterHighlights, {
    required this.applyToText,
  });

  final TextLayout textLayout;
  final Map<int, double> characterHighlights;

  /// Whether the gradient is painted as a fully-visible rectangle, or
  /// the gradient is "applied to the text" with a blending mode.
  final bool applyToText;

  @override
  void paint(Canvas canvas, Size size) {
    if (characterHighlights.isEmpty) {
      return;
    }

    final indices = characterHighlights.keys.toList()..sort((a, b) => a - b);
    final startIndex = indices.first;
    final endIndex = indices.last;

    final lineBoxes = textLayout.getBoxesForSelection(TextSelection(
      baseOffset: startIndex,
      extentOffset: endIndex + 1, // +1 because selection end is exclusive
    ));
    final totalLineBoxExtent = lineBoxes.fold(0.0, (double sum, box) => sum + box.toRect().width);
    final startAlpha = characterHighlights[startIndex]!;
    final endAlpha = characterHighlights[endIndex]!;

    double currentAlpha = startAlpha;
    for (final lineBox in lineBoxes) {
      final rect = lineBox.toRect();
      final lineEndAlpha = ui.lerpDouble(currentAlpha, endAlpha, rect.width / totalLineBoxExtent)!;

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, 0),
          Offset(rect.right, 0),
          [
            Colors.red.withOpacity(currentAlpha),
            Colors.red.withOpacity(lineEndAlpha),
          ],
        );
      // ..blendMode = applyToText ? BlendMode.lighten : BlendMode.srcOver;
      canvas.drawRect(lineBox.toRect(), paint);

      currentAlpha = lineEndAlpha;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

const defaultSelectionColor = Color(0xFFACCEF7);

const _textMessage =
    "This is a prototype for a fading highlight effect. A few effects are available. We can fade character boxes behind the text, gradient boxes behind the text, and a gradient over the text with a blend mode.";

const _textStyle = TextStyle(
  color: Color(0xFF444444),
  fontFamily: 'Roboto',
  fontSize: 40,
  height: 1.4,
);

const _primaryCaretStyle = CaretStyle(
  width: 2.0,
  color: Colors.black,
);
const _primaryHighlightStyle = SelectionHighlightStyle(
  color: defaultSelectionColor,
);

// TypingRobot was copied from Super Editor. Don't keep this around.
class TypingRobot {
  TypingRobot({
    required TextEditingController textEditingController,
    int? randomSeed,
  })  : _controller = textEditingController,
        _random = Random(randomSeed);

  void dispose() {
    _actionQueue.clear();
    _isDisposed = true;
  }

  final _actionQueue = <RobotAction>[];
  final TextEditingController _controller;
  final Random _random;
  bool _isDisposed = false;

  void placeCaret(TextPosition position) {
    _ensureNotDisposed();

    _actionQueue.add(
      _randomPauseBefore(
        () {
          _controller.selection = TextSelection.collapsed(offset: position.offset);
        },
      ),
    );
  }

  void select(TextSelection selection) {
    _ensureNotDisposed();

    _actionQueue.add(
      _randomPauseBefore(
        () {
          _controller.selection = selection;
        },
      ),
    );
  }

  void selectAll() {
    _ensureNotDisposed();

    _actionQueue.add(
      _randomPauseBefore(
        () {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        },
      ),
    );
  }

  void moveCaretLeft({
    int count = 1,
    bool expand = false,
  }) {
    _ensureNotDisposed();

    for (int i = 0; i < count; ++i) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            if (_controller.selection.extentOffset > 0) {
              _controller.selection = _controller.selection.copyWith(
                extentOffset: _controller.selection.extentOffset - 1,
              );
            }
          },
        ),
      );
    }
  }

  void moveCaretRight({
    int count = 1,
    bool expand = false,
  }) {
    _ensureNotDisposed();

    for (int i = 0; i < count; ++i) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            if (_controller.selection.extentOffset < _controller.text.length) {
              _controller.selection = _controller.selection.copyWith(
                extentOffset: _controller.selection.extentOffset + 1,
              );
            }
          },
        ),
      );
    }
  }

  void moveCaretUp({expand = false}) {
    _ensureNotDisposed();

    _actionQueue.add(
      _randomPauseBefore(
        () {
          // TODO: access the TextLayout and move caret one line up
        },
      ),
    );
  }

  void moveCaretDown({expand = false}) {
    _ensureNotDisposed();

    _actionQueue.add(
      _randomPauseBefore(
        () {
          // TODO: access the TextLayout and move caret one line down
        },
      ),
    );
  }

  void typeText(String text) {
    _ensureNotDisposed();

    for (final character in text.characters) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            _typeCharacter(character);
          },
        ),
      );
    }
  }

  void typeTextFast(String text) {
    _ensureNotDisposed();

    for (final character in text.characters) {
      _actionQueue.add(
        _randomPauseBefore(
          () {
            _typeCharacter(character);
          },
          true,
        ),
      );
    }
  }

  void _typeCharacter(String character) {
    if (_controller.selection.extentOffset < 0 || _controller.selection.extentOffset > _controller.text.length) {
      return;
    }
    if (!_controller.selection.isCollapsed) {
      return;
    }

    _controller.value = TextEditingValue(
      text: _controller.text + character,
      selection: TextSelection.collapsed(offset: _controller.selection.extentOffset + 1),
    );
  }

  void backspace() {
    _ensureNotDisposed();

    _actionQueue.add(
      _randomPauseBefore(
        () {
          if (_controller.selection.extentOffset < 1 || _controller.selection.extentOffset > _controller.text.length) {
            return;
          }

          if (_controller.selection.isCollapsed) {
            final newSelection = TextSelection.collapsed(offset: _controller.selection.extentOffset - 1);
            _controller.text = _controller.text
                .replaceRange(_controller.selection.extentOffset, _controller.selection.extentOffset, "");
            _controller.selection = newSelection;
          } else {
            final newSelection = TextSelection.collapsed(offset: _controller.selection.start);
            _controller.text =
                _controller.text.replaceRange(_controller.selection.start, _controller.selection.end, "");
            _controller.selection = newSelection;
          }
        },
      ),
    );
  }

  void delete() {
    _ensureNotDisposed();

    _actionQueue.add(
      _randomPauseBefore(
        () {
          if (_controller.selection.extentOffset < 0 ||
              _controller.selection.extentOffset > _controller.text.length - 1) {
            return;
          }

          if (_controller.selection.isCollapsed) {
            final newSelection = TextSelection.collapsed(offset: _controller.selection.extentOffset - 1);
            _controller.text = _controller.text
                .replaceRange(_controller.selection.extentOffset + 1, _controller.selection.extentOffset + 1, "");
            _controller.selection = newSelection;
          } else {
            final newSelection = TextSelection.collapsed(offset: _controller.selection.start);
            _controller.text =
                _controller.text.replaceRange(_controller.selection.start, _controller.selection.end, "");
            _controller.selection = newSelection;
          }
        },
      ),
    );
  }

  void pause(Duration duration) {
    _ensureNotDisposed();

    _actionQueue.add(
      () async {
        await Future.delayed(duration);
      },
    );
  }

  RobotAction _randomPauseBefore(RobotAction action, [bool fastMode = false]) {
    return () async {
      await Future.delayed(_randomWaitPeriod(fastMode));

      if (_isDisposed) {
        return;
      }

      await action();
    };
  }

  Duration _randomWaitPeriod([bool fastMode = false]) {
    return Duration(milliseconds: _random.nextInt(fastMode ? 45 : 300) + (fastMode ? 5 : 20));
  }

  Future<void> start() async {
    while (_actionQueue.isNotEmpty) {
      final action = _actionQueue.removeAt(0);
      await action();
    }
  }

  Future<void> cancel() async {
    _actionQueue.clear();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw Exception("Tried to schedule a TypingRobot operation after it was disposed.");
    }
  }
}

typedef RobotAction = FutureOr<void> Function();
