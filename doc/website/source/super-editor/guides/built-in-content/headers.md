---
title: Headers
---
Super Editor ships with support for six levels of headers.

Headers are implemented with the same objects as [paragraphs](/super-editor/guides/built-in-content/headers),
but with a slightly different configuration.

## Header Node
Headers are represented in documents with a `ParagraphNode` whose `blockType` is set to
some level of header, such as `header1Attribution`.

```dart
final document = MutableDocument(nodes: [
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("This is a header 1"),
    metadata: {
      NodeMetadata.blockType: header1Attribution,
    }
  ),
]);
```

## Visual Presentation
By default, `SuperEditor` includes a `ParagraphComponentBuilder`, which builds a
`ParagraphComponent` widget to display within an editor. Despite being named after
a "paragraph", this widget also handles the display of headers. Therefore, no additional
steps are required to display a header.

The easiest way to make stylistic adjustments to the built-in header presentation
is to customize Super Editor's default [stylesheet](/super-editor/guides/styling/style-a-document).

## References
* [`ParagraphNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphNode-class.html) - node for paragraphs, headers, and blockquotes.
* [`ParagraphComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponentBuilder-class.html) - component builder for the visual representation of a paragraph or header.
* [`ParagraphComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponentViewModel-class.html) - view model that configures a `ParagraphComponent`.
* [`ParagraphComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphComponent-class.html) - the visual presentation of a paragraph or header within a document.
