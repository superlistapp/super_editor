---
title: Paragraphs
---
Super Editor ships with built-in support for paragraphs, which represent standard
text in a document.

## Paragraph Node
A `ParagraphNode` is the most common `DocumentNode` in a `Document`. It holds the logical
representation of a paragraph, which mostly means that a `ParagraphNode` contains some text
and possibly some attributions applied to that text (e.g.: bold, italics).

The following sample shows how to create a `ParagraphNode`.

```dart
final document = MutableDocument(nodes: [
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("This is a paragraph"),
  ),
]);
```

## Visual Presentation
By default, `SuperEditor` includes a `ParagraphComponentBuilder`, which builds a 
`ParagraphComponent` widget to display within an editor. Therefore, no additional
steps are required to display a paragraph.

The easiest way to make stylistic adjustments to the built-in paragraph presentation
is to customize Super Editor's default [stylesheet](/super-editor/guides/styling/style-a-document).

## References
* [`ParagraphNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphNode-class.html) - node for paragraphs, headers, and blockquotes.
* [`ParagraphComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponentBuilder-class.html) - component builder for the visual representation of a paragraph.
* [`ParagraphComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponentViewModel-class.html) - view model that configures a `ParagraphComponent`.
* [`ParagraphComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponent-class.html) - the visual presentation of a paragraph within a document.
