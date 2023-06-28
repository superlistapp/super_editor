import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:super_text_layout/super_text_layout.dart';

class AttributedFollowerDemo extends StatefulWidget {
  const AttributedFollowerDemo({super.key});

  @override
  State<AttributedFollowerDemo> createState() => _AttributedFollowerDemoState();
}

class _AttributedFollowerDemoState extends State<AttributedFollowerDemo> {
  static const token = NamedAttribution("token");

  static const _textStyle = TextStyle(
    color: Color(0xFF444444),
    fontFamily: 'Roboto',
    fontSize: 20,
    height: 1.4,
  );

  final _attributedText = AttributedText(
    text: "This is some text that's tokenized like tags and mentions",
    spans: AttributedSpans(attributions: [
      const SpanMarker(attribution: token, offset: 8, markerType: SpanMarkerType.start),
      const SpanMarker(attribution: token, offset: 16, markerType: SpanMarkerType.end),
      const SpanMarker(attribution: token, offset: 25, markerType: SpanMarkerType.start),
      const SpanMarker(attribution: token, offset: 33, markerType: SpanMarkerType.end),
      const SpanMarker(attribution: token, offset: 40, markerType: SpanMarkerType.start),
      const SpanMarker(attribution: token, offset: 43, markerType: SpanMarkerType.end),
      const SpanMarker(attribution: token, offset: 49, markerType: SpanMarkerType.start),
      const SpanMarker(attribution: token, offset: 56, markerType: SpanMarkerType.end),
    ]),
  );
  Set<TextRange> _tokenRanges = {};

  final _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();

    _calculateTokenRanges();
  }

  void _calculateTokenRanges() {
    _tokenRanges = _attributedText
        .getAttributionSpansInRange(
            attributionFilter: (a) => a == token, range: SpanRange(start: 0, end: _attributedText.text.length))
        .map((span) => TextSelection(baseOffset: span.start, extentOffset: span.end + 1))
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildText(),
        CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          showWhenUnlinked: false,
          child: Container(
            width: 200,
            height: 50,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildText() {
    return SuperText(
      richText: TextSpan(
        text: _attributedText.text,
        style: _textStyle,
      ),
      layerBeneathBuilder: boundingBoxesLayer(_tokenRanges),
    );
  }
}

/// Returns a [SuperTextLayerBuilder] that builds invisible bounding box widgets around
/// each of the given [ranges].
SuperTextLayerBuilder boundingBoxesLayer(Set<TextRange> ranges) {
  return (context, textLayout) {
    final tokenRectsByAttribution = ranges
        .map((range) => textLayout.getBoxesForSelection(
              TextSelection(baseOffset: range.start, extentOffset: range.end),
            ))
        .map((boxes) => boxes.map((box) => box.toRect()));

    final tokenRects = [
      for (final rects in tokenRectsByAttribution) //
        ...rects,
    ];

    return Stack(
      children: [
        for (final rect in tokenRects)
          Positioned.fromRect(
            rect: rect,
            child: Container(color: Colors.red),
          ),
      ],
    );
  };
}
