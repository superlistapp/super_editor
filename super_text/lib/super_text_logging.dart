// ignore_for_file: avoid_print

import 'package:logging/logging.dart';
export 'package:logging/logging.dart';

class LogNames {
  static const errors = 'super_text.errors';
  static const builds = 'super_text.builds';
  static const layout = 'super_text.layout';
  static const typingRobot = 'super_text.robot';
}

// Errors that don't fit into other loggers
final errorsLog = Logger(LogNames.errors);
final buildsLog = Logger(LogNames.builds);
final layoutLog = Logger(LogNames.layout);
final robotLog = Logger(LogNames.typingRobot);

final _activeLoggers = <Logger>{};

void initAllLogs(Level level) {
  initLoggers(level, {Logger.root});
}

void initLoggers(Level level, Set<Logger> loggers) {
  hierarchicalLoggingEnabled = true;

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

void deactivateLoggers(Set<Logger> loggers) {
  for (final logger in loggers) {
    if (_activeLoggers.contains(logger)) {
      print('Deactivating logger: ${logger.name}');
      logger.clearListeners();

      _activeLoggers.remove(logger);
    }
  }
}

void printLog(LogRecord record) {
  print(
      '(${record.time.second}.${record.time.millisecond.toString().padLeft(3, '0')}) ${record.loggerName} > ${record.level.name}: ${record.message}');
}
