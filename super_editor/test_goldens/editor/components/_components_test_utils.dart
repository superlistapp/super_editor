import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void testComponentGolden(String description, Widget componentBuilder, String fileName) {
  testGoldens(description, (tester) async {
    tester.binding.window
      ..physicalSizeTestValue = const Size(600, 400)
      ..devicePixelRatioTestValue = 1.0;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: componentBuilder,
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );

    await screenMatchesGolden(tester, fileName);
  });
}
