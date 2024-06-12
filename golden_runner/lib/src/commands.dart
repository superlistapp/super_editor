import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

/// A [Command] which runs golden tests.
///
/// The command run the tests in a Linux Docker container. It expects to be running in a "golden_tester" directory.
///
/// Usage: `flutter pub run <executable> test <options> <target>`
///
/// Options:
///
/// `--plain-name "test-name"`: Runs only the tests containing the given value in the test name.
///
/// The target can be a directory or a file. This argument is optional.
///
/// This is intended to be added as an [CommandRunner] command.
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

    // The tool must run from the root of the package being tested.
    // For example, /super_editor/super_text_layout.
    // We take the last part of the directory as the package directory.
    final packageDirectory = path.split(Directory.current.path).last;

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

    late String testDirOrTestFileName;
    late String testBaseDirectory;

    if (rest.isNotEmpty) {
      // An argument was passed after the command options.
      // For example, in "flutter pub run tool/goldens test my_test_dir", "my_test_dir" is the first argument
      // after the command.
      // Use the first argument after the command options as the test directory or test file name
      // and remove it from the rest.
      testDirOrTestFileName = rest.removeAt(0);

      if (path.extension(testDirOrTestFileName).isNotEmpty) {
        // A test file was given.
        // Extract the directory name so we can list the sub-directories.
        testBaseDirectory = path.dirname(testDirOrTestFileName);
      } else {
        // A test directory was given.
        // Don't try to extract the directory name because it can return an empty string if it's the root directory.
        // For example, passing "test_goldens" to dirname would return "".
        testBaseDirectory = testDirOrTestFileName;
      }
    } else {
      testDirOrTestFileName = 'test_goldens';
      testBaseDirectory = testDirOrTestFileName;
    }

    final dirs = _findAllTestDirectories(testBaseDirectory);

    final volumeMappings = _generateFailureDirectoriesMappings(packageDirectory, dirs);

    // Runs the container.
    //
    // --rm: Removes the container when it exits.
    //
    // --workdir: Sets the process working directory to the given package directory in the container.
    await _runProcess(
      executable: 'docker',
      arguments: [
        'run',
        '--rm',
        ...volumeMappings,
        '--workdir',
        '/golden_tester/$packageDirectory',
        'supereditor_golden_tester',
        'flutter',
        'test',
        testDirOrTestFileName,
        ...rest,
        ...cmdArguments,
      ],
      description: 'Golden tests',
      throwOnError: false,
    );

    // After running the tests, we don't need the image anymore. Remove it.
    await _removeDockerImage();

    // Mapping the failure directories causes them to be created automatically, even without any failing test.
    // Remove all the empty failure directories.
    for (final dirName in dirs) {
      final dir = Directory('$dirName/failures');
      if (dir.existsSync() && dir.listSync().isEmpty) {
        dir.deleteSync();
      }
    }
  }

  /// Returns a list of docker command line arguments to configure the volume mappings for the test failure directories.
  ///
  /// [testDirectories] must be a list of relative paths to the working directory.
  ///
  /// This mappings are used so when a failure happens, the failure images are save in the host OS.
  List<String> _generateFailureDirectoriesMappings(String packageDirectory, List<String> testDirectories) {
    final mappings = <String>[];

    for (final dir in testDirectories) {
      mappings.add('-v');
      mappings.add('${Directory.current.path}/$dir/failures:/golden_tester/$packageDirectory/$dir/failures');
    }

    return mappings;
  }

  /// Returns a list of sub-directories inside a root test directory as relative paths to the working directory.
  ///
  /// For example, "test_goldens/editor", "test_goldens/components".
  ///
  /// Ignores "failures" directories.
  List<String> _findAllTestDirectories(String rootTestDir) {
    final dir = Directory(rootTestDir);
    final subDirs = dir
        .listSync(recursive: true) //
        .whereType<Directory>()
        // Ensure we use linux path separator.
        // The tool can run in a host OS which uses a different path separator.
        // Without this, the volume ma
        .map((e) => e.path.replaceAll(path.separator, '/'))
        .where((e) => !e.endsWith('failures'))
        .toList();
    return [rootTestDir, ...subDirs];
  }
}

