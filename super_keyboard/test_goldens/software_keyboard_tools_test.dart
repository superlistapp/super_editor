import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:super_keyboard/super_keyboard.dart';
import 'package:super_keyboard/super_keyboard_test.dart';

void main() {
  group("Super Keyboard > software keyboard > tools >", () {
    testGoldenSceneOnIOS("software keyboard stationary", (tester) async {
      await Gallery(
        "Software Keyboard (Stationary)",
        fileName: "keyboard-tools_keyboard-widget_stationary",
        layout: const GridGoldenSceneLayout(),
        // Item is the size of an iPhone 16 (DIP).
        itemConstraints: const BoxConstraints.tightFor(width: 393, height: 852),
        itemSetup: (tester) async => tester.pump(),
      )
          .itemFromWidget(
            description: "Open",
            widget: SoftwareKeyboardHeightSimulator(
              tester: tester,
              initialKeyboardState: KeyboardState.open,
              renderSimulatedKeyboard: true,
              child: const ColoredBox(color: Colors.white),
            ),
          )
          .run(tester);
    });

    testGoldenSceneOnIOS("keyboard widget opens and closes", (tester) async {
      await Timeline(
        "Software Keyboard Opens/Closes",
        fileName: "keyboard-tools_keyboard-widget_opens-and-closes",
        layout: const AnimationTimelineSceneLayout(
          rowBreakPolicy: AnimationTimelineRowBreak.beforeItemDescription("Start"),
        ),
        // Size of an iPhone 16 (DIP).
        windowSize: const Size(393, 852),
        itemScaffold: minimalTimelineItemScaffold,
      ) //
          .setupWithWidget(_buildKeyboardSimulatorScaffold(tester))
          // Open the keyboard.
          .takePhoto("Start")
          .tap(find.byType(TextField))
          .modifyScene((tester, _) async {
            await tester.pump();
          })
          .takePhotos(10, const Duration(milliseconds: 60))
          .takePhoto("Open")
          // Close the keyboard.
          .takePhoto("Start")
          .modifyScene((tester, _) async {
            await tester.tapAt(const Offset(50, 50));
          })
          .modifyScene((tester, _) async {
            await tester.pump();
          })
          .takePhotos(10, const Duration(milliseconds: 60))
          .takePhoto("Closed")
          .run(tester);
    });
  });
}

Widget _buildKeyboardSimulatorScaffold(WidgetTester tester) {
  return MaterialApp(
    home: SoftwareKeyboardHeightSimulator(
      tester: tester,
      animateKeyboard: true,
      renderSimulatedKeyboard: true,
      child: Scaffold(
        body: Builder(builder: (context) {
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: const Center(
              child: SizedBox(
                width: 250,
                child: TextField(),
              ),
            ),
          );
        }),
      ),
    ),
    debugShowCheckedModeBanner: false,
  );
}
