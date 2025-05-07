---
title: Built-In Content
---
Super Editor ships with a variety of document content types and visual document components.

The term "node" refers to a logical piece of information, without any opinion about
how it's rendered, e.g., `ParagraphNode`.

The term "component" refers to a widget that renders the UI for a "node".

## Text
Super Editor includes a variety of `TextNode`s, configurations, and visual presentations.

### Paragraphs
The most common `DocumentNode` for text is a `ParagraphNode`. 

`ParagraphNode`s support paragraphs, headers, and blockquotes.

The following sample shows how to create each type of `ParagraphNode`, as supported by
Super Editor out of the box.

```dart
final document = MutableDocument(nodes: [
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("This is a paragraph"),
  ),
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("This is a header 1"),
    metadata: {
      NodeMetadata.blockType: header1Attribution,
    }
  ),
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("This is a blockquote"),
    metadata: {
      NodeMetadata.blockType: blockquoteAttribution,
    }
  ),
]);
```

#### References
 * [`TextNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TextNode-class.html) - base node for all text nodes.
 * [`ParagraphNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphNode-class.html) - node for paragraphs, headers, blockquotes, and code.
 * [`ParagraphComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponentBuilder-class.html) - component builder for the visual representation of a paragraph. 
 * [`ParagraphComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponentViewModel-class.html) - view model that configures a `ParagraphComponent`.
 * [`ParagraphComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponent-class.html) - the visual presentation of a paragraph within a document.
 * [`BlockquoteComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/BlockquoteComponentBuilder-class.html) - component builder for the visual representation of a blockquote.
 * [`BlockquoteComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/BlockquoteComponentViewModel-class.html) - view model that configures a `BlockquoteComponent`.
 * [`BlockquoteComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/BlockquoteComponent-class.html) - the visual presentation of a blockquote within a document.

### List Items
List Items share the same base type as `ParagraphNode` (`TextNode`), but they have their own 
`DocumentNode` type because they include two specific types (ordered vs unordered), they add the 
concept of grouping, and they render with a special leading indicator.

The following code sample shows a variety of list item configurations.

```dart
final document = MutableDocument(nodes: [
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("Unordered list"),
    metadata: {
      NodeMetadata.blockType: header1Attribution,
    }
  ),
  ListItemNode.unordered(
    id: Editor.createNodeId(),
    text: AttributedText("The first unordered list item"),
  ),
  ListItemNode.unordered(
    id: Editor.createNodeId(),
    text: AttributedText("The first item in an indented list"),
    indent: 1,
  ),
  ListItemNode.unordered(
    id: Editor.createNodeId(),
    text: AttributedText("The second item in an indented list"),
    indent: 1,
  ),
  ListItemNode.unordered(
    id: Editor.createNodeId(),
    text: AttributedText("The second list item at the top level of the list"),
    indent: 1,
  ),

  ParagraphNode(
      id: Editor.createNodeId(),
      text: AttributedText("Ordered list"),
      metadata: {
        NodeMetadata.blockType: header1Attribution,
      }
  ),
  ListItemNode.ordered(
    id: Editor.createNodeId(),
    text: AttributedText("The first ordered list item"),
  ),
  ListItemNode.ordered(
    id: Editor.createNodeId(),
    text: AttributedText("The first item in an indented list"),
    indent: 1,
  ),
  ListItemNode.ordered(
    id: Editor.createNodeId(),
    text: AttributedText("The second item in an indented list"),
    indent: 1,
  ),
  ListItemNode.ordered(
    id: Editor.createNodeId(),
    text: AttributedText("The second list item at the top level of the list"),
    indent: 1,
  ),
]);
```

#### References
* [`ListItemNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ListItemNode-class.html) - node for ordered and unordered list items.
* [`ListItemComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ListItemComponentBuilder-class.html) - component builder for the visual representation of a list item.
* [`ListItemComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ListItemComponentViewModel-class.html) - view model that configures an `OrderedListItemComponent` and `UnorderedListItemComponent`.
* [`OrderedListItemComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/OrderedListItemComponent-class.html) - the visual presentation of an ordered list item within a document.
* [`UnorderedListItemComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/UnorderedListItemComponent-class.html) - the visual presentation of an unordered list item within a document.

### Tasks
It's common for apps to include the concept of tasks in a document. A task is an item
that's either complete or incomplete. The user can typically tap on a task to toggle
it between the two. Tasks are popular in productivity apps, as well as issue ticketing
systems, such as when writing a GitHub issue ticket.

Super Editor includes a `TaskNode`.

```dart
final document = MutableDocument(nodes: [
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("Tasks"),
    metadata: {
      NodeMetadata.blockType: header1Attribution,
    }
  ),
  TaskNode(
    id: Editor.createNodeId(),
    text: AttributedText("Task 1"),
    isComplete: true,
  ),
  TaskNode(
    id: Editor.createNodeId(),
    text: AttributedText("Task 2"),
    isComplete: false,
  ),
  TaskNode(
    id: Editor.createNodeId(),
    text: AttributedText("Task 3"),
    isComplete: false,
  ),
]);
```

#### References
* [`TaskNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskNode-class.html) - node for a task.
* [`TaskComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskComponentBuilder-class.html) - component builder for the visual representation of a task.
* [`TaskViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskComponentViewModel-class.html) - view model that configures an `TaskComponent`.
* [`TaskComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/TaskComponent-class.html) - the visual presentation of a task within a document.

## Images
Images are encoded in `ImageNode`s and and rendered with `ImageComponent`s.

```dart
final document = MutableDocument(nodes: [
  ImageNode(
    id: Editor.createNodeId(),
    imageUrl: "https://avatars.githubusercontent.com/u/70979896?s=200&v=4",
  ),
]);
```

#### References
* [`ImageNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageNode-class.html) - node for an image.
* [`ImageComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageComponentBuilder-class.html) - component builder for the visual presentation of an image.
* [`ImageComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageComponentViewModel-class.html) - view model that configures an `ImageNode`.
* [`ImageComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageComponent-class.html) - visual presentation of an image. 

## Horizontal Rules
Horizontal rules are represented by `HorizontalRuleNode`s and presented with `HorizontalRuleComponent`s.

```dart
final document = MutableDocument(nodes: [
  HorizontalRuleNode(
    id: Editor.createNodeId(),
  ),
]);
```

#### References
* [`HorizontalRuleNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleNode-class.html) - node for a horizontal rule.
* [`HorizontalRuleComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleComponentBuilder-class.html) - builder for the visual presentation of a horizontal rule.
* [`HorizontalRuleComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleComponentViewModel-class.html) - view model that configures a `HorizontalRuleComponent`.
* [`HorizontalRuleComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/HorizontalRuleComponent-class.html) - visual presentation of a horizontal rule.

