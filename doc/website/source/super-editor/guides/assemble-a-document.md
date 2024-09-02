---
title: Assemble a Document
---
# Assemble a Document
In Super Editor, a document is typically represented by an instance of `MutableDocument`. The
easiest way to assemble a `MutableDocument` is by [de-serializing Markdown](/guides/document-from-markdown).
However, there are situations where you might need to construct a `MutableDocument` directly. This
guide shows you how.

## What is a Document?
In Super Editor, a `Document` is a series of nodes - specifically `DocumentNode`s. Different types of
`DocumentNode`s are available for different types of content, such as `ParagraphNode` and `ImageNode`.

Assembling a `Document` means assembling a list of desired `DocumentNode`s.

## Construct a `MutableDocument` with Content
The `MutableDocument` constructor accepts a list of `DocumentNode`s as initial content.

```dart
final document = MutableDocument(
  nodes: [
    ParagraphNode(
      id: Editor.createNodeId(),
      text: AttributedText(text: "Hello, world!"),
    ),
  ],
);
```

## Alter an existing `MutableDocument`
A `MutableDocument` can be altered after construction.

You can insert nodes.

```dart
document.insertNodeAt(1, ParagraphNode(
  id: Editor.createNodeId(),
  text: AttributedText(text: "New paragraph"),
),);
```

You can move nodes.

```dart
document.moveNode(nodeId: "node1", targetIndex: 2);
```

You can remove nodes.

```dart
document.deleteNodeAt(2);
```

If your goal is to use a `MutableDocument` in an editor experience, consider wrapping the
`MutableDocument` in an `Editor`, and then use the standard edit pipeline to alter the document's
content.