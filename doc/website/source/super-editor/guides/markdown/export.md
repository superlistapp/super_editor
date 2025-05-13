---
title: Export Super Editor Document to Markdown
contentRenderers:
  - jinja
  - markdown
---
Super Editor supports serializing Super Editor documents to Markdown documents.

To get started with serializing Markdown documents, add the Super Editor Markdown package:

```yaml
dependencies:
  super_editor: any
  super_editor_markdown: ^{{ pub.super_editor_markdown.version }}
```

Serialize a Super Editor document to Markdown document by calling the provided global function:

```dart
final markdown = serializeDocumentToMarkdown(superEditorDocument);
```

## Custom Serialization
Sometimes an app uses non-standard Markdown. Super Editor Markdown provides customization
control to generate that non-standard Markdown.

### Pre-Configured Syntax
Super Editor Markdown has a concept called `MarkdownSyntax`, which represents an entire
set of syntax preferences. The `serializeDocumentToMarkdown()` function accepts a
`MarkdownSyntax`.

There are only two options:
* `MarkdownSyntax.superEditor`: Standard Markdown syntax, along with a number of custom
  Markdown syntaxes, including paragraph alignment with notation like `:---` for left alignment
  and `:---:` for center alignment.
* `MarkdownSyntax.normal`: Standard Markdown syntax as defined by the `markdown` package.

By default, the `MarkdownSyntax.superEditor` option is used. To restrict serializing to the normal
syntax, pass `MarkdownSyntax.normal` into `serializeDocumentToMarkdown()`.

```dart
final markdown = serializeDocumentToMarkdown(
  superEditorDocument,
  syntax: MarkdownSyntax.normal,
);
```

### Custom Super Editor Node Converters
Super Editor documents are serialized to Markdown by converting every `DocumentNode` in the
Super Editor document into a block-level Markdown syntax. You might want to convert these nodes
to Markdown in a different way, or you might have your own custom `DocumentNode`s, which require
explicit instructions from you about how to turn them into Markdown blocks.

To control how various `DocumentNode`s serialize to Markdown blocks, provide
`customNodeSerializers` of type `DocumentNodeMarkdownSerializer` to 
`serializeDocumentToMarkdown`:

```dart
final markdown = serializeDocumentToMarkdown(
  superEditorDocument,
  syntax: [
    const TableNodeToMarkdownConverter(),
  ],
);
```