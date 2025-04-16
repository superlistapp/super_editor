import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperEditor > computeInlineSpan >', () {
    testWidgets('computes inlineSpan for text with attributions and a placeholder at the beginning', (tester) async {
      // Pump a widget because we need a BuildContext to compute the InlineSpan.
      await tester.pumpWidget(
        const MaterialApp(),
      );

      // Create an AttributedText with the words "Welcome" and "SuperEditor" in bold and with a leading placeholder.
      final text = AttributedText(
        'Welcome to SuperEditor',
        AttributedSpans(
          attributions: [
            const SpanMarker(attribution: boldAttribution, offset: 1, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 7, markerType: SpanMarkerType.end),
            const SpanMarker(attribution: boldAttribution, offset: 12, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 22, markerType: SpanMarkerType.end),
          ],
        ),
        {0: const _ExamplePlaceholder()},
      );

      final inlineSpan = text.computeInlineSpan(
        find.byType(MaterialApp).evaluate().first as BuildContext,
        defaultStyleBuilder,
        [_inlineWidgetBuilder],
      );

      final spanList = _flattenInlineSpan(inlineSpan);
      expect(spanList.length, equals(5));

      // Ensure that the first span is an empty TextSpan with the default fontWeight.
      expect(spanList[0], isA<TextSpan>());
      expect((spanList[0] as TextSpan).text, equals(''));
      expect((spanList[0] as TextSpan).style!.fontWeight, isNull);

      // Expect that the second span is the widget rendered using the placeholder.
      expect(spanList[1], isA<WidgetSpan>());

      // Ensure that the third span is a TextSpan with the text "Welcome" in bold.
      expect(spanList[2], isA<TextSpan>());
      expect((spanList[2] as TextSpan).text, equals('Welcome'));
      expect((spanList[2] as TextSpan).style!.fontWeight, equals(FontWeight.bold));

      // Ensure that the fourth span is a TextSpan with the text " to " with the default fontWeight.
      expect(spanList[3], isA<TextSpan>());
      expect((spanList[3] as TextSpan).text, equals(' to '));
      expect((spanList[3] as TextSpan).style!.fontWeight, isNull);

      // Ensure that the fifth span is a TextSpan with the text "SuperEditor" in bold.
      expect(spanList[4], isA<TextSpan>());
      expect((spanList[4] as TextSpan).text, equals('SuperEditor'));
      expect((spanList[4] as TextSpan).style!.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('computes inlineSpan for text with attributions and a placeholder at the middle', (tester) async {
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
            const SpanMarker(attribution: boldAttribution, offset: 12, markerType: SpanMarkerType.start),
            const SpanMarker(attribution: boldAttribution, offset: 22, markerType: SpanMarkerType.end),
          ],
        ),
        {10: const _ExamplePlaceholder()},
      );

      final inlineSpan = text.computeInlineSpan(
        find.byType(MaterialApp).evaluate().first as BuildContext,
        defaultStyleBuilder,
        [_inlineWidgetBuilder],
      );

      final spanList = _flattenInlineSpan(inlineSpan);
      expect(spanList.length, equals(6));

      // Ensure that the first span is an empty TextSpan with the default fontWeight.
      expect(spanList[0], isA<TextSpan>());
      expect((spanList[0] as TextSpan).text, equals(''));
      expect((spanList[0] as TextSpan).style!.fontWeight, isNull);

      // Expect that the second span is a TextSpan with the text "Welcome" in bold.
      expect(spanList[1], isA<TextSpan>());
      expect((spanList[1] as TextSpan).text, equals('Welcome'));
      expect((spanList[1] as TextSpan).style!.fontWeight, equals(FontWeight.bold));

      // Ensure that the third span is a TextSpan with the text " to" with the default fontWeight.
      expect(spanList[2], isA<TextSpan>());
      expect((spanList[2] as TextSpan).text, equals(' to'));
      expect((spanList[2] as TextSpan).style!.fontWeight, isNull);

      // Expect that the fourth span is the widget rendered using the placeholder.
      expect(spanList[3], isA<WidgetSpan>());

      // Ensure that the fifth span is a TextSpan with the text " " with the default fontWeight.
      expect(spanList[4], isA<TextSpan>());
      expect((spanList[4] as TextSpan).text, equals(' '));
      expect((spanList[4] as TextSpan).style!.fontWeight, isNull);

      // Ensure that the sixth span is a TextSpan with the text "SuperEditor" in bold.
      expect(spanList[5], isA<TextSpan>());
      expect((spanList[5] as TextSpan).text, equals('SuperEditor'));
      expect((spanList[5] as TextSpan).style!.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('computes inlineSpan for text with attributions and a placeholder at the end', (tester) async {
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

      final spanList = _flattenInlineSpan(inlineSpan);
      expect(spanList.length, equals(5));

      // Ensure that the first span is an empty TextSpan with the default fontWeight.
      expect(spanList[0], isA<TextSpan>());
      expect((spanList[0] as TextSpan).text, equals(''));
      expect((spanList[0] as TextSpan).style!.fontWeight, isNull);

      // Ensure that the second span is a TextSpan with the text "Welcome" in bold.
      expect(spanList[1], isA<TextSpan>());
      expect((spanList[1] as TextSpan).text, equals('Welcome'));
      expect((spanList[1] as TextSpan).style!.fontWeight, equals(FontWeight.bold));

      // Ensure that the third span is a TextSpan with the text " to " with the default fontWeight.
      expect(spanList[2], isA<TextSpan>());
      expect((spanList[2] as TextSpan).text, equals(' to '));
      expect((spanList[2] as TextSpan).style!.fontWeight, isNull);

      // Ensure that the fourth span is a TextSpan with the text "SuperEditor" in bold.
      expect(spanList[3], isA<TextSpan>());
      expect((spanList[3] as TextSpan).text, equals('SuperEditor'));
      expect((spanList[3] as TextSpan).style!.fontWeight, equals(FontWeight.bold));

      // Expect that the fifth span is the widget rendered using the placeholder.
      expect(spanList[4], isA<WidgetSpan>());
    });
  });
}

List<InlineSpan> _flattenInlineSpan(InlineSpan inlineSpan) {
  final flatList = <InlineSpan>[];

  inlineSpan.visitChildren((child) {
    flatList.add(child);
    return true;
  });

  return flatList;
}

class _ExamplePlaceholder {
  const _ExamplePlaceholder();
}

Widget? _inlineWidgetBuilder(BuildContext context, TextStyle textStyle, Object placeholder) {
  return const SizedBox(width: 10);
}
