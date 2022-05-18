import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/super_editor.dart';

void main() { 
  // position at doc|ument. When the screen is resized this word will move between lines
  const textPosition = TextPosition(offset: 46);
  final tapPosition = DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: textPosition.offset));  

  group("SuperEditor", () {
    group('window resizing', () {
      const screenSizeBigger = Size(1000.0, 400.0);
      const screenSizeSmaller = Size(250.0, 400.0);

      testWidgets('updates caret offset when selected position is displayed in a line below', (WidgetTester tester) async {          
        tester.binding.window
          ..devicePixelRatioTestValue = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSizeTestValue = screenSizeBigger;

        final docKey = GlobalKey();
        await tester.pumpWidget(
          _createTestApp(
            gestureMode:  DocumentGestureMode.mouse,
            docKey: docKey,
          ),
        );
        await tester.pumpAndSettle();

        // simulate a tap at doc|ument
        final tapOffset = _getOffsetForPosition(docKey, tapPosition);
        await tester.tapAt(tapOffset);        
        await tester.pumpAndSettle();
        
        final initialCaretOffset = _getCurrentDesktopCaretOffset(tester);
        final expectedInitialCaretOffset = _computeExpectedDesktopCaretOffset(tester, textPosition);
        expect(initialCaretOffset, expectedInitialCaretOffset); 

        await _resizeWindow(
          tester: tester,             
          frameCount: 60, 
          initialScreenSize: screenSizeBigger,
          finalScreenSize: screenSizeSmaller
        );    
      
        final finalCaretOffset = _getCurrentDesktopCaretOffset(tester);
        final expectedFinalCaretOffset = _computeExpectedDesktopCaretOffset(tester, textPosition);
        expect(finalCaretOffset, expectedFinalCaretOffset);        
      });

      testWidgets('updates caret offset when selected position is displayed in a line above', (WidgetTester tester) async {          
        tester.binding.window
          ..devicePixelRatioTestValue = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSizeTestValue = screenSizeSmaller;

        final docKey = GlobalKey();
        await tester.pumpWidget(
          _createTestApp(
            gestureMode: DocumentGestureMode.mouse,
            docKey: docKey, 
          ),
        );  
        await tester.pumpAndSettle();

        // simulate a tap at doc|ument
        final tapOffset = _getOffsetForPosition(docKey, tapPosition);
        await tester.tapAt(tapOffset);        
        await tester.pumpAndSettle();

        final initialCaretOffset = _getCurrentDesktopCaretOffset(tester);
        final expectedInitialCaretOffset = _computeExpectedDesktopCaretOffset(tester, textPosition);
        expect(initialCaretOffset, expectedInitialCaretOffset); 

        await _resizeWindow(
          tester: tester,             
          frameCount: 60, 
          initialScreenSize: screenSizeSmaller,
          finalScreenSize: screenSizeBigger
        );    
        
        final finalCaretOffset = _getCurrentDesktopCaretOffset(tester);
        final expectedFinalCaretOffset = _computeExpectedDesktopCaretOffset(tester, textPosition);
        expect(finalCaretOffset, expectedFinalCaretOffset);   
      });
    });

    group('phone rotation', () {
      const screenSizePortrait = Size(400.0, 1000.0);
      const screenSizeLandscape = Size(1000.0, 400);
          
      group('on Android', () {    
        testWidgets('from portrait to landscape updates caret position', (WidgetTester tester) async {  
          tester.binding.window
            ..devicePixelRatioTestValue = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSizeTestValue = screenSizePortrait;    

          final docKey = GlobalKey();
          await tester.pumpWidget(
            _createTestApp(
              gestureMode: DocumentGestureMode.android, 
              docKey: docKey,              
            ),
          );           
          await tester.pumpAndSettle();              

          // simulate a tap at doc|ument
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          final initialCaretOffset = _getCurrentAndroidCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialCaretOffset, expectedInitialCaretOffset); 

          tester.binding.window.physicalSizeTestValue = screenSizeLandscape;
          await tester.pumpAndSettle(); 

          final finalCaretOffset = _getCurrentAndroidCaretOffset(tester);
          final expectedFinalCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(finalCaretOffset, expectedFinalCaretOffset);               
        });    

        testWidgets('from landscape to portrait updates caret position', (WidgetTester tester) async {
          tester.binding.window
            ..devicePixelRatioTestValue = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSizeTestValue = screenSizeLandscape;    

          final docKey = GlobalKey();
          await tester.pumpWidget(
            _createTestApp(
              gestureMode: DocumentGestureMode.android, 
              docKey: docKey,              
            ),
          );              
          await tester.pumpAndSettle();              

          // simulate a tap at doc|ument
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          final initialCaretOffset = _getCurrentAndroidCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialCaretOffset, expectedInitialCaretOffset); 

          tester.binding.window.physicalSizeTestValue = screenSizePortrait;
          await tester.pumpAndSettle(); 

          final finalCaretOffset = _getCurrentAndroidCaretOffset(tester);
          final expectedFinalCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(finalCaretOffset, expectedFinalCaretOffset);           
        });   
      });

      group('on iOS', () {      
        testWidgets('from portrait to landscape updates caret position', (WidgetTester tester) async {  
          tester.binding.window
            ..devicePixelRatioTestValue = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSizeTestValue = screenSizePortrait;    

          final docKey = GlobalKey();
          await tester.pumpWidget(
            _createTestApp(
              gestureMode: DocumentGestureMode.iOS, 
              docKey: docKey,              
            ),
          );    
          await tester.pumpAndSettle();              

          // simulate a tap at doc|ument
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          final initialOffset = _getIosCurrentCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialOffset, expectedInitialCaretOffset); 

          tester.binding.window.physicalSizeTestValue = screenSizeLandscape;
          await tester.pumpAndSettle(); 

          final finalCaretOffset = _getIosCurrentCaretOffset(tester);
          final expectedFinalCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(finalCaretOffset, expectedFinalCaretOffset);                
        });    

        testWidgets('from landscape to portrait updates caret position', (WidgetTester tester) async {  
          tester.binding.window
            ..devicePixelRatioTestValue = 1.0
            ..platformDispatcher.textScaleFactorTestValue = 1.0
            ..physicalSizeTestValue = screenSizeLandscape;    

          final docKey = GlobalKey();
          await tester.pumpWidget(
            _createTestApp(
              gestureMode: DocumentGestureMode.iOS, 
              docKey: docKey,              
            ),
          );    
          await tester.pumpAndSettle();              

          // simulate a tap at doc|ument
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          final initialOffset = _getIosCurrentCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialOffset, expectedInitialCaretOffset);              

          tester.binding.window.physicalSizeTestValue = screenSizePortrait;
          await tester.pumpAndSettle(); 

          final finalCaretOffset = _getIosCurrentCaretOffset(tester);
          final expectedFinalCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(finalCaretOffset, expectedFinalCaretOffset);          
        });   
      });
    });  
  });
}

