import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../test/super_textfield/super_textfield_robot.dart';
import '../test_tools_goldens.dart';

void main() {
  group('SuperTextField', () {
    testGoldensOnAndroid('displays toolbar pointing down', (tester) async {
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

      // Select a word so that the popover toolbar appears.
      await tester.doubleTapAtSuperTextField(6);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFileWithPixelAllowance("goldens/super_textfield_ios_toolbar_pointing_down.png", 1),
      );
    });

    testGoldensOnAndroid('displays toolbar pointing up', (tester) async {
      // Pumps a widget tree with a SuperTextField at the top of the screen.
      await _pumpSuperTextfieldToolbarTestApp(
        tester,
        child: _buildSuperTextField(
          text: 'Arrow pointing up',
          configuration: SuperTextFieldPlatformConfiguration.iOS,
        ),
      );

      // Select a word so that the popover toolbar appears.
      await tester.doubleTapAtSuperTextField(6);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFileWithPixelAllowance("goldens/super_textfield_ios_toolbar_pointing_up.png", 3),
      );
    });
  });
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

Widget _buildSuperTextField({
  required String text,
  SuperTextFieldPlatformConfiguration? configuration,
}) {
  final controller = AttributedTextEditingController(
    text: AttributedText(text),
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
