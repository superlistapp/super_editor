import 'package:example/spikes/editor_abstractions/core/attributed_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Attributed Text', () {
    group('Single attribution tests', () {
      test('applies attribution to full text', () {
        final text = AttributedText(
          text: 'this is some text',
        );

        text.addAttribution('bold', TextRange(start: 0, end: 16));

        expect(text.attributions.length, 2);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 0, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 16, markerType: AttributionMarkerType.end));
      });

      test('applies attribution to beginning text span', () {
        final text = AttributedText(
          text: 'this is some text',
        );

        text.addAttribution('bold', TextRange(start: 0, end: 7));

        expect(text.attributions.length, 2);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 0, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end));
      });

      test('applies attribution to inner text span', () {
        final text = AttributedText(
          text: 'this is some text',
        );

        text.addAttribution('bold', TextRange(start: 2, end: 7));

        expect(text.attributions.length, 2);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end));
      });

      test('applies attribution to ending text span', () {
        final text = AttributedText(
          text: 'this is some text',
        );

        text.addAttribution('bold', TextRange(start: 7, end: 16));

        expect(text.attributions.length, 2);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 16, markerType: AttributionMarkerType.end));
      });

      test('removes attribution from full text', () {
        final text = AttributedText(text: 'this is some text', attributions: [
          TextAttributionMarker(name: 'bold', offset: 0, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 16, markerType: AttributionMarkerType.end)
        ]);

        text.removeAttribution('bold', TextRange(start: 0, end: 16));

        expect(text.attributions.length, 0);
      });

      test('removes attribution from inner text span', () {
        final text = AttributedText(text: 'this is some text', attributions: [
          TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end)
        ]);

        text.removeAttribution('bold', TextRange(start: 2, end: 7));

        expect(text.attributions.length, 0);
      });

      test('removes attribution from partial beginning span', () {
        final text = AttributedText(text: 'this is some text', attributions: [
          TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end)
        ]);

        text.removeAttribution('bold', TextRange(start: 2, end: 4));

        expect(text.attributions.length, 2);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 5, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end));
      });

      test('removes attribution from partial inner span', () {
        final text = AttributedText(text: 'this is some text', attributions: [
          TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end)
        ]);

        text.removeAttribution('bold', TextRange(start: 4, end: 5));

        expect(text.attributions.length, 4);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 3, markerType: AttributionMarkerType.end));
        expect(text.attributions[2],
            TextAttributionMarker(name: 'bold', offset: 6, markerType: AttributionMarkerType.start));
        expect(text.attributions[3],
            TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end));
      });

      test('removes attribution from partial ending span', () {
        final text = AttributedText(text: 'this is some text', attributions: [
          TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end)
        ]);

        text.removeAttribution('bold', TextRange(start: 5, end: 7));

        expect(text.attributions.length, 2);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 4, markerType: AttributionMarkerType.end));
      });

      test('applies attribution when mixed span is toggled', () {
        final text = AttributedText(text: 'this is some text', attributions: [
          TextAttributionMarker(name: 'bold', offset: 8, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 16, markerType: AttributionMarkerType.end)
        ]);

        text.toggleAttribution('bold', TextRange(start: 0, end: 16));

        expect(text.attributions.length, 2);
        expect(text.attributions[0],
            TextAttributionMarker(name: 'bold', offset: 0, markerType: AttributionMarkerType.start));
        expect(text.attributions[1],
            TextAttributionMarker(name: 'bold', offset: 16, markerType: AttributionMarkerType.end));
      });

      test('removes attribution when contiguous span is toggled', () {
        final text = AttributedText(text: 'this is some text', attributions: [
          TextAttributionMarker(name: 'bold', offset: 0, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 16, markerType: AttributionMarkerType.end)
        ]);

        text.toggleAttribution('bold', TextRange(start: 0, end: 16));

        expect(text.attributions.length, 0);
      });
    });

    group('Multiple attribution tests', () {
      test('applies full length, concurrent attributions', () {
        final text = AttributedText(
          text: 'abcdefghij',
        );
        // TODO: split these into different tests.
        // text.addAttribution('b', TextRange(start: 0, end: 9));
        // text.addAttribution('i', TextRange(start: 0, end: 9));
        // final expectedAttributions = _ExpectedSpans([
        //   'bbbbbbbbbb',
        //   'iiiiiiiiii',
        // ]);

        // text.addAttribution('b', TextRange(start: 5, end: 9));
        // text.addAttribution('i', TextRange(start: 0, end: 4));
        // final expectedAttributions2 = _ExpectedSpans([
        //   '_____bbbbb',
        //   'iiiii_____',
        // ]);

        // text.addAttribution('b', TextRange(start: 4, end: 8));
        // text.addAttribution('i', TextRange(start: 1, end: 5));
        // final expectedAttributions3 = _ExpectedSpans([
        //   '____bbbbb_',
        //   '_iiiii____',
        // ]);

        // text.addAttribution('b', TextRange(start: 4, end: 8));
        // text.addAttribution('i', TextRange(start: 1, end: 5));
        // text.addAttribution('s', TextRange(start: 5, end: 9));
        // final expectedAttributions4 = _ExpectedSpans([
        //   '____bbbbb_',
        //   '_iiiii____',
        //   '_____sssss',
        // ]);

        text.addAttribution('b', TextRange(start: 0, end: 1));
        text.addAttribution('i', TextRange(start: 2, end: 3));
        text.addAttribution('s', TextRange(start: 4, end: 5));
        text.addAttribution('b', TextRange(start: 6, end: 7));
        text.addAttribution('i', TextRange(start: 8, end: 9));
        final expectedAttributions5 = _ExpectedSpans([
          'bb____bb__',
          '__ii____ii',
          '____ss____',
        ]);

        // expect(text.attributions.length, 6);
        expectedAttributions5.expectSpans(text);
      });
    });

    group('AttributedText to TextSpan', () {
      test('no styles', () {
        final text = AttributedText(
          text: 'abcdefghij',
        );
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, 'abcdefghij');
        expect(textSpan.children, null);
      });

      test('full-span style', () {
        final text = AttributedText(text: 'abcdefghij', attributions: [
          TextAttributionMarker(name: 'bold', offset: 0, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 9, markerType: AttributionMarkerType.end),
        ]);
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, 'abcdefghij');
        expect(textSpan.style.fontWeight, FontWeight.bold);
        expect(textSpan.children, null);
      });

      test('single character style', () {
        final text = AttributedText(text: 'abcdefghij', attributions: [
          TextAttributionMarker(name: 'bold', offset: 1, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 1, markerType: AttributionMarkerType.end),
        ]);
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, null);
        expect(textSpan.children.length, 3);
        expect(textSpan.children[0].toPlainText(), 'a');
        expect(textSpan.children[1].toPlainText(), 'b');
        expect(textSpan.children[1].style.fontWeight, FontWeight.bold);
        expect(textSpan.children[2].toPlainText(), 'cdefghij');
        expect(textSpan.children[2].style.fontWeight, null);
      });

      test('single character style - reverse order', () {
        final text = AttributedText(text: 'abcdefghij', attributions: [
          // Notice that the markers are provided in reverse order:
          // end then start. Order shouldn't matter within a single
          // position index. This test ensures that.
          TextAttributionMarker(name: 'bold', offset: 1, markerType: AttributionMarkerType.end),
          TextAttributionMarker(name: 'bold', offset: 1, markerType: AttributionMarkerType.start),
        ]);
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, null);
        expect(textSpan.children.length, 3);
        expect(textSpan.children[0].toPlainText(), 'a');
        expect(textSpan.children[1].toPlainText(), 'b');
        expect(textSpan.children[1].style.fontWeight, FontWeight.bold);
        expect(textSpan.children[2].toPlainText(), 'cdefghij');
        expect(textSpan.children[2].style.fontWeight, null);
      });

      test('add single character style', () {
        final text = AttributedText(text: 'abcdefghij');
        text.addAttribution('bold', TextRange(start: 1, end: 1));
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, null);
        expect(textSpan.children.length, 3);
        expect(textSpan.children[0].toPlainText(), 'a');
        expect(textSpan.children[1].toPlainText(), 'b');
        expect(textSpan.children[1].style.fontWeight, FontWeight.bold);
        expect(textSpan.children[2].toPlainText(), 'cdefghij');
        expect(textSpan.children[2].style.fontWeight, null);
      });

      test('partial style', () {
        final text = AttributedText(text: 'abcdefghij', attributions: [
          TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 7, markerType: AttributionMarkerType.end),
        ]);
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, null);
        expect(textSpan.children.length, 3);
        expect(textSpan.children[0].toPlainText(), 'ab');
        expect(textSpan.children[1].toPlainText(), 'cdefgh');
        expect(textSpan.children[1].style.fontWeight, FontWeight.bold);
        expect(textSpan.children[2].toPlainText(), 'ij');
      });

      test('non-mingled varying styles', () {
        final text = AttributedText(text: 'abcdefghij', attributions: [
          TextAttributionMarker(name: 'bold', offset: 0, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 4, markerType: AttributionMarkerType.end),
          TextAttributionMarker(name: 'italics', offset: 5, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'italics', offset: 9, markerType: AttributionMarkerType.end),
        ]);
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, null);
        expect(textSpan.children.length, 2);
        expect(textSpan.children[0].toPlainText(), 'abcde');
        expect(textSpan.children[0].style.fontWeight, FontWeight.bold);
        expect(textSpan.children[0].style.fontStyle, null);
        expect(textSpan.children[1].toPlainText(), 'fghij');
        expect(textSpan.children[1].style.fontWeight, null);
        expect(textSpan.children[1].style.fontStyle, FontStyle.italic);
      });

      test('intermingled varying styles', () {
        final text = AttributedText(text: 'abcdefghij', attributions: [
          TextAttributionMarker(name: 'bold', offset: 2, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'italics', offset: 4, markerType: AttributionMarkerType.start),
          TextAttributionMarker(name: 'bold', offset: 5, markerType: AttributionMarkerType.end),
          TextAttributionMarker(name: 'italics', offset: 7, markerType: AttributionMarkerType.end),
        ]);
        final textSpan = text.computeTextSpan();

        expect(textSpan.text, null);
        expect(textSpan.children.length, 5);
        expect(textSpan.children[0].toPlainText(), 'ab');
        expect(textSpan.children[0].style.fontWeight, null);
        expect(textSpan.children[0].style.fontStyle, null);

        expect(textSpan.children[1].toPlainText(), 'cd');
        expect(textSpan.children[1].style.fontWeight, FontWeight.bold);
        expect(textSpan.children[1].style.fontStyle, null);

        expect(textSpan.children[2].toPlainText(), 'ef');
        expect(textSpan.children[2].style.fontWeight, FontWeight.bold);
        expect(textSpan.children[2].style.fontStyle, FontStyle.italic);

        expect(textSpan.children[3].toPlainText(), 'gh');
        expect(textSpan.children[3].style.fontWeight, null);
        expect(textSpan.children[3].style.fontStyle, FontStyle.italic);

        expect(textSpan.children[4].toPlainText(), 'ij');
        expect(textSpan.children[4].style.fontWeight, null);
        expect(textSpan.children[4].style.fontStyle, null);
      });
    });
  });
}

