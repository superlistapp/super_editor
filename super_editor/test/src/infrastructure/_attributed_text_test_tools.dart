import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';

class ExpectedSpans {
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
            namedAttribution = boldAttribution;
            break;
          case 'i':
            namedAttribution = italicsAttribution;
            break;
          case 's':
            namedAttribution = strikethroughAttribution;
            break;
          default:
            throw Exception('Unknown span template character: $attributionName');
        }

        if (!spans.hasAttributionAt(characterIndex, attribution: namedAttribution)) {
          print("SPAN MISMATCH: missing $namedAttribution at $characterIndex");
        }
        expect(spans.hasAttributionAt(characterIndex, attribution: namedAttribution), true);
      }
    }
  }
}
