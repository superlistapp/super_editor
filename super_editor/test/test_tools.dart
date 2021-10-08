import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:logging/logging.dart' as logging;

void groupWithLogging(String description, Level logLevel, Set<logging.Logger> loggers, VoidCallback body) {
  initLoggers(logLevel, loggers);

  group(description, body);

  deactivateLoggers(loggers);
}
