import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('SuperDesktopTextField', () {
    testWidgetsOnDesktop('has text cursor style while hovering over text', (tester) async {
      await _pumpGestureTestApp(tester);

      // Start a gesture outside SuperDesktopTextField bounds
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Ensure the cursor type is 'basic' when not hovering SuperDesktopTextField
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);

      // Hover over the text inside SuperDesktopTextField
      // TODO: add the ability to SuperTextFieldInspector to lookup an offset for a content position
      await gesture.moveTo(tester.getTopLeft(find.byType(SuperText)));
      await tester.pump();

      // Ensure the cursor type is 'text' when hovering the text
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);

      // Move outside SuperDesktopTextField bounds
      await gesture.moveTo(Offset.zero);

      // Ensure the cursor type is 'basic' again
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
    });

    testWidgetsOnDesktop('has text cursor style while hovering over empty space', (tester) async {
      await _pumpGestureTestApp(tester);

      // Start a gesture outside SuperDesktopTextField bounds
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Ensure the cursor type is 'basic' when not hovering SuperDesktopTextField
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);

      // Hover over the empty space within SuperDesktopTextField
      await gesture.moveTo(tester.getBottomRight(find.byType(SuperDesktopTextField)) - const Offset(10, 10));
      await tester.pump();

      // Ensure the cursor type is 'text' when hovering the empty space
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);

      // Move outside SuperDesktopTextField bounds
      await gesture.moveTo(Offset.zero);

      // Ensure the cursor type is 'basic' again
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
    });

    testWidgetsOnDesktop('has text cursor style while hovering over padding region', (tester) async {
      await _pumpGestureTestApp(tester, padding: 20.0);

      // Start a gesture outside SuperDesktopTextField bounds
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Ensure the cursor type is 'basic' when not hovering SuperDesktopTextField
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);

      // Hover over the padding within SuperDesktopTextField
      await gesture.moveTo(tester.getTopLeft(find.byType(SuperDesktopTextField)) + const Offset(10, 10));
      await tester.pump();

      // Ensure the cursor type is 'text' when hovering the padding
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);

      // Move outside SuperDesktopTextField bounds
      await gesture.moveTo(Offset.zero);

      // Ensure the cursor type is 'basic' again
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
    });
  });
}

/// Creates a test app with the given [padding] applied to [SuperDesktopTextField]
Future<void> _pumpGestureTestApp(WidgetTester tester, {double padding = 0.0}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Container(
          width: 300,
          padding: const EdgeInsets.all(20.0),
          child: SuperDesktopTextField(
            padding: EdgeInsets.all(padding),
            textController: AttributedTextEditingController(
              text: AttributedText("abc"),
            ),
            textStyleBuilder: (_) => const TextStyle(fontSize: 16),
          ),
        ),
      ),
    ),
  );
}
