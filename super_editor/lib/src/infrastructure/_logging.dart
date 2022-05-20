// ignore_for_file: avoid_print

import 'package:logging/logging.dart' as logging;

class LogNames {
  static const editor = 'editor';
  static const editorGestures = 'editor.gestures';
  static const editorKeys = 'editor.keys';
  static const editorIme = 'editor.ime';
  static const editorLayout = 'editor.layout';
  static const editorDocument = 'editor.document';
  static const editorCommonOps = 'editor.ops';
  static const editorBlockquote = 'editor.blockquote';
  static const editorBoxComponent = 'editor.box_component';
  static const editorListItems = 'editor.listItems';
  static const editorMultiNodeEditing = 'editor.multi_node_editing';
  static const editorTextTools = 'editor.text_tools';

  static const textField = 'textfield';
  static const scrollingTextField = 'textfield.scrolling';
  static const imeTextField = 'textfield.ime';
  static const androidTextField = 'textfield.android';
  static const iosTextField = 'textfield.ios';

  static const infrastructure = 'infrastructure';
  static const attributions = 'infrastructure.attributions';
}

final editorLog = logging.Logger(LogNames.editor);
final editorGesturesLog = logging.Logger(LogNames.editorGestures);
final editorKeyLog = logging.Logger(LogNames.editorKeys);
final editorImeLog = logging.Logger(LogNames.editorIme);
final editorLayoutLog = logging.Logger(LogNames.editorLayout);
final editorDocLog = logging.Logger(LogNames.editorDocument);
final editorOpsLog = logging.Logger(LogNames.editorCommonOps);
final editorBlockquoteLog = logging.Logger(LogNames.editorBlockquote);
final editorBoxComponentLog = logging.Logger(LogNames.editorBoxComponent);
final editorListItemsLog = logging.Logger(LogNames.editorListItems);
final editorMultiNodeEditingLog = logging.Logger(LogNames.editorMultiNodeEditing);
final editorTextToolsLog = logging.Logger(LogNames.editorTextTools);

final textFieldLog = logging.Logger(LogNames.textField);
final scrollingTextFieldLog = logging.Logger(LogNames.scrollingTextField);
final imeTextFieldLog = logging.Logger(LogNames.imeTextField);
final androidTextFieldLog = logging.Logger(LogNames.androidTextField);
final iosTextFieldLog = logging.Logger(LogNames.iosTextField);

final infrastructureLog = logging.Logger(LogNames.infrastructure);
final attributionsLog = logging.Logger(LogNames.attributions);

final _activeLoggers = <logging.Logger>{};

void initAllLogs(logging.Level level) {
  initLoggers(level, {logging.Logger.root});
}

void initLoggers(logging.Level level, Set<logging.Logger> loggers) {
  logging.hierarchicalLoggingEnabled = true;

  for (final logger in loggers) {
    if (!_activeLoggers.contains(logger)) {
      print('Initializing logger: ${logger.name}');
      logger
        ..level = level
        ..onRecord.listen(printLog);

      _activeLoggers.add(logger);
    }
  }
}

void deactivateLoggers(Set<logging.Logger> loggers) {
  for (final logger in loggers) {
    if (_activeLoggers.contains(logger)) {
      print('Deactivating logger: ${logger.name}');
      logger.clearListeners();

      _activeLoggers.remove(logger);
    }
  }
}

void printLog(logging.LogRecord record) {
  print(
      '(${record.time.second}.${record.time.millisecond.toString().padLeft(3, '0')}) ${record.loggerName} > ${record.level.name}: ${record.message}');
}
