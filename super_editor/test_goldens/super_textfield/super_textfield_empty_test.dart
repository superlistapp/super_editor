import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_text_field.dart';

import '../test_tools_goldens.dart';

void main() {
  group("SuperTextField > empty >", () {
    // This desktop test is run on Android because it seems that the golden toolkit
    // only render real fonts on Android. To account for this, we explicitly configure
    // the SuperTextField to present as a desktop textfield.
    testGoldensOnAndroid("desktop > displays hint text with padding", (tester) async {
      // Use a Row as a wrapper to fill the available width.
      final builder = GoldenBuilder.column(
        wrap: (child) => Row(
          children: [child],
        ),
      )
        ..addScenario(
          'No padding',
          _buildEmptySingleLineTextField(
            padding: EdgeInsets.zero,
          ),
        )
        ..addScenario(
          'Small padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(10.0),
          ),
        )
        ..addScenario(
          'Large padding',
          _buildEmptySingleLineTextField(
            padding: const EdgeInsets.all(25.0),
          ),
        );
      await tester.pumpWidgetBuilder(builder.build());

      await screenMatchesGolden(tester, 'super_textfield_empty_hint_padding');
    });
  });
}

Widget _buildEmptySingleLineTextField({
  EdgeInsets? padding,
}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: 250,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.yellow,
        border: Border.all(),
      ),
      child: SuperTextField(
        textController: AttributedTextEditingController(),
        textStyleBuilder: (_) => const TextStyle(fontSize: 20, color: Colors.black, fontFamily: 'Roboto'),
        hintBuilder: (_) => Text(
          "Hint text...",
          style: defaultHintStyleBuilder({}),
        ),
        maxLines: 1,
        padding: padding,
        configuration: SuperTextFieldPlatformConfiguration.desktop,
      ),
    ),
  );
}
