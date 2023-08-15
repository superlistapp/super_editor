import 'package:attributed_text/attributed_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/attributions.dart';

void main() {
  group('Default editor attributions', () {
    group('links', () {
      test('different link attributions cannot overlap', () {
        final text = AttributedText(
          text: 'one two three',
        );

        // Add link across "one two"
        text.addAttribution(
          LinkAttribution(url: Uri.parse('https://flutter.dev')),
          const SpanRange(start: 0, end: 6),
        );

        // Try to add a different link across "two three" and expect
        // an exception
        expect(() {
          text.addAttribution(
            LinkAttribution(url: Uri.parse('https://pub.dev')),
            const SpanRange(start: 4, end: 12),
          );
        }, throwsA(isA<IncompatibleOverlappingAttributionsException>()));
      });

      test('identical link attributions can overlap', () {
        final text = AttributedText(
          text: 'one two three',
        );

        final linkAttribution = LinkAttribution(url: Uri.parse('https://flutter.dev'));

        // Add link across "one two"
        text.addAttribution(
          linkAttribution,
          const SpanRange(start: 0, end: 6),
        );

        text.addAttribution(
          LinkAttribution(url: Uri.parse('https://flutter.dev')),
          const SpanRange(start: 4, end: 12),
        );

        expect(text.spans.hasAttributionsWithin(attributions: {linkAttribution}, start: 0, end: 12), true);
      });
    });
  });
}
