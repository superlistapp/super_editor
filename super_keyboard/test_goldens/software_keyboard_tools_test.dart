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
        layout: ftlGridGoldenSceneLayout,
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
              child: const ColoredBox(color: Color(0xff020817)),
            ),
          )
          .itemFromWidget(
            description: "Two",
            widget: SoftwareKeyboardHeightSimulator(
              tester: tester,
              initialKeyboardState: KeyboardState.open,
              renderSimulatedKeyboard: true,
              child: const ColoredBox(color: Color(0xff020817)),
            ),
          )
          .itemFromWidget(
            description: "Three",
            widget: SoftwareKeyboardHeightSimulator(
              tester: tester,
              initialKeyboardState: KeyboardState.open,
              renderSimulatedKeyboard: true,
              child: const ColoredBox(color: Color(0xff020817)),
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

const ftlGridGoldenSceneLayout = GridGoldenSceneLayout(
  spacing: GridSpacing(around: EdgeInsets.all(48), between: 24),
  background: GoldenSceneBackground.color(Color(0xff01040d)),
  itemDecorator: _itemDecorator,
);

Widget _itemDecorator(
  BuildContext context,
  GoldenScreenshotMetadata metadata,
  Widget content,
) {
  return ColoredBox(
    color: const Color(0xff020817),
    child: IntrinsicWidth(
      child: PixelSnapColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelSnapAlign(
            alignment: Alignment.topLeft,
            child: content,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              metadata.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff1e293b),
                fontFamily: TestFonts.openSans,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
