import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperEditor > computeInlineSpan >', () {
    testWidgets('does not modify text with attributions and a placeholder at the beginning', (tester) async {
      // Pump a widget because we need a BuildContext to compute the InlineSpan.
      await tester.pumpWidget(
        const MaterialApp(),
      );

      // Create an AttributedText with the words "Welcome" and "SuperEditor" in bold and with a leading placeholder.
      final text = AttributedText(
        'Welcome to SuperEditor',
        AttributedSpans(
          attributions: [
            const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: boldAttribution, offset: 11, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
          ],
        ),
        {0: const _ExamplePlaceholder()},
      );

      final inlineSpan = text.computeInlineSpan(
        find.byType(MaterialApp).evaluate().first as BuildContext,
        defaultStyleBuilder,
        [_inlineWidgetBuilder],
      );

      // Ensure the text was not modified.
      expect(
        inlineSpan.toPlainText(includePlaceholders: false),
        'Welcome to SuperEditor',
      );
    });

    testWidgets('does not modify text with attributions and a placeholder at the middle', (tester) async {
      // Pump a widget because we need a BuildContext to compute the InlineSpan.
      await tester.pumpWidget(
        const MaterialApp(),
      );

      // Create an AttributedText with the words "Welcome" and "SuperEditor" in bold and with a
      // placeholder after the word "to".
      final text = AttributedText(
        'Welcome to SuperEditor',
        AttributedSpans(
          attributions: [
            const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: boldAttribution, offset: 11, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
          ],
        ),
        {10: const _ExamplePlaceholder()},
      );

      final inlineSpan = text.computeInlineSpan(
        find.byType(MaterialApp).evaluate().first as BuildContext,
        defaultStyleBuilder,
        [_inlineWidgetBuilder],
      );

      // Ensure the text was not modified.
      expect(
        inlineSpan.toPlainText(includePlaceholders: false),
        'Welcome to SuperEditor',
      );
    });

    testWidgets('does not modify text with attributions and a placeholder at the end', (tester) async {
      // Pump a widget because we need a BuildContext to compute the InlineSpan.
      await tester.pumpWidget(
        const MaterialApp(),
      );

      // Create an AttributedText with the words "Welcome" and "SuperEditor" in bold and a trailing placeholder.
      final text = AttributedText(
        'Welcome to SuperEditor',
        AttributedSpans(
          attributions: [
            const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 6, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: boldAttribution, offset: 11, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 21, markerType: SpanMarkerType.end),
          ],
        ),
        {22: const _ExamplePlaceholder()},
      );

      final inlineSpan = text.computeInlineSpan(
        find.byType(MaterialApp).evaluate().first as BuildContext,
        defaultStyleBuilder,
        [_inlineWidgetBuilder],
      );

      // Ensure the text was not modified.
      expect(
        inlineSpan.toPlainText(includePlaceholders: false),
        'Welcome to SuperEditor',
      );
    });
  });
}

class _ExamplePlaceholder {
  const _ExamplePlaceholder();
}

Widget? _inlineWidgetBuilder(BuildContext context, TextStyle textStyle, Object placeholder) {
  return const SizedBox(width: 10);
}
