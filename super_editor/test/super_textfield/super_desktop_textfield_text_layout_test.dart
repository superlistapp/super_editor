import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';

import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

void main() {
  group('SuperDesktopTextField', () {
    group('containing only one emoji', (){
      testWidgets("moves left with LEFT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢',
        );

        // Place caret after the emoji      
        await tester.placeCaretInSuperTextField(2);   

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 2),
        );   

        // Press left arrow key to move the selection to the beginning of the text
        await tester.pressLeftArrow();      

        // Ensure caret is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0)
        );         
      });

      testWidgets("expands selection with SHIFT + LEFT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢',
        );

        // Place caret after the emoji      
        await tester.placeCaretInSuperTextField(2); 

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 2),
        );      

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();      

        // Ensure that the emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 2,
            extentOffset: 0,
          ),
        );         
      });
    
      testWidgets("moves right with RIGHT ARROW", (tester) async {      
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢',
        );

        // Place caret before the emoji      
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0),
        );     

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();      

        // Ensure caret is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 2),
        );         
      });    

      testWidgets("expands selection with SHIFT + RIGHT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢',
        );

        // Place caret before the emoji
        await tester.placeCaretInSuperTextField(0);    

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0),
        );    

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();      

        // Ensure that the emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );         
      });

      testWidgets("selects the content double tap", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢',
        );

        await tester.doubleTapAtSuperTextField(0);             

        // Ensure that the emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );         
      });
    });

    group('containing only two consecutive emojis', (){
      testWidgets("moves left with LEFT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢🐢',
        );

        // Place caret after the second emoji      
        await tester.placeCaretInSuperTextField(4);   

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 4),
        );   

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();   

        // Ensure caret is between the two emojis
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 2),
        );    

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();   

        // Ensure caret is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0)
        );         
      });

      testWidgets("expands selection with SHIFT + LEFT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢🐢',
        );

        // Place caret after the second emoji    
        await tester.placeCaretInSuperTextField(4); 

        // Ensure we are at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 4),
        );      

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();   

        // Ensure that the last emoji is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 4,
            extentOffset: 2,
          ),
        );    

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow(); 

        // Ensure the whole text is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 4,
            extentOffset: 0,
          ),
        );         
      });    
    
      testWidgets("moves right with RIGHT ARROW", (tester) async {      
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢🐢',
        );

        // Place caret before the first emoji  
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0),
        );     

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();      

        // Ensure caret is between the two emojis
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 2),
        ); 

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();  

        // Ensure caret is at the end of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 4),
        );         
      });    
    
      testWidgets("expands selection with SHIFT + RIGHT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: '🐢🐢',
        );

        // Place caret before the first emoji
        await tester.placeCaretInSuperTextField(0);    

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0),
        );    

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();      

        // Ensure the first emoji is selected
         expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow(); 

        // Ensure we selected the whole text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 0,
            extentOffset: 4,
          ),
        );         
      });    
    });  

    group('containing emojis and non-emojis', (){
      testWidgets("moves left with LEFT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: 'a🐢b',
        );

        // Place caret at |b   
        await tester.placeCaretInSuperTextField(3);   

        // Ensure we are after the emoji
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 3),
        );   

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();   

        // Ensure we are between the emoji and the 'a'
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 1),
        );    

        // Press left arrow key to move the selection to the left
        await tester.pressLeftArrow();   

        // Ensure caret is at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0)
        );         
      });
    
      testWidgets("expands selection with SHIFT + LEFT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: 'a🐢b',
        );

        // Place caret at |b
        await tester.placeCaretInSuperTextField(3); 

        // Ensure we are after the emoji
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 3),
        );      

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow();   

        // Ensure we selected the emoji
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 3,
            extentOffset: 1,
          ),
        );    

        // Press shift + left arrow key to expand the selection to the left
        await tester.pressShiftLeftArrow(); 

        // Ensure "a🐢" is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 3,
            extentOffset: 0,
          ),
        );         
      });    
    
      testWidgets("moves right with RIGHT ARROW", (tester) async {      
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: 'a🐢b',
        );

        // Place caret at the beginning of the text    
        await tester.placeCaretInSuperTextField(0);

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0),
        );     

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();      

        // Ensure we are at a|
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 1),
        ); 

        // Press right arrow key to move the selection to the right
        await tester.pressRightArrow();  

        // Ensure caret is after the emoji
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 3),
        );         
      });    
    
      testWidgets("expands selection with SHIFT + RIGHT ARROW", (tester) async {           
        await _pumpSuperTextFieldEmojiTest(tester, 
          text: 'a🐢b',
        );

        // Place caret at the beginning of the text
        await tester.placeCaretInSuperTextField(0);    

        // Ensure we are at the beginning of the text
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection.collapsed(offset: 0),
        );    

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow();      

        // Ensure 'a' is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 0,
            extentOffset: 1,
          ),
        );

        // Press shift + right arrow key to expand the selection to the right
        await tester.pressShiftRightArrow(); 

        // Ensure "a🐢" is selected
        expect(
          SuperTextFieldInspector.findSelection(), 
          const TextSelection(
            baseOffset: 0,
            extentOffset: 3,
          ),
        );         
      });
    });
  });
}

Future<void> _pumpSuperTextFieldEmojiTest(
  WidgetTester tester, {
  required String text
}) async {
  final controller = AttributedTextEditingController(
    text: AttributedText(text: text),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(            
        body: SuperTextField(
          configuration: SuperTextFieldPlatformConfiguration.desktop,
          textController: controller,
          textStyleBuilder: (_) => const TextStyle(fontSize: 16),
        ),
      ),
    ),
  );
}

/// Compute the center (x,y) for the given document [position]
// Offset _getOffsetForPosition(GlobalKey docKey, DocumentPosition position){
//   final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
//   final docLayout = docKey.currentState as DocumentLayout;
//   final characterBox = docLayout.getRectForPosition(position);
//   return docBox.localToGlobal(characterBox!.center);
// }

// extension on WidgetTester {
//   Future<void> doubleTapAt(int offset) async {
//     await tapAt(offset);
//     await pump(kDoubleTapMinTime);
//     await tapAt(offset);
//   }  
// }