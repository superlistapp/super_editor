import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:args/command_runner.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;

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
/// Usage: `flutter pub run super_editor:goldens test <options> <directory>`
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
    final rest = [...args.rest];

    late String testDirectory;
    if (rest.isNotEmpty) {
      testDirectory = rest.removeAt(0);
    } else {
      testDirectory = 'test_goldens';
    }

    final mapppings = _findTestFailureDirMappings(testDirectory);

    // Runs the container.
    //
    // --rm: Removes the container when it exists.
    await _runProcess(
      exe: 'docker',
      arguments: [
        'run',
        '--rm',
        ...mapppings,
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
/// Usage: `flutter pub run super_editor:goldens update <options> <directory>`
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
    final rest = [...args.rest];

    late String testDirectory;
    if (rest.isNotEmpty) {
      testDirectory = rest.removeAt(0);
    } else {
      testDirectory = 'test_goldens';
    }

    //final mapppings = _findTestFailureDirMappings(testDirectory);

    // Runs the container.
    //
    // --rm: Removes the container when it exists.
    //
    // -v: Mounts the repo root dir of the host machine into /build directory on the container.
    // We need to mount the root to be able to depend on the other packages using the local path.
    //
    // --workdir: Sets the working directory to /build/super_editor in the container.
    await _runProcess(
      exe: 'docker',
      arguments: [
        'run',
        '--rm',
        //...mapppings,
        '-v',
        '${Directory.current.path}/$testDirectory:/super_editor/super_editor/$testDirectory',
        // '-v',
        // '${Directory.current.path}/../:/build',
        // '--workdir',
        // '/build/super_editor',
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
    workingDirectory: '../',
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
  final process = await Process.start(
    exe,
    arguments,
    workingDirectory: workingDirectory,
  );

  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    throw Exception('$description failed');
  }
}

List<String> _findTestFailureDirMappings(String rootTestDir) {
  final mapppings = <String>[
    '-v',
    '${Directory.current.path}/$rootTestDir/failures:/super_editor/super_editor/$rootTestDir/failures/'
  ];

  final dirs = _findAllTestDirs(rootTestDir);
  for (final dir in dirs) {
    mapppings.add('-v');
    mapppings.add('${Directory.current.path}/$dir/failures:/super_editor/super_editor/$dir/failures');
  }
  return mapppings;
}

List<String> _findAllTestDirs(String rootTestDir) {
  final dir = Directory(rootTestDir);
  return dir
      .listSync(recursive: true) //
      .whereType<Directory>()
      // Ensure we use linux path separator.
      .map((e) => e.path.replaceAll(path.separator, '/'))
      .where((e) => !e.endsWith('goldens') && !e.endsWith('failures'))
      .toList();
}
