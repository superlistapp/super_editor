import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:super_text_layout/super_text_layout_logging.dart';

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
      robotLog.warning("WARNING: Can't type character because the selection extent is invalid");
      robotLog.warning(" - tried to type: '$character' at selection: ${_controller.selection}");
      return;
    }
    if (!_controller.selection.isCollapsed) {
      robotLog.warning("WARNING: Can't type character because the selection is expanded: ${_controller.selection}");
      return;
    }

    robotLog.info("Typing character: $character");
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
            robotLog
                .warning("WARNING: Can't backspace because the selection extent is invalid - ${_controller.selection}");
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
            robotLog
                .warning("WARNING: Can't delete because the selection extent is invalid - ${_controller.selection}");
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