/// A [Command] which updates golden files.
///
/// The command run the tests in a Linux Docker container. It expects to be running in a "golden_tester" directory.
///
/// Usage: `flutter pub run <executable> update <options> <target>`
///
/// Options:
///
/// `--plain-name "test-name"`: Update only the tests containing the given value in the test name.
///
/// The target can be a directory or a file. This argument is optional.
///
/// This is intended to be added as an [CommandRunner] command.
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

    // The tool must run from the root of the package being tested.
    // For example, /super_editor/super_text_layout.
    // We take the last part of the directory as the package directory.
    final packageDirectory = path.split(Directory.current.path).last;

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

    late String testDirOrTestFileName;
    late String testBaseDirectory;

    if (rest.isNotEmpty) {
      // An argument was passed after the command options.
      // For example, in "flutter pub run tool/goldens test my_test_dir", "my_test_dir" is the first argument
      // after the command.
      // Use the first argument after the command options as the test directory or test file name
      // and remove it from the rest.
      testDirOrTestFileName = rest.removeAt(0);

      if (path.extension(testDirOrTestFileName).isNotEmpty) {
        // A test file was given.
        // Extract the directory name so we can list the sub-directories.
        testBaseDirectory = path.dirname(testDirOrTestFileName);
      } else {
        // A test directory was given.
        // Don't try to extract the directory name because it can return an empty string if it's the root directory.
        // For example, passing "test_goldens" to dirname would return "".
        testBaseDirectory = testDirOrTestFileName;
      }
    } else {
      testDirOrTestFileName = 'test_goldens';
      testBaseDirectory = testDirOrTestFileName;
    }

    // Runs the container.
    //
    // --rm: Removes the container when it exits.
    //
    // -v: Mounts the directory containing the tests of the host machine into the container.
    // This is used to write the new golden files directly on the host OS.
    //
    // --workdir: Sets the working directory to /super_editor/super_text_layout in the container.
    await _runProcess(
      executable: 'docker',
      arguments: [
        'run',
        '--rm',
        '-v',
        '${Directory.current.path}/$testBaseDirectory:/golden_tester/$packageDirectory/$testBaseDirectory',
        '--workdir',
        '/golden_tester/$packageDirectory',
        'supereditor_golden_tester',
        'flutter',
        'test',
        '--update-goldens',
        testDirOrTestFileName,
        ...rest,
        ...cmdArguments,
      ],
      description: 'Update goldens',
      throwOnError: false,
    );

    // After running the tests, we don't need the image anymore. Remove it.
    await _removeDockerImage();
  }
}

/// Builds a linux docker image to run the tests.
///
/// The golden_tester.Dockerfile is used to build this image.
Future<void> _buildDockerImage() async {
  stdout.writeln('building image');

  await _runProcess(
    executable: 'docker',
    arguments: [
      'build',
      '-f',
      './golden_tester.Dockerfile',
      '-t',
      'supereditor_golden_tester',
      '.',
    ],
    // We need to use the repository root as the working directory to be able to copy all of the files
    // in this repository, not just the package directory.
    workingDirectory: '../',
    description: 'Image build',
  );
}

/// Removes the image built by the golden tester.
Future<void> _removeDockerImage() async {
  await _runProcess(
    executable: 'docker',
    arguments: [
      'image', 'rm', //
      '-f',
      'supereditor_golden_tester',
    ],
    description: 'Removing image',
    throwOnError: false,
  );
}

/// Runs [executable] with the given [arguments].
///
/// [executable] could be an absolute path or it could be resolved from the PATH.
///
/// The [arguments] must contain any modifiers, like `-`, `--` or `/`.
///
/// Use [workingDirectory] to set the working directory for the process.
///
/// The child process stdout and stderr are written to the current process stdout.
///
/// If [throwOnError] is `true`, throws an exception if the process exits with a non-zero exit code.
///
/// If [throwOnError] is `false`, the function returns the exit code.
Future<int> _runProcess({
  required String executable,
  required List<String> arguments,
  required String description,
  String? workingDirectory,
  bool throwOnError = true,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );

  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;

  if (exitCode != 0 && throwOnError) {
    throw Exception('$description failed');
  }

  return exitCode;
}
