import 'package:device_frame/device_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_goldens/flutter_test_goldens.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:slack/main.dart';
import 'package:slack/mobile_message_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  testGoldenSceneOnIOS("Slack chat magazine", (tester) async {
    final backgroundImage = await tester.loadImageFromFile("test_goldens/slack_bk.png");

    await Gallery(
      "Slack Clone",
      fileName: "slack_chat_magazine_layout",
      itemConstraints: BoxConstraints.tight(
        Devices.ios.iPhone16.screenSize,
      ),
      itemBoundsFinder: find.byType(MobileMessageEditor),
      layout: MagazineGoldenSceneLayout(
        featureTitle: "Slack Clone",
        featureFrameBuilder: (BuildContext context, Widget featuredGolden) {
          return DeviceFrame(
            device: Devices.ios.iPhone16,
            screen: featuredGolden,
          );
        },
        featureBackground: GoldenSceneBackground.widget(
          Image.memory(backgroundImage.bytes, fit: BoxFit.cover),
        ),
      ),
    )
        .itemFromWidget(
          description: "Chat Page",
          boundsFinder: find.byType(GoldenImageBounds),
          widget: SlackChatPage(),
        )
        .itemFromWidget(
          description: "Editor - Collapsed",
          widget: SlackChatPage(),
        )
        .itemFromWidget(
          description: "Editor - Focused, Empty, with Hint",
          widget: SlackChatPage(),
          setup: (tester) async {
            await tester.tap(find.byType(MobileMessageEditor));
            await tester.pumpAndSettle();
          },
        )
        .itemFromWidget(
          description: "Editor - Typing 'Hello, World!'",
          widget: SlackChatPage(),
          setup: (tester) async {
            await tester.tap(find.byType(MobileMessageEditor));
            await tester.pumpAndSettle();
            await tester.typeImeText("Hello, World!");
          },
        )
        .itemFromWidget(
          description: "Editor - Multiple lines",
          widget: SlackChatPage(),
          setup: (tester) async {
            await tester.tap(find.byType(MobileMessageEditor));
            await tester.pumpAndSettle();
            await tester.typeImeText("Hello, World!");
            await tester.pressEnterAdaptive();
            await tester.typeImeText("This is line two");
          },
        )
        .run(tester);
  });
}
