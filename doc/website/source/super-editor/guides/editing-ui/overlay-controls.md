---
title: Overlay Controls
---
# Styling Overlay Controls
The `SuperEditor` widget includes a number of viewport "overlay builders", which construct
editor controls that sit on top of the viewport. These controls include, for example, the
caret (on desktop), drag handles (on mobile), magnifier (on mobile), and a popover toolbar.

`SuperEditor` includes a default collection of overlay builders. If you want a different
collection of overlay builders, or if you'd like to adjust the configuration of those builders,
you can copy the default list of overlay builders and change their configuration.

## Caret Color and Shape
By default, the caret is rendered with a `DefaultCaretOverlayBuilder`. This builder can be
replaced for a completely custom caret. It can also be configured to change the standard
caret color, width, and border radius.

To change the default configuration, copy the default list of overlay builders and then
adjust the properties given to `DefaultCaretOverlayBuilder`:

```dart
SuperEditor(
  // ...
  documentOverlayBuilders: [
    // Make the caret thicker, rounder, and make it red.
    DefaultCaretOverlayBuilder(
      color: Colors.red,
      width: 4,
      borderRadius: BorderRadius.circular(2),
    ),
  
    // Include the other standard overlay builders.
    SuperEditorIosToolbarFocalPointDocumentLayerBuilder(),
    SuperEditorIosHnaldesDocumentLayerBuilder(),
    SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder(),
    SuperEditorAndroidHandlesDocumentLayerBuilder(),
  ],
  // ...
);
```
