<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/170845454-e7a6e0ec-07f0-4f80-be31-3e5730a72aaf.png" width="300" alt="Super Text Layout"><br>
  <span><b>Configurable, composable, extensible text display for Flutter.</b></span><br><br>
</p>

---

## `SuperTextWithSelection`
Use the `SuperTextWithSelection` widget when you want to paint text with traditional user selections.

`SuperTextWithSelection` supports single-user and multi-user text selections.

```dart
// Single-user selection
Widget build(context) {
  return SuperTextWithSelection.single(
    richText: myText,
    userSelection: UserSelection(
      highlightStyle: myHighlightStyle,
      caretStyle: myCaretStyle,
      selection: myTextSelection,
    ),
  );
}

// Multi-user selection
Widget build(context) {
  return SuperTextWithSelection.multi(
    richText: _text,
    userSelections: [
      UserSelection(
        highlightStyle: _primaryHighlightStyle,
        caretStyle: _primaryCaretStyle,
        selection: const TextSelection(baseOffset: 11, extentOffset: 21),
      ),
      UserSelection(
        highlightStyle: _johnHighlightStyle,
        caretStyle: _johnCaretStyle,
        selection: const TextSelection(baseOffset: 58, extentOffset: 65),
      ),
      UserSelection(
        highlightStyle: _sallyHighlightStyle,
        caretStyle: _sallyCaretStyle,
        selection: const TextSelection(baseOffset: 79, extentOffset: 120),
      ),
    ],
  );
}
``` 

## `SuperText`
The `SuperText` widget is the workhorse in the `super_text` package. It provides a platform, upon which you can build custom text decorations.

`SuperText` renders rich text, like you're used to, but then it allows you to paint a UI beneath the text, and above the text. In those layers you can paint things like selection highlights, carets, user names, etc.

```dart
Widget build(context) {
  // Implement a standard highlight + caret user selection,
  // using SuperText.
  return SuperText(
    richText: _text,
    layerAboveBuilder: (context, textLayout) {
      return Stack(
        children: [
          // Here you can paint anything you want, and you can use the
          // provided textLayout to position your UI based on lines and
          // characters in the text.
          TextLayoutCaret(
            textLayout: textLayout,
            style: myCaretStyle,
            position: mySelection.extent,
          ),
        ],
      );
    },
    layerBeneathBuilder: (context, textLayout) {
      return Stack(
        children: [
          // Here you can paint anything you want, and you can use the
          // provided textLayout to position your UI based on lines and
          // characters in the text.
          TextLayoutSelectionHighlight(
            textLayout: textLayout,
            style: myHighlightStyle,
            selection: mySelection,
          ),
        ],
      );
    },
  );
}
```
