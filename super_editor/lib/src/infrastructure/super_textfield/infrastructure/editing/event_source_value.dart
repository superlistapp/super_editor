import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../attributed_text_editing_value.dart';

/// An [AttributedTextEditingValue] that remembers its history and
/// supports undo/redo.
class EventSourcedAttributedTextEditingValue implements AttributedTextEditingValue {
  EventSourcedAttributedTextEditingValue(AttributedTextEditingValue value) : _value = value;

  @override
  AttributedText get text => _value.text;

  @override
  TextSelection get selection => _value.selection;

  @override
  TextRange get composingRegion => _value.composingRegion;

  AttributedTextEditingValue _value = AttributedTextEditingValue(
    text: AttributedText(text: ""),
  );

  /// Executes the given [command] against the current attributed text
  /// editing value, and adds the command to the history stack.
  void execute(AttributedTextEditingValueCommand command) {
    _eraseTheFuture();

    _value = command.execute(_value);
    _history.add(command);
  }

  /// Whether there are any commands in the history stack.
  bool get isUndoable => _history.isNotEmpty;

  final _history = <AttributedTextEditingValueCommand>[];

  /// Pops the top command off the history stack and reverses its
  /// effect on the current attributed text editing value.
  bool undo() {
    if (!isUndoable) {
      return false;
    }

    final command = _history.removeLast();
    _value = command.undo(_value);
    _future.add(command);

    return true;
  }

  /// Whether there are any commands in the future stack.
  bool get isRedoable => _future.isNotEmpty;

  final _future = <AttributedTextEditingValueCommand>[];

  /// Pops the top command off the future stack and re-applies its
  /// effect on the current attributed text editing value.
  bool redo() {
    if (!isRedoable) {
      return false;
    }

    final command = _future.removeLast();
    _value = command.execute(_value);
    _history.add(command);

    return true;
  }

  void _eraseTheFuture() => _future.clear();
}

abstract class AttributedTextEditingValueCommand {
  bool _hasRun = false;

  AttributedTextEditingValue execute(AttributedTextEditingValue previousValue) {
    _ensureNotRun();

    final newValue = doExecute(previousValue);
    _hasRun = true;

    return newValue;
  }

  void _ensureNotRun() {
    if (_hasRun) {
      throw Exception("Tried to run a command for a second time: $runtimeType");
    }
  }

  @protected
  AttributedTextEditingValue doExecute(AttributedTextEditingValue previousValue);

  AttributedTextEditingValue undo(AttributedTextEditingValue currentValue) {
    _ensureRun();

    final oldValue = doUndo(currentValue);
    _hasRun = false;

    return oldValue;
  }

  @protected
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue);

  void _ensureRun() {
    if (!_hasRun) {
      throw Exception("Tried to undo a command that hasn't run: $runtimeType");
    }
  }
}

/// A batch of commands that are executed and undone together.
class BatchCommand extends AttributedTextEditingValueCommand {
  BatchCommand(this._commands);

  final List<AttributedTextEditingValueCommand> _commands;

  @override
  AttributedTextEditingValue doExecute(AttributedTextEditingValue currentValue) {
    AttributedTextEditingValue previousValue = currentValue;
    for (final command in _commands) {
      previousValue = command.execute(previousValue);
    }
    return previousValue;
  }

  @override
  AttributedTextEditingValue doUndo(AttributedTextEditingValue currentValue) {
    AttributedTextEditingValue previousValue = currentValue;
    for (final command in _commands.reversed) {
      previousValue = command.undo(previousValue);
    }
    return previousValue;
  }
}
