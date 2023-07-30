import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:golden_runner/golden_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner("goldens", "A tool to run and update golden tests using docker")
    ..addCommand(GoldenTestCommand(packageDirectory: 'super_editor'))
    ..addCommand(UpdateGoldensCommand(packageDirectory: 'super_editor'));

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    stdout.write(e);
  }
}
