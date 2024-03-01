import 'package:test/expect.dart';

import 'attributed_spans.dart';
import 'attribution.dart';

class ExpectedSpans {
  static const bold = NamedAttribution('bold');
  static const italics = NamedAttribution('italics');
  static const underline = NamedAttribution('underline');
  static const strikethrough = NamedAttribution('strikethrough');
  static const hashTag = NamedAttribution('hashTag');

  ExpectedSpans(
    List<String> spanTemplates,
  ) : _combinedSpans = [] {
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

  void expectSpans(AttributedSpans spans) {
    for (int characterIndex = 0; characterIndex < _combinedSpans.length; ++characterIndex) {
      for (int attributionIndex = 0; attributionIndex < _combinedSpans[characterIndex].length; ++attributionIndex) {
        // The attribution name is just a letter, like 'b', 'i', or 's'.
        final attributionName = _combinedSpans[characterIndex][attributionIndex];
        if (attributionName == '_') {
          continue;
        }

        Attribution namedAttribution;
        switch (attributionName) {
          case 'b':
            namedAttribution = bold;
            break;
          case 'i':
            namedAttribution = italics;
            break;
          case 's':
            namedAttribution = strikethrough;
            break;
          default:
            throw Exception('Unknown span template character: $attributionName');
        }

        if (!spans.hasAttributionAt(characterIndex, attribution: namedAttribution)) {
          // ignore: avoid_print
          print("SPAN MISMATCH: missing $namedAttribution at $characterIndex");
        }
        expect(spans.hasAttributionAt(characterIndex, attribution: namedAttribution), true);
      }
    }
  }
}
