import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';

import '../test_tools.dart';

void main() {
  group("SuperTextField", () {
    testWidgetsOnDesktop("keeps caret solid while typing", (tester) async{
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;

      // duration to switch between visible and invisible
      const flashPeriod = Duration(milliseconds: 500);
      
      // interval between each key is pressed
      // here we add one millissecond because BlinkController checks if the 
      // ellapsed time is bigger than the flash period
      final typingInterval = (flashPeriod ~/ 2) + const Duration(milliseconds: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(            
            body: SuperTextField(              
              textStyleBuilder: (_) => const TextStyle(fontSize: 16),                        
            ),
          ),
        ),
      );

      // Press tab to focus SuperTextField
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Ensure caret is visible at start      
      expect(_isCaretVisible(tester), true);

      // Trigger a frame with an ellapsed time greater than the flashPeriod,
      // so the caret should change from visible to invisible
      await tester.pump(flashPeriod + const Duration(milliseconds: 1));

      // Ensure caret is invisible after the flash period
      expect(_isCaretVisible(tester), false);

      // Trigger another frame to make caret visible again
      await tester.pump(flashPeriod + const Duration(milliseconds: 1));

      // Ensure caret is visible
      expect(_isCaretVisible(tester), true);
     
      // Type and 'wait' for ~ half a period
      await tester.typeKeyboardText("a");
      await tester.pump(typingInterval);

      // After typing caret should stay visible
      expect(_isCaretVisible(tester), true); 

      // Type and 'wait' for ~ half a period to end the first full period
      await tester.typeKeyboardText("b");
      await tester.pump(typingInterval);

      // Ensure typing prevented caret from disappearing
      expect(_isCaretVisible(tester), true); 

      // Type and 'wait' for ~ half a period
      await tester.typeKeyboardText("c");
      await tester.pump(typingInterval);

      // After typing caret should stay visible
      expect(_isCaretVisible(tester), true); 

      // Type and 'wait' for ~ half a period to end the second full period
      await tester.typeKeyboardText("d");
      await tester.pump(typingInterval);

      // Ensure typing prevented caret from disappearing
      expect(_isCaretVisible(tester), true); 

      BlinkController.indeterminateAnimationsEnabled = false;
    });
  });
}

bool _isCaretVisible(WidgetTester tester){
  final customPaint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is CaretPainter);
  final caretPainter = tester.widget<CustomPaint>(customPaint.last).painter as CaretPainter;
  return caretPainter.blinkController!.opacity == 1.0;  
}