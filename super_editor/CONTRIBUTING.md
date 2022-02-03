# CONTRIBUTING

If you're interested in contributing to `super_editor`, please adhere to the following guidelines.

## Project principles

`super_editor` is intended to be used by an unbounded variety of apps for editing and rendering documents. Therefore, `super_editor` is built with certain principles in mind. These principles are to be maintained throughout the development process.

**Principles**

* Aggressive composition: Build small, effective tools that are designed to work with other small tools to achieve broader functionality.
* Establish strong encapsulation boundaries: Keep unrelated concepts completely independent (including transitive dependencies).
* If you can't see it, it doesn't exist: Every feature should have a runnable demo.
* Tests are not optional: Every feature must be tested, and those tests must run in CI.

**A few specifics**

* Classes and behaviors that are required for `super_editor` but are not specific to the project goals should be placed within the `infrastructure` package.
* The `core` package should only include the project's fundamental abstractions. Nothing in the `core` package should depend on any code outside the `core` package, except (rarely) something in the `infrastructure` package.
* Meaningless names like "manager", "helper", "utility", "data", "model" will not be accepted unless there is a strong contextual reason to do so.
* If the term "controller" is used, it must specifically refer to the Flutter concept of a controller.
* `super_editor` is a Dart-only solution. Do not contribute platform code.

## Bug tickets must include reproduction steps

Every development machine, environment, and project configuration is unique. It can be difficult or impossible to reproduce bugs without appropriate guidance from the person who found the bug.

If you file a bug, you must include **minimal reproduction steps** so that project maintainers can reproduce the bug. A "minimal" set of reproduction steps is a set of steps that include details that are needed to reproduce the bug and nothing more.

Bug tickets that lack minimal reproduction steps will be closed.

## Feature requests must include the motivation

Developers often see a problem and then immediately jump to a solution. But jumping to a solution prevents project maintainers from considering the broader context of a given problem.

All feature request tickets must be framed in terms of a motivation, rather than a specific change to the project.

## Consider writing a proposal before writing an implementation

`super_editor` is a relatively complicated project, maintaining many competing goals and behaviors. It's easy to lose the forest for the trees when working on a new feature.

Rather than jump directly into an implementation, consider drafting a proposal for the project maintainers to review. The proposal process might discover issues or conflicts that will save you considerable time and frustration.

## Pull requests must include effective tests
**File an issue ticket before working on code!** Issue tickets are where we recognize problems and discuss solutions. Don't invest your time in a PR before the team tells you that your solution is likely to be accepted. Otherwise, you might waste your time.

Text editing and document rendering involve a large number of interrelated behaviors. It's extremely easy to make a change that fixes one bug but then creates another bug.

Every change to the project must include effective tests.

An effective test meets the following criteria:

 * Uses the lowest level test tools that accomplish the testing goals.
   * Dart language tests for non-UI behaviors. Unit tests, when feasible.
   * Widget tests for user interactions.
   * Golden tests for visual goals.
   * Integration tests as a last resort. They take much longer to run and they depend on specific platforms.
 * Doesn't test things that are already tested (avoid useless redundancy).
 * Does test all edge cases.
 * Is grouped appropriately.
 * Is named appropriately.
 * Is readable and comprehensible by project maintainers.
