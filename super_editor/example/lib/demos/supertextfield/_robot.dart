import 'dart:async';
import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

class TextFieldDemoRobot {
  TextFieldDemoRobot({
    required this.focusNode,
    required this.tickerProvider,
    required this.textController,
    required this.textKey,
  });

  void dispose() {
    cancelActions();
  }

  final FocusNode? focusNode;
  final TickerProvider tickerProvider;
  final AttributedTextEditingController textController;
  final GlobalKey<SuperDesktopTextFieldState>? textKey;

  final List<RobotCommand> _commands = [];
  bool _executionDesired = false;
  bool _isExecuting = false;
  RobotCommand? _activeCommand;

  Future<void> typeText(AttributedText text) async {
    _commands.add(TypeTextCommand(
      tickerProvider: tickerProvider,
      textToType: text,
    ));
  }

  Future<void> backspaceCharacters(int characterCount) async {
    _commands.add(DeleteCharactersCommand(
      tickerProvider: tickerProvider,
      characterCount: characterCount,
      direction: TextAffinity.upstream,
    ));
  }

  Future<void> deleteCharacters(int characterCount) async {
    _commands.add(DeleteCharactersCommand(
      tickerProvider: tickerProvider,
      characterCount: characterCount,
      direction: TextAffinity.downstream,
    ));
  }

  Future<void> insertCaretAt(TextPosition position) async {
    _commands.add(InsertCaretCommand(caretPosition: position));
  }

  Future<void> select(TextSelection selection) async {
    _commands.add(SelectTextCommand(selection: selection));
  }

  Future<void> deselect() async {
    _commands.add(SelectTextCommand(selection: const TextSelection.collapsed(offset: -1)));
  }

  Future<void> pause(Duration duration) async {
    _commands.add(PauseCommand(
      tickerProvider: tickerProvider,
      duration: duration,
    ));
  }

  void start() {
    if (!_executionDesired) {
      _executionDesired = true;
      _run();
    }
  }

  Future<void> _run() async {
    if (_isExecuting) {
      return;
    }
    _isExecuting = true;

    while (_commands.isNotEmpty) {
      _activeCommand = _commands.removeAt(0);
      await _activeCommand!.run(focusNode, textController, textKey);

      if (!_executionDesired) {
        break;
      }
    }

    _isExecuting = false;
  }

  void cancelActions() {
    _commands.clear();
    _activeCommand?.cancel();
    _activeCommand = null;
    _executionDesired = false;
  }
}

abstract class RobotCommand {
  Future<void> run(
    FocusNode? focusNode,
    AttributedTextEditingController textController,
    GlobalKey<SuperDesktopTextFieldState>? textKey,
  );

  void cancel();
}

class TypeTextCommand implements RobotCommand {
  TypeTextCommand({
    required this.tickerProvider,
    required this.textToType,
  });

  final TickerProvider tickerProvider;
  final AttributedText textToType;
  bool isCancelled = false;
  Completer? _characterCompleter;
  late Duration _characterDelay;
  Ticker? _characterDelayTicker;

  @override
  Future<void> run(
    FocusNode? focusNode,
    AttributedTextEditingController textController,
    GlobalKey<SuperDesktopTextFieldState>? textKey,
  ) async {
    if (textController.selection.extentOffset == -1) {
      print('Can\'t type text because the text field doesn\'t have a valid selection.');
      return;
    }

    focusNode!.requestFocus();

    for (int i = 0; i < textToType.text.length; ++i) {
      _typeCharacter(textController, i);

      await _waitForCharacterDelay();

      if (isCancelled) {
        return;
      }
    }
  }

  void _typeCharacter(AttributedTextEditingController textController, int offset) {
    textController.text = textController.text.insertString(
      textToInsert: textToType.text[offset], // TODO: support insertion of attributed text
      startOffset: textController.selection.extentOffset,
    );

    final previousSelection = textController.selection;
    textController.selection = TextSelection(
      baseOffset: previousSelection.isCollapsed ? previousSelection.extentOffset + 1 : previousSelection.baseOffset,
      extentOffset: previousSelection.extentOffset + 1,
    );
  }

  Future<void> _waitForCharacterDelay() async {
    final random = Random();
    _characterDelay = Duration(milliseconds: random.nextInt(250));
    _characterCompleter = Completer();
    _characterDelayTicker = tickerProvider.createTicker(_onTick);
    _characterDelayTicker!.start(); // ignore: unawaited_futures
    await _characterCompleter!.future;
  }

  void _onTick(Duration elapsedTime) {
    if (elapsedTime >= _characterDelay) {
      _stopTickerAndComplete();
    }
  }

  void _stopTickerAndComplete() {
    _characterDelayTicker?.stop();
    _characterDelayTicker?.dispose();
    _characterDelayTicker = null;
    if (!_characterCompleter!.isCompleted) {
      _characterCompleter?.complete();
    }
  }

  @override
  void cancel() {
    isCancelled = true;
    _stopTickerAndComplete();
  }
}

