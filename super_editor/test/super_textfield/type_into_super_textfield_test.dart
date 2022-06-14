import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';

import 'super_textfield_robot.dart';

void main() {
  group("SuperTextField", () {
    group("test typing", () {
      testWidgets("in empty field", (tester) async {
        await _pumpDesktopScaffold(tester);

        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();
        await tester.typeKeyboardText("Hello, World!");

        expect(find.text("Hello, World!", findRichText: true), findsOneWidget);
      });

      testWidgets("symbol characters", (tester) async {
        await _pumpDesktopScaffold(tester);

        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();
        await tester.typeKeyboardText("@");

        expect(find.text("@", findRichText: true), findsOneWidget);
        expect(find.text("2", findRichText: true), findsNothing);
      });

      testWidgets("in middle of existing text", (tester) async {
        await _pumpDesktopScaffold(
          tester,
          AttributedTextEditingController(
            text: AttributedText(text: "hello world"),
          ),
        );
        await tester.placeCaretInSuperTextField(6);
        await tester.pumpAndSettle();
        await tester.typeKeyboardText("new ");

        expect(find.text("hello new world", findRichText: true), findsOneWidget);
      });

      testWidgets("doesn't support Android", (tester) async {
        await _pumpAndroidScaffold(tester);

        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();
        await tester.typeKeyboardText("a");

        expect(find.text("a", findRichText: true), findsNothing);
      });

      testWidgets("doesn't support iOS", (tester) async {
        await _pumpIOSScaffold(tester);

        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();
        await tester.typeKeyboardText("a");

        expect(find.text("a", findRichText: true), findsNothing);
      });
    });
  });
}

Future<void> _pumpDesktopScaffold(WidgetTester tester, [AttributedTextEditingController? controller]) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

  await _pumpScaffold(
    tester,
    SuperTextField(
      textController: controller,
      controlsColor: Colors.blue,
      selectionColor: Colors.lightBlueAccent,
    ),
  );

  debugDefaultTargetPlatformOverride = null;
}

Future<void> _pumpAndroidScaffold(WidgetTester tester, [ImeAttributedTextEditingController? controller]) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  await _pumpScaffold(
    tester,
    SuperTextField(
      textController: controller,
      controlsColor: Colors.blue,
      selectionColor: Colors.lightBlueAccent,
      lineHeight: 24,
    ),
  );

  debugDefaultTargetPlatformOverride = null;
}

Future<void> _pumpIOSScaffold(WidgetTester tester, [ImeAttributedTextEditingController? controller]) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

  await _pumpScaffold(
    tester,
    SuperTextField(
      textController: controller,
      selectionColor: Colors.lightBlueAccent,
      controlsColor: Colors.blue,
      lineHeight: 24,
    ),
  );

  debugDefaultTargetPlatformOverride = null;
}

Future<void> _pumpScaffold(WidgetTester tester, Widget textField) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: textField,
          ),
        ),
      ),
    ),
  );
}
