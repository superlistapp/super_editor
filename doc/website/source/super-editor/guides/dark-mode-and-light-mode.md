---
title: Dark Mode & Light Mode
---
# Dark Mode & Light Mode
In Super Editor, there's no explicit concept of light mode and dark mode. Instead, you can implement
your own light mode and dark mode by switching out stylesheets.

Build a `SuperEditor` widget with a configurable stylesheet.

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

Define the stylesheet you want to use for light mode, and another stylesheet for dark mode.

```dart
// Super Editor comes with a standard stylesheet. You 
// can copy that stylesheet and adjust for your light 
// mode stylesheet.
final _lightStylesheet = defaultStylesheet.copyWith();

// For dark mode, you can define an entirely new stylesheet, 
// or you can copy and adjust your light mode stylesheet.
//
// Note the background color of your editor is controlled 
// by your widget tree outside of SuperEditor, which is 
// why this stylesheet doesn't include a background color.
final _darkStylesheet = _lightStylesheet.copyWith(
  addRulesAfter: [
    // Make all text a very light gray.
    StyleRule(
      BlockSelector.all, (doc, docNode) {
        return {
          "textStyle": const TextStyle(
            color: Color(0xFFCCCCCC),
          ),
        };
      },
    ),
    // Make the headers a medium gray.
    StyleRule(
      const BlockSelector("header1"), (doc, docNode) {
        return {
          "textStyle": const TextStyle(
            color: Color(0xFF888888),
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header2"), (doc, docNode) {
        return {
          "textStyle": const TextStyle(
            color: Color(0xFF888888),
          ),
        };
      },
    ),
  ],
);
```

When you're ready to switch brightness modes, rebuild your `SuperEditor` widget with the other
stylesheet.

```dart
setState(() {
  _stylesheet = _darkStylesheet; 
});
```