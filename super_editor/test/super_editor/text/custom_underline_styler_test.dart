import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('CustomUnderlineStyler', () {
    test('adds no underlines to text without custom underline attributions', () {
      final viewModel = _style(
        AttributedText(
          'Hello world, this is linked and bold text',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(attribution: boldAttribution, offset: 4, markerType: SpanMarkerType.end),
              const SpanMarker(
                attribution: LinkAttribution('https://example.com'),
                offset: 21,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: LinkAttribution('https://example.com'),
                offset: 26,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      );

      expect(viewModel.customUnderlines, isEmpty);
      expect(viewModel.text.getAttributionSpansByFilter((_) => true), hasLength(2));
    });

    test('adds an underline for each custom underline span next to other attributions', () {
      final viewModel = _style(
        AttributedText(
          'Hello world, this is linked and bold text',
          AttributedSpans(
            attributions: [
              const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
              const SpanMarker(
                attribution: CustomUnderlineAttribution('squiggle'),
                offset: 2,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(attribution: boldAttribution, offset: 4, markerType: SpanMarkerType.end),
              const SpanMarker(
                attribution: CustomUnderlineAttribution('squiggle'),
                offset: 7,
                markerType: SpanMarkerType.end,
              ),
              const SpanMarker(
                attribution: CustomUnderlineAttribution(),
                offset: 32,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: CustomUnderlineAttribution(),
                offset: 35,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      );

      final underlines = viewModel.customUnderlines.map((u) => (u.type, u.textRange)).toList()
        ..sort((a, b) => a.$2.start.compareTo(b.$2.start));
      expect(underlines, [
        ('squiggle', const TextRange(start: 2, end: 8)),
        (CustomUnderlineAttribution.standard, const TextRange(start: 32, end: 36)),
      ]);
    });
  });
}

TextComponentViewModel _style(AttributedText text) {
  final document = MutableDocument(nodes: [ParagraphNode(id: '1', text: text)]);
  final input = SingleColumnLayoutViewModel(
    componentViewModels: [
      ParagraphComponentViewModel(
        nodeId: '1',
        createdAt: null,
        text: text,
        textStyleBuilder: (_) => const TextStyle(),
        selectionColor: const Color(0x00000000),
      ),
    ],
  );

  return CustomUnderlineStyler().style(document, input).componentViewModels.single as TextComponentViewModel;
}
