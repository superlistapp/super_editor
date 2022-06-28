import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';

import '../test_tools.dart';

void main() { 
  group("SuperTextField", () {    
    // Duration to switch between visible and invisible
    const flashPeriod = Duration(milliseconds: 500);

    testWidgetsOnDesktop("caret blinks at rest", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

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

      // Trigger a frame with an ellapsed time equal to the flashPeriod,
      // so the caret should change from visible to invisible
      await tester.pump(flashPeriod);

      // Ensure caret is invisible after the flash period
      expect(_isCaretVisible(tester), false);

      // Trigger another frame to make caret visible again
      await tester.pump(flashPeriod);

      // Ensure caret is visible
      expect(_isCaretVisible(tester), true);
    });

    testWidgetsOnDesktop("keeps caret solid while typing", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);      
      
      // Interval between each key is pressed.      
      final typingInterval = (flashPeriod ~/ 2);

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
     
      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("a");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true); 

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("b");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true); 

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("c");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true); 

      // Type after half of the flash period
      await tester.pump(typingInterval);
      await tester.typeKeyboardText("d");
      // Ensure that typing keeps caret visible
      expect(_isCaretVisible(tester), true); 
    });
  });
}

bool _isCaretVisible(WidgetTester tester){
  final customPaint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is CaretPainter);
  final caretPainter = tester.widget<CustomPaint>(customPaint.last).painter as CaretPainter;
  return caretPainter.blinkController!.opacity == 1.0;  
}