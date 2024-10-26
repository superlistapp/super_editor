---
title: Document from Markdown
---
# Document from Markdown
Super Editor supports conversion to and from Markdown.

## Add a dependency on super_editor_markdown
Markdown support is maintained in a separate package. To get started, add `super_editor_markdown`
to your `pubspec.yaml`.

```yaml
dependencies:
  super_editor_markdown:
```

## De-serialize Markdown
De-serialize a Markdown `String` with the supplied top-level function.

```dart
final document = deserializeMarkdownToDocument(markdown);
```

The de-serialized document is a `MutableDocument`. Check other guides to find out how to use it.

## Serialize Markdown
Serialize a `Document` to a Markdown `String`.

```dart
final markdown = serializeDocumentToMarkdown(document);
```
