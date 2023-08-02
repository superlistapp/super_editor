import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:args/command_runner.dart';
import 'package:golden_runner/golden_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner("goldens", "A tool to run and update golden tests using docker")
    ..addCommand(GoldenTestCommand())
    ..addCommand(UpdateGoldensCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    stdout.write(e);
  }
}