Widget _createTestApp({required DocumentGestureMode gestureMode, required GlobalKey docKey}){
  final editor = _createTestDocEditor();        
  return MaterialApp(
    home: Scaffold(
      body: SuperEditor(                
        documentLayoutKey: docKey,
        editor: editor,        
        gestureMode: gestureMode,                       
      ),
    ),
  );              
}

Offset _getOffsetForPosition(GlobalKey docKey, DocumentPosition position){
  final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
  final docLayout = docKey.currentState as DocumentLayout;
  final characterBox = docLayout.getRectForPosition(position);
  return docBox.localToGlobal(characterBox!.center);
}

Offset _getCurrentDesktopCaretOffset(WidgetTester tester){
  final blinkingCaret = tester.widget<BlinkingCaret>(find.byType(BlinkingCaret).last);      
  return blinkingCaret.caretOffset ?? Offset.zero;
}

Offset _getCurrentAndroidCaretOffset(WidgetTester tester){
  final controls = tester.widget<AndroidDocumentTouchEditingControls>(find.byType(AndroidDocumentTouchEditingControls).last);   
  return controls.editingController.caretTop!;
}

Offset _getIosCurrentCaretOffset(WidgetTester tester){
  final controls = tester.widget<IosDocumentTouchEditingControls>(find.byType(IosDocumentTouchEditingControls).last);  
  return controls.editingController.caretTop!;
}

Offset _computeExpectedDesktopCaretOffset(WidgetTester tester, TextPosition textPosition){
  final superText = tester.state<SuperSelectableTextState>(find.byType(SuperSelectableText));        
  return superText.getOffsetForCaret(textPosition);
}

Offset _computeExpectedMobileCaretOffset(WidgetTester tester, GlobalKey docKey, DocumentPosition documentPosition){
  final docLayout = docKey.currentState as DocumentLayout;
  final extentRect = docLayout.getRectForPosition(documentPosition)!;
  return Offset(extentRect.left, extentRect.top);
}

DocumentEditor _createTestDocEditor(){
  return DocumentEditor(document: _createTestDocument());  
}

MutableDocument _createTestDocument() {
  return MutableDocument(
    nodes: [          
      ParagraphNode(
        id: '1',
        text: AttributedText(
          text:              
              "Super Editor is a toolkit to help you build document editors, document layouts, text fields, and more.",
        ),
      )
    ],
   );
}

Future<void> _resizeWindow({
  required WidgetTester tester,
  required Size initialScreenSize,
  required Size finalScreenSize,  
  required int frameCount,
}) async {  
  double resizedWidth = 0.0;
  double resizedHeight = 0.0;
  double totalWidthResize = initialScreenSize.width - finalScreenSize.width;
  double totalHeightResize = initialScreenSize.height - finalScreenSize.height;
  double widthShrinkPerFrame = totalWidthResize / frameCount;
  double heightShrinkPerFrame = totalHeightResize / frameCount;  
  for (var i = 0; i < frameCount; i++) {    
    resizedWidth += widthShrinkPerFrame;
    resizedHeight += heightShrinkPerFrame;
    final currentScreenSize = (initialScreenSize - Offset(resizedWidth, resizedHeight)) as Size;
    tester.binding.window.physicalSizeTestValue = currentScreenSize;
    await tester.pumpAndSettle();
  }  
}