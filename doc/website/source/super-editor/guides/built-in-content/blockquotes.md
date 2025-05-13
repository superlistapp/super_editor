---
title: Blockquotes
---
Super Editor ships with support for blockquotes, which are essentially paragraphs
whose content represents a quotation.

Blockquotes re-use some tools from the [paragraph](/super-editor/guides/built-in-content/headers)
implementation, and also adds some tools specific to blockquotes.

## Blockquote Node
Blockquotes are represented in documents with a `ParagraphNode` whose `blockType` is set to
`blockquoteAttribution`.

```dart
final document = MutableDocument(nodes: [
  ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText("This is a header 1"),
    metadata: {
      NodeMetadata.blockType: blockquoteAttribution,
    }
  ),
]);
```

## Visual Presentation
By default, `SuperEditor` includes a `BlockquoteComponentBuilder`, which builds a
`BlockquoteComponent` widget to display within an editor. Therefore, no additional
steps are required to display a blockquote.

The easiest way to make stylistic adjustments to the built-in blockquote presentation
is to customize Super Editor's default [stylesheet](/super-editor/guides/styling/style-a-document).

## References
* [`ParagraphNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ParagraphNode-class.html) - node for paragraphs, headers, and blockquotes.
* [`BlockquoteComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/BlockquoteComponentBuilder-class.html) - component builder for the visual representation of a blockquote.
* [`BlockquoteComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/BlockquoteComponentViewModel-class.html) - view model that configures a `BlockquoteComponent`.
* [`BlockquoteComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/BlockquoteComponent-class.html) - the visual presentation of a blockquote within a document.