---
title: Tasks
---
Super Editor ships with support for tasks.

It's common for apps to include the concept of tasks in a document. A task is an item
that's either complete or incomplete. The user can typically tap on a task to toggle
it between the two. Tasks are popular in productivity apps, as well as issue ticketing
systems, such as when writing a GitHub issue ticket.

## Task Node
A task is represented in a `Document` with a `TaskNode`.

```dart
final document = MutableDocument(nodes: [
  TaskNode(
    id: Editor.createNodeId(),
    text: AttributedText("Task 1"),
    isComplete: true,
  ),
]);
```

Tasks also support a variable level of indent, so that you can define sub-tasks.

## Visual Presentation
By default, `SuperEditor` includes a `TaskComponentBuilder`, which builds a
`TaskComponent` widget to display within an editor. Therefore, no additional
steps are required to display a task.

The easiest way to make stylistic adjustments to the built-in task presentation
is to customize Super Editor's default [stylesheet](/super-editor/guides/styling/style-a-document).

## References
* [`TaskNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskNode-class.html) - node for a task.
* [`TaskComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskComponentBuilder-class.html) - component builder for the visual representation of a task.
* [`TaskViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskComponentViewModel-class.html) - view model that configures an `TaskComponent`.
* [`TaskComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskComponent-class.html) - the visual presentation of a task within a document.
