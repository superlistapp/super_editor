---
title: Embed in a Scrollview
---
The `SuperEditor` widget includes its own viewport and scroll system because most apps
want a self-contained editor. However, some apps need to place a `SuperEditor` within
a pre-existing scrollable. For example, an app might have a collapsible header, which requires
that the page be built from slivers. Or another example, an app displays an editor above
a comment thread, and that comment thread should scroll using the same system as the
editor.

`SuperEditor` was built as a hybrid. You can use it as a `RenderBox` whenever you want 
it to scroll itself, or you can use it as a `Sliver` when you want to embed it within
another scrolling experience.

When embedding `SuperEditor` within another scrolling system, you have two options:
1. Use `SuperEditor` as a `Sliver`, or
2. Expand `SuperEditor` to its maximum height and use it like a big `RenderBox`

Whenever possible, you should go with option #1, because `SuperEditor` operating as
a `Sliver` better respects Flutter's built-in assumptions about scrolling and layout.
`SuperEditor` is built specifically to operate that way.

Option #2 is possible, but may produce unexpected results. This is because option #2
relies on telling `SuperEditor` that it can be as tall as it wants, and then defers
to `SuperEditor`'s intrinsic height. There's nothing fundamentally wrong with this,
however the reality of the Flutter ecosystem is that most developers don't think about
intrinsic height and then fail to account for it. For example, for `SuperEditor` to
support intrinsic height, every component used within `SuperEditor` must support
intrinsic height, including any custom component that you might add. `SuperEditor`
can't force you to do the right thing - that becomes your responsibility.

## How to embed `SuperEditor` as a `Sliver`
Embedding `SuperEditor` as a `Sliver` is trivial - simply treat it like any other
`Sliver`.

```dart
Widget build(BuildContext context) {
  return CustomScrollView(
    slivers: [
      CollapsibleHeader(),
      SuperEditor(
        // ...
      ),
      InfiniteCommentThread(),
      Footer(),
    ],
  );
}
```

## How to embed `SuperEditor` as a `RenderBox`
To embed `SuperEditor` in a scrolling experience such as a `ListView`, configure `SuperEditor`
to size itself intrinsically.

```dart
Widget build(BuildContext context) {
  return ListView(
    children: [
      Header(),
      SuperEditor(
        // ...
        shrinkWrap: true,
        // ...
      ),
      Footer(),
    ],
  );
}
```
