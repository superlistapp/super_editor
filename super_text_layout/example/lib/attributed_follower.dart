import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
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
  late final TextSpan _richText;
  Set<TextRange> _tokenRanges = {};

  final _leaderLink = LeaderLink();

  int _spanToFollow = 0;

  @override
  void initState() {
    super.initState();

    _createRichText();
    _calculateTokenRanges();
  }

  void _createRichText() {
    _richText = TextSpan(children: [], style: _textStyle);
    int textOffset = 0;

    final spans = _attributedText.getAttributionSpansInRange(
      attributionFilter: (a) => a == token,
      range: SpanRange(start: 0, end: _attributedText.text.length),
    );

    for (final span in spans) {
      if (span.start > textOffset) {
        _richText.children!.add(
          TextSpan(text: _attributedText.text.substring(textOffset, span.start)),
        );
        textOffset = span.start;
      }

      _richText.children!.add(TextSpan(
        text: _attributedText.text.substring(span.start, span.end + 1),
        style: const TextStyle(color: Colors.blue),
      ));
      textOffset = span.end + 1;
    }
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
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildText(),
            _buildSpanSelectionControls(),
          ],
        ),
        Follower.withAligner(
          link: _leaderLink,
          aligner: CupertinoPopoverToolbarAligner(),
          child: CupertinoPopoverToolbar(
            focalPoint: LeaderMenuFocalPoint(link: _leaderLink),
            children: [
              CupertinoPopoverToolbarMenuItem(label: "Copy"),
              CupertinoPopoverToolbarMenuItem(label: "Cut"),
              CupertinoPopoverToolbarMenuItem(label: "Paste"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildText() {
    return SuperText(
      richText: _richText,
      layerBeneathBuilder: boundingBoxesLayer(_tokenRanges, (i) => i == _spanToFollow ? _leaderLink : null),
    );
  }

  Widget _buildSpanSelectionControls() {
    return Row(
      children: [
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _spanToFollow > 0
              ? () {
                  setState(() {
                    _spanToFollow -= 1;
                  });
                }
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _spanToFollow < _tokenRanges.length - 1
              ? () {
                  setState(() {
                    _spanToFollow += 1;
                  });
                }
              : null,
        ),
      ],
    );
  }
}

/// Returns a [SuperTextLayerBuilder] that builds invisible bounding box widgets around
/// each of the given [ranges].
SuperTextLayerBuilder boundingBoxesLayer(Set<TextRange> ranges, BoundingBoxLinker linker) {
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

    final rectWidgets = <Widget>[];
    for (int i = 0; i < tokenRects.length; i += 1) {
      final link = linker(i);
      rectWidgets.add(
        link != null
            ? Leader(
                link: link,
                child: const SizedBox(),
              )
            : const SizedBox(),
      );
    }

    return Stack(
      children: [
        for (int i = 0; i < rectWidgets.length; i += 1)
          Positioned.fromRect(
            rect: tokenRects[i],
            child: rectWidgets[i],
          ),
      ],
    );
  };
}

typedef BoundingBoxLinker = LeaderLink? Function(int spanIndex);
