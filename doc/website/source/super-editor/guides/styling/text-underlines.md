---
title: Text Underlines
---
Underlines in Flutter text don't support any styles. They're always the same
thickness, the same distance from the text, the same color as the text, and
have the same square end-caps. It should be possible to control these styles,
but Flutter doesn't expose the lower level text layout controls.

Editors require custom underline painting for styles and design languages that
don't exactly match the standard text underline. Super Editor supports custom 
painting of underlines by manually positioning the painted lines beneath the
relevant spans of text.

## Special Underlines
Super Editor treats some underlines as special. These include:

 * The user's composing region.
 * Spelling errors.
 * Grammar errors.

For these special underlines, please see other guides and references to
work with them.

## Custom Underlines
Super Editor supports painting custom text underlines.

### Attribute the Text
First, attribute the desired text with a `CustomUnderlineAttribution`, which
specifies the visual type of underline. Super Editor includes some pre-defined
type names, but you can use any name.

```dart
final underlineAttribution = CustomUnderlineAttribution(
  CustomUnderlineAttribution.standard,
);

AttributedText(
  "This text includes an underline.",
  AttributedSpans(
    attributions: [
      SpanMarker(attribution: underlineAttribution, offset: 22, markerType: SpanMarkerType.start),
      SpanMarker(attribution: underlineAttribution, offset: 30, markerType: SpanMarkerType.end),
    ],
  ),
)
```

### Style the Underlines
Add a style rule to your stylesheet, which specifies all underline styles.

```dart
final myStylesheet = defaultStylesheet.copyWith(
  addRulesBefore: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          // The `underlineStyles` key is used to identify a collection of
          // underline styles.
          //
          // Within the `CustomUnderlineStyles`, you should add an entry
          // for every underline type name that your app uses, and then
          // specify the `UnderlineStyle` to paint that underline.
          UnderlineStyler.underlineStyles: CustomUnderlineStyles({
            // In this example, we specify only one underline style. This
            // style is for the `standard` underline type, and it paints
            // a green squiggly underline.
            CustomUnderlineAttribution.standard: SquiggleUnderlineStyle(
              color: Colors.green,
            ),
            // You can add more types and styles here...
          }),
        };
      },
    ),
  ],
);
```

### Custom Styles
Super Editor provides a few underline styles, which offer some configuration,
including `StraightUnderlineStyle`, `DottedUnderlineStyle`, and `SquiggleUnderlineStyle`.
However, these may not meet your needs.

To paint your own underline, you need to create two classes: a subclass of `UnderlineStyle`
and a `CustomPainter` that actually does the painting.

The `UnderlineStyle` subclass is like a view-model, and the `CustomPainter` uses
properties from the `UnderlineStyle` to decide how to paint the underline.

For example, the following is the implementation of `StraightUnderlineStyle`.

```dart
class StraightUnderlineStyle implements UnderlineStyle {
  const StraightUnderlineStyle({
    this.color = const Color(0xFF000000),
    this.thickness = 2,
    this.capType = StrokeCap.square,
  });

  final Color color;
  final double thickness;
  final StrokeCap capType;

  @override
  CustomPainter createPainter(List<LineSegment> underlines) {
    return StraightUnderlinePainter(underlines: underlines, color: color, thickness: thickness, capType: capType);
  }
}
```

The job of the `UnderlineStyle` is to take a collection of properties and
pass them in some form to a `CustomPainter`. In the case of `StraightUnderlineStyle`,
the properties are passed to a `StraightUnderlinePainter`. The `createPainter()`
method is called by Super Editor at the appropriate time.

To complete the example, the following is the implementation of `StraightUnderlinePainter`.

```dart
class StraightUnderlinePainter extends CustomPainter {
  const StraightUnderlinePainter({
    required List<LineSegment> underlines,
    this.color = const Color(0xFF000000),
    this.thickness = 2,
    this.capType = StrokeCap.square,
  }) : _underlines = underlines;

  final List<LineSegment> _underlines;

  final Color color;
  final double thickness;
  final StrokeCap capType;

  @override
  void paint(Canvas canvas, Size size) {
    if (_underlines.isEmpty) {
      return;
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = capType;
    for (final underline in _underlines) {
      canvas.drawLine(underline.start, underline.end, linePaint);
    }
  }

  @override
  bool shouldRepaint(StraightUnderlinePainter oldDelegate) {
    return color != oldDelegate.color ||
        thickness != oldDelegate.thickness ||
        capType != oldDelegate.capType ||
        !const DeepCollectionEquality().equals(_underlines, oldDelegate._underlines);
  }
}
```

By providing your own version of these two classes, you can paint any underline you desire.

With your own `UnderlineStyle` defined, use it in your stylesheet as discussed previously.

As you implement your own underline painting, you might be confused where some of these
underline classes come from. Note that some of them are lower level than Super Editor - 
they come from the `super_text_layout` package, which is another package in the
Super Editor mono repo.