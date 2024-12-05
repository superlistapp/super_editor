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
const markdown = '''
# Header
This is a _Super_ Editor!
''';

final document = deserializeMarkdownToDocument(markdown);
```

The de-serialized document is a `MutableDocument`. Add it to your `Editor` similarly to how you did it in the Quickstart guide:

```dart
_editor = createDefaultDocumentEditor(
  document: document,
  composer: MutableDocumentComposer(),
);
```

Run that, and you'll see the document rendered on the screen.

## Serialize Markdown
You can also go the other direction. Here's how you would serialize a `Document` to a Markdown `String`:

```dart
final markdown = serializeDocumentToMarkdown(document);
```
