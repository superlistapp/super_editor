---
title: Horizontal Rules
---
Super Editor ships with support for horizontal rules.

A horizontal rule is a thin horizontal line that spans across the document.

## Horizontal Rule Node
A horizontal rule is represented in a `Document` with a `HorizontalRuleNode`.

```dart
final document = MutableDocument(nodes: [
  HorizontalRuleNode(
    id: Editor.createNodeId(),
  ),
]);
```

## Visual Presentation
By default, `SuperEditor` includes a `HorizontalRuleComponentBuilder`, which builds a
`HorizontalRuleComponent` widget to display within an editor. Therefore, no additional
steps are required to display a horizontal rule.

To change how horizontal rules are rendered in an editor, replace the built in
`HorizontalRuleComponentBuilder` and the `HorizontalRuleComponent` with your own
implementation.

## References
* [`HorizontalRuleNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleNode-class.html) - node for a horizontal rule.
* [`HorizontalRuleComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleComponentBuilder-class.html) - builder for the visual presentation of a horizontal rule.
* [`HorizontalRuleComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleComponentViewModel-class.html) - view model that configures a `HorizontalRuleComponent`.
* [`HorizontalRuleComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleComponent-class.html) - visual presentation of a horizontal rule.
