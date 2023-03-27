# Running tests

In order to run the golden tests, docker must be installed.

## Run golden tests:

```
# run all tests
flutter pub run super_editor:goldens test

# run a single test
flutter pub run super_editor:goldens test --plain-name "something"

# run all tests in a directory
flutter pub run super_editor:goldens test test my_dir

# run a single test in a directory
flutter pub run super_editor:goldens test --plain-name "something" my_dir
```

## Update golden files:

```
# update all goldens
flutter pub run super_editor:goldens update

# update all goldens in a directory
flutter pub run super_editor:goldens update my_dir

# update a single golden
flutter pub run super_editor:goldens update --plain-name "something"

# update a single golden in a directory
flutter pub run super_editor:goldens update --plain-name "something" my_dir
```
