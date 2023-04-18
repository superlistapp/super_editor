# Running tests

In order to run the golden tests, docker must be installed.

## Run golden tests:

```
# run all tests
flutter pub run tool/goldens test

# run a single test
flutter pub run tool/goldens test --plain-name "something"

# run all tests in a directory
flutter pub run tool/goldens test test my_dir

# run a single test in a directory
flutter pub run tool/goldens test --plain-name "something" my_dir
```

## Update golden files:

```
# update all goldens
flutter pub run tool/goldens update

# update all goldens in a directory
flutter pub run tool/goldens update my_dir

# update a single golden
flutter pub run tool/goldens update --plain-name "something"

# update a single golden in a directory
flutter pub run tool/goldens update --plain-name "something" my_dir
```
