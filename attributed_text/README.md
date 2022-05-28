<p align="center">
  <img src="https://user-images.githubusercontent.com/7259036/170845473-268655ac-3fec-47c1-86ab-41a1391aa1e0.png" width="300" alt="Attributed Text"><br>
  <span><b>Easily add metadata to your <code>String</code>s with the <code>attributed_text</code> package.</b></span><br><br>
</p>

---

`AttributedText` forms the basis of all text representation within `super_editor`.

## Get Started
`AttributedText` combines a `String` with some number of `Attribution` spans.

```dart
final helloWorld = AttributedText(
  text: "Hello, world!",
  spans: AttributedSpans(
    attributions: [
      const SpanMarker(attribution: bold, offset: 7, markerType: SpanMarkerType.start),
      const SpanMarker(attribution: bold, offset: 12, markerType: SpanMarkerType.end),
    ],
  ),
);
```

This example associates an `Attribution` called `bold` with all the characters from index `7` to index `12`. Logically, you can think of this `AttributedText` as looking like "Hello, **world!**".

### What is an Attribution?
An `Attribution` is the metadata that's associated with the characters in an `AttributedSpans`.

A text editor, for example, would probably define `Attribution`s for bold, italics, underline, strikethrough, links, and inline code.

#### Named Attributions
`Attribution`s that require only a name are easily defined as `NamedAttribution`s.

```dart
final bold = NamedAttribution("bold");
final italics = NamedAttribution("italics");
final underline = NamedAttribution("underline");
```

Two `NamedAttribution`s are considered "equivalent" when they both have the same name.

#### Custom Attributions
Any object that implements the `Attribution` interface can be used as an `Attribution` in an `AttributedText`.

You may need to define your own custom `Attribution` classes to represent metadata that includes more information than just a name.

For example, you might implement a `LinkAttribution` like this:

```dart
/// Attribution to be used within [AttributedText] to
/// represent a link.
///
/// Every [LinkAttribution] is considered equivalent, so
/// that [AttributedText] prevents multiple [LinkAttribution]s
/// from overlapping.
class LinkAttribution implements Attribution {
  LinkAttribution({
    required this.url,
  });

  @override
  String get id => 'link';

  final Uri url;

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LinkAttribution && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}
```

Any two instances of an `Attribution` that have the same `id` will be prevented from overlapping. If two `Attribution`s with the same `id` touch each other, then `AttributedText` will check if one of them `canMergeWith` the other - if so, they are combined.
