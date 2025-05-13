---
title: Images
---
Super Editor ships with support for network images.

## Image Node
Network images are represented in a `Document` with an `ImageNode`.

```dart
final document = MutableDocument(nodes: [
  ImageNode(
    id: Editor.createNodeId(),
    imageUrl: "https://avatars.githubusercontent.com/u/70979896?s=200&v=4",
  ),
]);
```

`ImageNode`s also support an "expected bitmap size", to help make space in the
editor while it's loading, as we all "alt text", which may be displayed on hover.

To support other image sources, implement a custom version of `ImageNode`, e.g.,
`FileImageNode`. Such a customization also requires custom visuals, as discussed
below.

## Visual Presentation
By default, `SuperEditor` includes an `ImageComponentBuilder`, which builds an
`ImageComponent` widget to display within an editor. Therefore, no additional
steps are required to display an image.

To change how images are rendered in an editor, replace the built in
`ImageComponentBuilder` and the `ImageComponent` with your own implementation.

## References
* [`ImageNode`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageNode-class.html) - node for an image.
* [`ImageComponentBuilder`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageComponentBuilder-class.html) - component builder for the visual presentation of an image.
* [`ImageComponentViewModel`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageComponentViewModel-class.html) - view model that configures an `ImageNode`.
* [`ImageComponent`](https://pub.dev/documentation/super_editor/0.3.0-dev.23/super_editor/ImageComponent-class.html) - visual presentation of an image.
