import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

import '../../test/super_textfield/super_textfield_robot.dart';

void main() {
  group('SuperTextField', () {
    testGoldens('displays toolbar pointing down', (tester) async {
      // Pumps a widget tree with a SuperTextField at the bottom of the screen.
      await _pumpSuperTextfieldToolbarTestApp(
        tester,
        child: Positioned(
          bottom: 50,
          child: _buildSuperTextField(
            text: 'Arrow pointing down',
            configuration: SuperTextFieldPlatformConfiguration.iOS,
          ),
        ),
      );

      // Double tap to select "pointing".
      await tester.doubleTapAtSuperTextField(6);

      await screenMatchesGolden(tester, 'super_textfield_ios_toolbar_pointing_down');
    });

    testGoldens('displays toolbar pointing up', (tester) async {
      // Pumps a widget tree with a SuperTextField at the top of the screen.
      await _pumpSuperTextfieldToolbarTestApp(
        tester,
        child: _buildSuperTextField(
          text: 'Arrow pointing up',
          configuration: SuperTextFieldPlatformConfiguration.iOS,
        ),
      );

      // Double tap to select "pointing".
      await tester.doubleTapAtSuperTextField(6);

      await screenMatchesGolden(tester, 'super_textfield_ios_toolbar_pointing_up');
    });
  });
}

Widget _buildSuperTextField({
  required String text,
  SuperTextFieldPlatformConfiguration? configuration,
}) {
  final controller = AttributedTextEditingController(
    text: AttributedText(text: text),
  );

  return SizedBox(
    width: 300,
    child: SuperTextField(
      configuration: configuration,
      textController: controller,
      maxLines: 1,
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

/// Pumps a widget tree which displays the [child] inside a [Stack].
Future<void> _pumpSuperTextfieldToolbarTestApp(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [child],
        ),
      ),
    ),
  );
}
