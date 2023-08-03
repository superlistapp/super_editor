# Running tests

In order to run the golden tests, docker must be installed. Activate the golden_runner with:

```console
dart pub global activate --source path ../golden_runner
```

## Run golden tests:

```
# run all tests
goldens test

# run a single test
goldens test --plain-name "something"

# run all tests in a directory
goldens test test my_dir

# run a single test in a directory
goldens test --plain-name "something" my_dir
```

## Update golden files:

```
# update all goldens
goldens update

# update all goldens in a directory
goldens update my_dir

# update a single golden
goldens update --plain-name "something"

# update a single golden in a directory
goldens update --plain-name "something" my_dir
```
