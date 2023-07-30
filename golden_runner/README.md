This package contains commands to run golden tests and update golden files.

The [args package](https://pub.dev/packages/args) must be used to run the commands.

To use the commands contained in this package, add a dart file inside the `tool` directory at the root of your flutter project.

Example:

```dart
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
```
