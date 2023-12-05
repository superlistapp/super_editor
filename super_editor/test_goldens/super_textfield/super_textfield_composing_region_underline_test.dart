import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools_goldens.dart';

void main() {
  group("SuperTextField > composing region >", () {
    testGoldensOnAndroid("is underlined", _composingRegionIsUnderlined);
    testGoldensOniOS("is underlined", _composingRegionIsUnderlined);
    testGoldensOnMac("is underlined", _composingRegionIsUnderlined);
  });

  group("SuperTextField > composing region >", () {
    testGoldensOnWindows("shows nothing", _composingRegionShowsNothing);
    testGoldensOnLinux("shows nothing", _composingRegionShowsNothing);
  });
}

Future<void> _composingRegionIsUnderlined(WidgetTester tester) async {
  final textController = AttributedTextEditingController(
    text: AttributedText("Typing with composing a"),
  );
  await _pumpScaffold(tester, textController);

  textController
    ..selection = const TextSelection.collapsed(offset: 23)
    ..composingRegion = const TextRange(start: 22, end: 23);
  await tester.pumpAndSettle();

  // Ensure the composing region is underlined.
  // await screenMatchesGolden(
  //     tester, "super-text-field_composing-region-shows-underline_${defaultTargetPlatform.name}_1");
  await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFileWithPixelAllowance(
          "goldens/super-text-field_composing-region-shows-underline_${defaultTargetPlatform.name}_1.png", 1));

  textController.composingRegion = const TextRange.collapsed(-1);
  await tester.pump();

  // Ensure the underline disappeared now that the composing region is null.
  await screenMatchesGolden(
      tester, "super-text-field_composing-region-shows-underline_${defaultTargetPlatform.name}_2");
}

Future<void> _composingRegionShowsNothing(WidgetTester tester) async {
  final textController = AttributedTextEditingController(
    text: AttributedText("Typing with composing a"),
  );
  await _pumpScaffold(tester, textController);

  textController
    ..selection = const TextSelection.collapsed(offset: 23)
    ..composingRegion = const TextRange(start: 22, end: 23);
  await tester.pumpAndSettle();

  // Ensure that no underline is shown.
  await screenMatchesGolden(
      tester, "super-text-field_composing-region-underline-shows-nothing_${defaultTargetPlatform.name}");
}

Future<void> _pumpScaffold(
  WidgetTester tester,
  AttributedTextEditingController textController,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SuperTextField(
              textController: textController,
              textStyleBuilder: (_) => const TextStyle(
                color: Colors.black,
                // Use Roboto so that goldens show real text
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
