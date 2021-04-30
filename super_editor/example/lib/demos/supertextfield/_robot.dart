import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

class TextFieldDemoRobot {
  TextFieldDemoRobot({
    // @required this.ticker,
    @required this.textController,
    @required this.textKey,
  });

  void dispose() {
    cancelActions();
  }

  // final Ticker ticker;
  final AttributedTextEditingController textController;
  final GlobalKey<SuperTextFieldState> textKey;

  final List<RobotCommand> _commands = [];
  bool _isExecuting = false;

  Future<void> typeText(AttributedText text) async {
    _commands.add(TypeTextCommand(
      textToType: text,
    ));
  }

  Future<void> insertCaretAt(TextPosition position) async {
    _commands.add(InsertCaretCommand(caretPosition: position));
  }

  Future<void> select(TextSelection selection) async {
    _commands.add(SelectTextCommand(selection: selection));
  }

  Future<void> deselect() async {
    _commands.add(SelectTextCommand(selection: TextSelection.collapsed(offset: -1)));
  }

  Future<void> pause(Duration duration) async {
    _commands.add(PauseCommand(duration: duration));
  }

  Future<void> start() async {
    if (_isExecuting) {
      return;
    }

    _isExecuting = true;

    while (_commands.isNotEmpty) {
      final command = _commands.removeAt(0);
      await command.run(textController, textKey);
    }

    _isExecuting = false;
  }

  void cancelActions() {
    _isExecuting = false;
    _commands.clear();
  }
}

abstract class RobotCommand {
  Future<void> run(
    AttributedTextEditingController textController,
    GlobalKey<SuperTextFieldState> textKey,
  );
}

class TypeTextCommand implements RobotCommand {
  TypeTextCommand({
    @required this.textToType,
  });

  final AttributedText textToType;

  @override
  Future<void> run(
    AttributedTextEditingController textController,
    GlobalKey<SuperTextFieldState> textKey,
  ) async {
    if (textController.selection.extentOffset == -1) {
      print('Can\'t type text because the text field doesn\'t have a valid selection.');
      return;
    }

    final random = Random();
    for (int i = 0; i < textToType.text.length; ++i) {
      print('Text before typing: ${textController.text.text}. Typing character $i');

      textController.text = textController.text.insertString(
        textToInsert: textToType.text[i], // TODO: support insertion of attributed text
        startOffset: textController.selection.extentOffset,
      );

      final previousSelection = textController.selection;
      textController.selection = TextSelection(
        baseOffset: previousSelection.isCollapsed ? previousSelection.extentOffset + 1 : previousSelection.baseOffset,
        extentOffset: previousSelection.extentOffset + 1,
      );

      await Future.delayed(Duration(milliseconds: random.nextInt(250)));
    }
  }
}

class InsertCaretCommand implements RobotCommand {
  InsertCaretCommand({
    @required this.caretPosition,
  });

  final TextPosition caretPosition;

  @override
  Future<void> run(
    AttributedTextEditingController textController,
    GlobalKey<SuperTextFieldState> textKey,
  ) async {
    textController.selection = TextSelection.collapsed(offset: caretPosition.offset);
  }
}

class SelectTextCommand implements RobotCommand {
  SelectTextCommand({
    @required this.selection,
  });

  final TextSelection selection;

  @override
  Future<void> run(
    AttributedTextEditingController textController,
    GlobalKey<SuperTextFieldState> textKey,
  ) async {
    textController.selection = selection;
  }
}

class PauseCommand implements RobotCommand {
  PauseCommand({
    @required this.duration,
  });

  final Duration duration;

  @override
  Future<void> run(
    AttributedTextEditingController textController,
    GlobalKey<SuperTextFieldState> textKey,
  ) async {
    await Future.delayed(duration);
  }
}
