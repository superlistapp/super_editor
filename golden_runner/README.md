This package contains a tool to run golden tests and update golden files in a docker container.

The command should be run from the root of the package being tested.

## Activate the package:

```console
dart pub global activate --source path ./golden_runner
```

## Run golden tests:

```
# run all tests
flutter pub run ../golden_runner/tool/goldens test

# run a single test
flutter pub run ../golden_runner/tool/goldens test --plain-name "something"

# run all tests in a directory
flutter pub run ../golden_runner/tool/goldens test test_goldens/my_dir

# run a single test in a directory
flutter pub run ../golden_runner/tool/goldens test --plain-name "something" test_goldens/my_dir
```

## Update golden files:

```
# update all goldens
flutter pub run ../golden_runner/tool/goldens update

# update all goldens in a directory
flutter pub run ../golden_runner/tool/goldens update test_goldens/my_dir

# update a single golden
flutter pub run ../golden_runner/tool/goldens update --plain-name "something"

# update a single golden in a directory
flutter pub run ../golden_runner/tool/goldens update --plain-name "something" test_goldens/my_dir
```

## A Hanging Command
Sometimes the golden runner hangs at "building image". It's not clear why this happens, or what
exactly can be done about it. However, to see the Docker image build with log output, you can
run the image build directly.

Run the following command from your project directory:

    docker build -f [path_to]/golden_tester.Dockerfile -t supereditor_golden_tester .

One theory about this hanging command problem is that the process to download the Flutter engine
is taking a very long time.