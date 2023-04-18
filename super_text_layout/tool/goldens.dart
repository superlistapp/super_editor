import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:args/command_runner.dart';

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

/// A [Command] which runs golden tests.
///
/// Usage: `flutter pub run super_text_layout:goldens test <options> <directory>`
///
/// Options:
///
/// `--plain-name "test-name"`: Runs only the tests containing the given value in the test name.
///
/// The directory is optional.
class GoldenTestCommand extends Command {
  GoldenTestCommand() {
    argParser.addOption(
      'plain-name',
      help: 'A plain-text substring of the names of tests to run',
    );
  }

  @override
  String get name => 'test';

  @override
  String get description => 'Runs golden tests';

  @override
  Future<void> run() async {
    final args = argResults!;

    // Builds the image used to run the container.
    // We can build the image even if it already exists.
    // Docker will cache each step used in the Dockerfile, so subsequent builds will be faster.
    await _buildDockerImage();

    // Arguments that are placed after 'flutter test test_goldens'.
    final cmdArguments = [];

    final name = args['plain-name'];
    if (name is String) {
      cmdArguments
        ..add('--plain-name')
        ..add(name);
    }

    stdout.writeln('Running golden tests');

    // Other arguments passed at the end of the command.
    // For example, the test directory.
    final rest = args.rest;

    final testDirectory = rest.isEmpty //
        ? 'test_goldens'
        : '';

    // Runs the container.
    //
    // --rm: Removes the container when it exists.
    //
    // -v: Mounts the repo root dir of the host machine into /build directory on the container.
    // We need to mount the root to be able to depend on the other packages using the local path.
    //
    // --workdir: Sets the working directory to /build/super_text_layout in the container.
    await _runProcess(
      exe: 'docker',
      arguments: [
        'run',
        '--rm',
        '-v',
        '${Directory.current.path}/../:/build',
        '--workdir',
        '/build/super_text_layout',
        'supereditor_golden_tester',
        'flutter',
        'test',
        testDirectory,
        ...rest,
        ...cmdArguments,
      ],
      description: 'Golden tests',
    );
  }
}

/// A [Command] which updates golden files.
///
/// Usage: `flutter pub run super_text_layout:goldens update <options> <directory>`
///
/// Options:
///
/// `--plain-name "test-name"`: Update only the tests containing the given value in the test name.
///
/// The directory is optional.
class UpdateGoldensCommand extends Command {
  UpdateGoldensCommand() {
    argParser.addOption(
      'plain-name',
      help: 'A plain-text substring of the names of tests to run',
    );
  }

  @override
  String get description => 'Updates golden files';

  @override
  String get name => 'update';

  @override
  Future<void> run() async {
    final args = argResults!;

    // Builds the image used to run the container.
    // We can build the image even if it already exists.
    // Docker will cache each step used in the Dockerfile, so subsequent builds will be faster.
    await _buildDockerImage();

    // Arguments that are placed after 'flutter test test_goldens'.
    final cmdArguments = [];

    final name = args['plain-name'];
    if (name is String) {
      cmdArguments
        ..add('--plain-name')
        ..add(name);
    }

    stdout.writeln('Updating golden files');

    // Other arguments passed at the end of the command.
    // For example, the test directory.
    final rest = args.rest;

    final testDirectory = rest.isEmpty //
        ? 'test_goldens'
        : '';

    // Runs the container.
    //
    // --rm: Removes the container when it exists.
    //
    // -v: Mounts the repo root dir of the host machine into /build directory on the container.
    // We need to mount the root to be able to depend on the other packages using the local path.
    //
    // --workdir: Sets the working directory to /build/super_text_layout in the container.
    await _runProcess(
      exe: 'docker',
      arguments: [
        'run',
        '--rm',
        '-v',
        '${Directory.current.path}/../:/build',
        '--workdir',
        '/build/super_text_layout',
        'supereditor_golden_tester',
        'flutter',
        'test',
        '--update-goldens',
        testDirectory,
        ...rest,
        ...cmdArguments,
      ],
      description: 'Update goldens',
    );
  }
}

/// Builds a linux docker image to run the tests.
///
/// The golden_tester.Dockerfile is used to build this image.
Future<void> _buildDockerImage() async {
  stdout.write('building image');

  await _runProcess(
    exe: 'docker',
    arguments: [
      'build',
      '-f',
      './golden_tester.Dockerfile',
      '-t',
      'supereditor_golden_tester',
      '.',
    ],
    description: 'Image build',
  );
}

/// Runs [exe] with the given [arguments].
///
/// The child process stdout and stderr are written to the current process stdout.
///
/// Throws and exception if the process exists with a non-zero exit code.
Future<void> _runProcess({
  required String exe,
  required List<String> arguments,
  required String description,
  String? workingDirectory,
}) async {
  final result = await Process.run(
    exe,
    arguments,
    workingDirectory: workingDirectory,
  );

  if (result.stdout != null) {
    stdout.write(result.stdout);
  }

  if (result.stderr != null) {
    stdout.write(result.stderr);
  }

  if (result.exitCode != 0) {
    throw Exception('$description failed');
  }
}
