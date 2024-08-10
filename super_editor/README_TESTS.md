# Running tests

In order to run the golden tests, Docker must be installed. See docs for installing Docker Desktop:
- macOS: https://docs.docker.com/desktop/install/mac-install/
- Linux: https://docs.docker.com/desktop/install/linux-install/
- Windows: https://docs.docker.com/desktop/install/windows-install/

Activate the golden_runner with:

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
goldens test test_goldens/my_dir

# run a single test in a directory
goldens test --plain-name "something" test_goldens/my_dir
```

## Update golden files:

```
# update all goldens
goldens update

# update all goldens in a directory
goldens update test_goldens/my_dir

# update a single golden
goldens update --plain-name "something"

# update a single golden in a directory
goldens update --plain-name "something" test_goldens/my_dir
```
