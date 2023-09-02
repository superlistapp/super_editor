import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperTextField', () {
    group('multi line', () {
      const multilineText = 'First Line\nSecond Line\nThird Line\nFourth Line';

      testWidgetsOnAllPlatforms('makes scrollview fill all the field width', (tester) async {
        await _pumpScaffold(
          tester,
          children: [
            _buildSuperTextField(
              text: multilineText,
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
          ],
        );
        await tester.pump();

        final textfieldWidth = tester.getSize(find.byType(SuperTextField)).width;
        final scrollViewWidth = tester.getSize(find.byType(SingleChildScrollView)).width;

        // Ensure the scrollview occupies all the available width rathen than
        // just width of the text.
        expect(scrollViewWidth, equals(textfieldWidth));
      });
    });
  });
}

Widget _buildSuperTextField({
  required String text,
  required TextAlign textAlign,
  SuperTextFieldPlatformConfiguration? configuration,
  int? maxLines,
}) {
  final controller = AttributedTextEditingController(
    text: AttributedText(text),
  );

  return SizedBox(
    width: double.infinity,
    child: SuperTextField(
      configuration: configuration,
      textController: controller,
      textAlign: textAlign,
      maxLines: maxLines,
      minLines: 1,
      lineHeight: 20,
      textStyleBuilder: (_) {
        return const TextStyle(
          color: Colors.black,
          fontSize: 20,
        );
      },
    ),
  );
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  required List<Widget> children,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(children: children),
      ),
    ),
  );
}