class DeleteCharactersCommand implements RobotCommand {
  DeleteCharactersCommand({
    required this.tickerProvider,
    required this.characterCount,
    required this.direction,
  });

  final TickerProvider tickerProvider;
  final int characterCount;
  final TextAffinity direction;
  bool isCancelled = false;
  Completer? _deleteCompleter;
  late Duration _deleteDelay;
  Ticker? _deleteDelayTicker;

  @override
  Future<void> run(
    FocusNode? focusNode,
    AttributedTextEditingController textController,
    GlobalKey<SuperDesktopTextFieldState>? textKey,
  ) async {
    if (textController.selection.extentOffset == -1) {
      print('Can\'t delete characters because the text field doesn\'t have a valid selection.');
      return;
    }

    focusNode!.requestFocus();

    int currentOffset = textController.selection.extentOffset;
    final finalLength = textController.text.text.length - characterCount;
    while (textController.text.text.length > finalLength) {
      final codePointsDeleted = _deleteCharacter(textController, currentOffset, direction);
      if (direction == TextAffinity.upstream) {
        currentOffset -= codePointsDeleted;
      }

      await _waitForDeleteDelay();

      if (isCancelled) {
        return;
      }
    }
  }

  int _deleteCharacter(AttributedTextEditingController textController, int offset, TextAffinity direction) {
    int deleteStartIndex;
    int deleteEndIndex;
    int deletedCodePointCount;
    int newSelectionIndex;

    if (direction == TextAffinity.downstream) {
      // Delete the character after the offset
      deleteStartIndex = offset;
      deleteEndIndex = getCharacterEndBounds(textController.text.text, offset);
      deletedCodePointCount = deleteEndIndex - deleteStartIndex;
      newSelectionIndex = deleteStartIndex;
    } else {
      // Delete the character before the offset
      deleteStartIndex = getCharacterStartBounds(textController.text.text, offset);
      deleteEndIndex = offset + 1;
      deletedCodePointCount = offset - deleteStartIndex;
      newSelectionIndex = deleteStartIndex;
    }

    textController.text = textController.text.removeRegion(
      startOffset: deleteStartIndex,
      endOffset: deleteEndIndex,
    );

    textController.selection = TextSelection.collapsed(offset: newSelectionIndex);

    return deletedCodePointCount;
  }

  Future<void> _waitForDeleteDelay() async {
    final random = Random();
    _deleteDelay = Duration(milliseconds: random.nextInt(250));
    _deleteCompleter = Completer();
    _deleteDelayTicker = tickerProvider.createTicker(_onTick);
    _deleteDelayTicker!.start(); // ignore: unawaited_futures
    await _deleteCompleter!.future;
  }

  void _onTick(Duration elapsedTime) {
    if (elapsedTime >= _deleteDelay) {
      _stopTickerAndComplete();
    }
  }

  void _stopTickerAndComplete() {
    _deleteDelayTicker?.stop();
    _deleteDelayTicker?.dispose();
    _deleteDelayTicker = null;
    if (!_deleteCompleter!.isCompleted) {
      _deleteCompleter?.complete();
    }
  }

  @override
  void cancel() {
    isCancelled = true;
    _stopTickerAndComplete();
  }
}

class InsertCaretCommand implements RobotCommand {
  InsertCaretCommand({
    required this.caretPosition,
  });

  final TextPosition caretPosition;

  @override
  Future<void> run(
    FocusNode? focusNode,
    AttributedTextEditingController textController,
    GlobalKey<SuperDesktopTextFieldState>? textKey,
  ) async {
    focusNode!.requestFocus();
    textController.selection = TextSelection.collapsed(offset: caretPosition.offset);
  }

  @override
  void cancel() {}
}

class SelectTextCommand implements RobotCommand {
  SelectTextCommand({
    required this.selection,
  });

  final TextSelection selection;

  @override
  Future<void> run(
    FocusNode? focusNode,
    AttributedTextEditingController textController,
    GlobalKey<SuperDesktopTextFieldState>? textKey,
  ) async {
    focusNode!.requestFocus();
    textController.selection = selection;
  }

  @override
  void cancel() {}
}

class PauseCommand implements RobotCommand {
  PauseCommand({
    required this.tickerProvider,
    required this.duration,
  });

  final TickerProvider tickerProvider;
  final Duration duration;
  late Completer _completer;
  Ticker? _ticker;

  @override
  Future<void> run(
    FocusNode? focusNode,
    AttributedTextEditingController textController,
    GlobalKey<SuperDesktopTextFieldState>? textKey,
  ) async {
    _completer = Completer();

    _ticker = tickerProvider.createTicker(_onTick);
    _ticker!.start(); // ignore: unawaited_futures

    await _completer.future;
  }

  void _onTick(Duration elapsedTime) {
    if (elapsedTime >= duration) {
      _stopTickerAndComplete();
    }
  }

  void _stopTickerAndComplete() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  void cancel() {
    _stopTickerAndComplete();
  }
}
