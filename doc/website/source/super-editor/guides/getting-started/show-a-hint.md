---
title: Show a Hint
---
When a document is new and empty, it's common for apps to display some hint text to
encourage the user to tap into the editor and start typing. For example, a chat editor
might show a hint that says "Start your message...".

Super Editor ships with support for hint messages in an empty document, but you need
to opt in to that behavior.

## Configure hint behavior
The decision to show a hint message is made at the document component level. This means
that to show a hint message, you need to add the corresponding component builder to
your `SuperEditor` widget configuration.

Note: When adding a new component builder, you need to make sure to still include the
standard "default" component builders, too. Otherwise, you'll end up with a `SuperEditor`
widget that doesn't know how to build components for paragraphs, images, or anything else.

```dart
Widget build(BuildContext context) {
  return SuperEditor(
    // ...
    componentBuilders: [
      HintComponentBuilder(
        hint: "Start typing...",
        hintStyleBuilder: (context) => TextStyle(
          color: Colors.grey,
        ),
      ),
      ...defaultComponentBuilders,
    ],
    // ...
  );
}
```