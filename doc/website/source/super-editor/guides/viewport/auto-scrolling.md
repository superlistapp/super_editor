---
title: Auto-Scrolling
---
# Auto-Scroll Boundaries
By default, when the user's caret approaches the top or bottom of the viewport, `SuperEditor`
automatically scrolls to make room for the caret.

When auto-scrolling, `SuperEditor` enforces a little bit of additional spaces between the
caret and the top/bottom boundary so that the caret doesn't get too close to the boundary.

```dart
class _MyAppState extends State<MyApp> {
  Stylesheet _stylesheet = _lightStylesheet;
  
  Widget build(BuildContext context) {
    return SuperEditor(
      stylesheet: _stylesheet,
      // ...other properties
    );
  }
}
```
