import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '_components_test_utils.dart';

void main() {
  group('editor', () {
    group('components', () {
      testComponentGolden(
        'text with hint',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextWithHintComponent(
              text: AttributedText(text: ''),
              textStyleBuilder: _textStyleBuilder,
              hintText: AttributedText(text: "this is a hint..."),
              hintStyleBuilder: (_) => _hintStyle,
            ),
            const SizedBox(height: 24),
            TextWithHintComponent(
              text: AttributedText(text: 'This is content text.'),
              textStyleBuilder: _textStyleBuilder,
              hintText: AttributedText(text: "this is a hint..."),
              hintStyleBuilder: (_) => _hintStyle,
            ),
          ],
        ),
        'text_with_hint',
      );
    });
  });
}

const _hintStyle = TextStyle(
  color: Color(0xFFDDDDDD),
);

TextStyle _textStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle(
    color: Color(0xFF000000),
    fontFamily: 'Roboto',
    fontSize: 40,
  );
}
