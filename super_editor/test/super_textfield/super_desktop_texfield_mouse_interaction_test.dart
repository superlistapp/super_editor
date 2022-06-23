import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../test_tools.dart';

void main() {
  group('SuperDesktopTextField', () {
    testWidgetsOnDesktop('has text cursor style while hovering text', (tester) async {
      final gesture = await _pumpGestureTestApp(tester);

      // Ensure the cursor type is 'basic' when not hovering SuperDesktopTextField
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
      
      // Hover the text inside SuperDesktopTextField
      await gesture.moveTo(tester.getCenter(find.byType(SuperText)));
      await tester.pump();

      // Ensure the cursor type is 'text' when hovering the text
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);

      // Move outside SuperDesktopTextField bounds
      await gesture.moveTo(Offset.zero);

      // Ensure the cursor type is 'basic' again
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
    });

    testWidgetsOnDesktop('has text cursor style while hovering empty space', (tester) async {
      final gesture = await _pumpGestureTestApp(tester);

      // Ensure the cursor type is 'basic' when not hovering SuperDesktopTextField
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
      
      // Hover the empty space within SuperDesktopTextField        
      await gesture.moveTo(tester.getTopRight(find.byType(SuperText)) + const Offset(10, 0));
      await tester.pump();

      // Ensure the cursor type is 'text' when hovering the empty space
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);

      // Move outside SuperDesktopTextField bounds
      await gesture.moveTo(Offset.zero);

      // Ensure the cursor type is 'basic' again
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
    });

    testWidgetsOnDesktop('has text cursor style while hovering padding region', (tester) async {
      final gesture = await _pumpGestureTestApp(tester, padding: 20.0);

      // Ensure the cursor type is 'basic' when not hovering SuperDesktopTextField
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
      
      // Hover the padding within SuperDesktopTextField
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
/// and starts a mouse gesture at (0, 0)
Future<TestGesture> _pumpGestureTestApp(WidgetTester tester, {
  double padding = 0.0
}) async {
  await tester.pumpWidget(
    MaterialApp(          
      home: Scaffold(
        body: Container(
          width: 300,
          padding: const EdgeInsets.all(20.0),
          child: SuperDesktopTextField(              
            padding: EdgeInsets.all(padding),
            textController: AttributedTextEditingController(
              text: AttributedText(text: "abc"),
            ),
            textStyleBuilder: (_) => const TextStyle(fontSize: 16),
          ),        
        ), 
      ),
    ),
  );

  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);      
  await tester.pump();

  return gesture;
}

