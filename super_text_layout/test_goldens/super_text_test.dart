import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group("SuperText", () {
    group("text layout", () {
      testGoldens("renders a visual reference for non-visual tests", (tester) async {
        await _pumpThreeLinePlainText(tester);
        await screenMatchesGolden(tester, "SuperText-reference-render");
      });
    });
  });
}

Future<void> _pumpThreeLinePlainText(WidgetTester tester) async {
  await tester.pumpWidget(
    _buildScaffold(
      child: SuperText(
        key: _textKey,
        richText: _threeLineSpan,
      ),
    ),
  );
}

final _textKey = GlobalKey(debugLabel: "super_text");

const _threeLineSpan = TextSpan(
  text: "This is some text. It is explicitly laid out in\n" // Line indices: 0 -> 47/48 (upstream/downstream)
      "multiple lines so that we don't need to guess\n" // Line indices: 48 ->  93/94 (upstream/downstream)
      "where the layout forces a line break", // Line indices: 94 -> 130
  style: _testTextStyle,
);

const _testTextStyle = TextStyle(
  color: Color(0xFF000000),
  fontFamily: 'Roboto',
  fontSize: 20,
);

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: child,
      ),
    ),
  );
}