class _ExpectedSpans {
  _ExpectedSpans(
    List<String> spanTemplates,
  ) {
    final templateLength = spanTemplates.first.length;
    for (final template in spanTemplates) {
      assert(template.length == templateLength);
    }

    // Collapse spanTemplates down into a single
    // list of character collections representing the
    // set of attributions at a given index.
    _combinedSpans = List.filled(templateLength, '');
    for (int i = 0; i < templateLength; ++i) {
      for (final template in spanTemplates) {
        if (_combinedSpans[i].isEmpty) {
          _combinedSpans[i] = template[i];
        } else if (_combinedSpans[i] == '_' && template[i] != '_') {
          _combinedSpans[i] = template[i];
        } else if (_combinedSpans[i] != '_' && template[i] != '_') {
          _combinedSpans[i] += template[i];
        }
      }
    }
  }

  List<String> _combinedSpans;

  void expectSpans(AttributedText text) {
    expect(text.text.length, _combinedSpans.length,
        reason: "Can't checks spans on the given text because its length is different than the span templates.");

    for (int characterIndex = 0; characterIndex < text.text.length; ++characterIndex) {
      for (int attributionIndex = 0; attributionIndex < _combinedSpans[characterIndex].length; ++attributionIndex) {
        print('Checking character $characterIndex');
        // The attribution name is just a letter, like 'b', 'i', or 's'.
        final attributionName = _combinedSpans[characterIndex][attributionIndex];
        print(' - looking for attribution: "$attributionName"');
        if (attributionName == '_') {
          print(' - skipping empty template character');
          continue;
        }

        expect(text.hasAttributionAt(characterIndex, name: attributionName), true);
      }
    }
  }
}
