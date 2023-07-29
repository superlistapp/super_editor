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

    late String testDirOrTestFileName;
    late String testBaseDirectory;

    if (rest.isNotEmpty) {
      // An argument was passed after the command options. For example, tool/goldens test my_test_dir.
      // Use the first argument after the command options as the test directory and remove it from the rest.
      testDirOrTestFileName = rest.removeAt(0);

      if (testDirOrTestFileName.endsWith('.dart')) {
        // A test file was given.
        // Extract the directory name so we can list the sub-directories.
        testBaseDirectory = path.dirname(testDirOrTestFileName);
      } else {
        testBaseDirectory = testDirOrTestFileName;
      }
    } else {
      testDirOrTestFileName = 'test_goldens';
      testBaseDirectory = testDirOrTestFileName;
    }

    final dirs = _findAllTestDirs(testBaseDirectory);

    final volumeMappings = _generateFailureDirMappings(dirs);

    // Runs the container.
    //
    // --rm: Removes the container when it exits.
    //
    // --workdir: Sets the working directory to /super_editor/super_editor in the container.
    await _runProcess(
      exe: 'docker',
      arguments: [
        'run',
        '--rm',
        ...volumeMappings,
        '--workdir',
        '/super_editor/super_editor',
        'supereditor_golden_tester',
        'flutter',
        'test',
        testDirOrTestFileName,
        ...rest,
        ...cmdArguments,
      ],
      description: 'Golden tests',
    );

    // Mapping the failure directories causes them to be created automatically, even without any failing test.
    // Remove all the empty failure directories.
    for (final dirName in dirs) {
      final dir = Directory('$dirName/failures');
      if (dir.existsSync() && dir.listSync().isEmpty) {
        dir.deleteSync();
      }
    }
  }

  /// Returns a list with all volume mappings for the test failure directories.
  ///
  /// This mappings are used so when a failure happens, the failure images are save in the host OS.
  List<String> _generateFailureDirMappings(List<String> testDirs) {
    final mapppings = <String>[];

    for (final dir in testDirs) {
      mapppings.add('-v');
      mapppings.add('${Directory.current.path}/$dir/failures:/super_editor/super_editor/$dir/failures');
    }

    return mapppings;
  }

  /// Returns all sub-directories inside a root test directory.
  ///
  /// Ignores "goldens" and "failures" directories.
  List<String> _findAllTestDirs(String rootTestDir) {
    final dir = Directory(rootTestDir);
    final subDirs = dir
        .listSync(recursive: true) //
        .whereType<Directory>()
        // Ensure we use linux path separator.
        .map((e) => e.path.replaceAll(path.separator, '/'))
        .where((e) => !e.endsWith('goldens') && !e.endsWith('failures'))
        .toList();
    return [rootTestDir, ...subDirs];
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

    late String testDirOrTestFileName;
    late String testBaseDirectory;

    if (rest.isNotEmpty) {
      // An argument was passed after the command options. For example, tool/goldens test my_test_dir.
      // Use the first argument after the command options as the test directory and remove it from the rest.
      testDirOrTestFileName = rest.removeAt(0);

      if (testDirOrTestFileName.endsWith('.dart')) {
        // A test file was given.
        // Extract the directory name so we can list the sub-directories.
        testBaseDirectory = path.dirname(testDirOrTestFileName);
      } else {
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
    // --workdir: Sets the working directory to /super_editor/super_editor in the container.
    await _runProcess(
      exe: 'docker',
      arguments: [
        'run',
        '--rm',
        '-v',
        '${Directory.current.path}/$testBaseDirectory:/super_editor/super_editor/$testBaseDirectory',
        '--workdir',
        '/super_editor/super_editor',
        'supereditor_golden_tester',
        'flutter',
        'test',
        '--update-goldens',
        testDirOrTestFileName,
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
    // We need to use the repository root as the working directory to be able to copy all of the files
    // in this repository, not just the super_editor sub-directory.
    workingDirectory: '../',
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
