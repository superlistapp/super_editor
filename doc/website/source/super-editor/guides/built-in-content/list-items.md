---
title: List Items
---
Super Editor ships with support for ordered and unordered list items.

## List Item Node
List items are represented in `Document`s with `ListItemNode`s.

To represent an unordered list item, use the `ListItemNode.unordered()` constructor.

```dart
final document = MutableDocument(nodes: [
  ListItemNode.unordered(
    id: Editor.createNodeId(),
    text: AttributedText("An unordered list item"),
  ),
]);
```

To represent an ordered list item, use the `ListItemNode.ordered()` constructor.

```dart
final document = MutableDocument(nodes: [
  ListItemNode.ordered(
    id: Editor.createNodeId(),
    text: AttributedText("An unordered list item"),
  ),
]);
```

Both ordered and unordered list items support a variable indent level, allowing for
lists within lists.

## Visual Presentation
By default, `SuperEditor` includes an `UnorderedListItemComponentBuilder`, and an
`OrderedListItemComponentBuilder`, which builds widgets for the respective types of
list items. Therefore, no additional steps are required to display list items.

The easiest way to make stylistic adjustments to the built-in list item presentation
is to customize Super Editor's default [stylesheet](/super-editor/guides/styling/style-a-document).

## References
* [`ListItemNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ListItemNode-class.html) - node for ordered and unordered list items.
* [`ListItemComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ListItemComponentBuilder-class.html) - component builder for the visual representation of a list item.
* [`OrderedListItemComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/OrderedListItemComponentViewModel-class.html) - view model that configures an `OrderedListItemComponent`.
* [`OrderedListItemComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/OrderedListItemComponent-class.html) - the visual presentation of an ordered list item within a document.
* [`UnorderedListItemComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/UnorderedListItemComponentViewModel-class.html) - view model that configures an `UnorderedListItemComponent`.
* [`UnorderedListItemComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/UnorderedListItemComponent-class.html) - the visual presentation of an unordered list item within a document.