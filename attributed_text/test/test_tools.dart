import 'package:attributed_text/attributed_text.dart';
import 'package:attributed_text/src/logging.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void groupWithLogging(String description, Level logLevel, Set<Logger> loggers, VoidCallback body) {
  initLoggers(logLevel, loggers);

  group(description, body);

  deactivateLoggers(loggers);
}
