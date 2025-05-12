---
title: As You Type
---
Not only can Super Editor import and export Markdown, but it can also recognize and
apply Markdown as the user types.

## Add the package
Markdown functionality is provided by `super_editor_markdown`. Add it to your `pubspec.yaml`.

```yaml
dependencies:
  super_editor: any
  super_editor_markdown: any
```

## Add the plugin
The `MarkdownInlineUpstreamSyntaxPlugin` monitors the position of the user's caret,
looks upstream for any Markdown syntax, and then converts the text as desired.

Add the plugin to your `SuperEditor` widget.

```dart
Widget build(BuildContext context) {
  return SuperEditor(
    // ...
    plugins: {
      MarkdownInlineUpstreamSyntaxPlugin(),
    },
  );
}
```

## Verify the results
Run your editor experience and try out the automatic conversion.

Type `# ` to convert your paragraph to a Header 1.

Type `> ` to convert your paragraph to a blockquote.

In the middle of some text type `This is *italic*` to make the text "italic", italic.

In the middle of some text type `This is **bold**` to make the text "bold", bold.

In the middle of some text type `This is a [link](https://flutterbountyhunters.com)` to linkify "link".