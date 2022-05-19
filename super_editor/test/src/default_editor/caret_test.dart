import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() { 
  group("SuperEditor", () {
    // We're testing the automatic movement of the caret when the available space changes. This
    // text position sits at a location that should move to a different line when the available space
    // is reduced.
    const textPosition = TextPosition(offset: 46);
    final tapPosition = DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: textPosition.offset));

    group('window resizing', () {
      const screenSizeBigger = Size(1000.0, 400.0);
      const screenSizeSmaller = Size(250.0, 400.0);

      testWidgets('moves caret to next line when available width contracts', (WidgetTester tester) async {          
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

        // Place caret at a position that will move to the next line when the width contracts
        final tapOffset = _getOffsetForPosition(docKey, tapPosition);
        await tester.tapAt(tapOffset);        
        await tester.pumpAndSettle();
        
        // Ensure that the caret is displayed at the correct (x,y) in the document before resizing the window
        final initialCaretOffset = _getCurrentDesktopCaretOffset(tester);
        final expectedInitialCaretOffset = _computeExpectedDesktopCaretOffset(tester, textPosition);
        expect(initialCaretOffset, expectedInitialCaretOffset); 

        // Make the window more narrow, pushing the caret text position down a line.
        await _resizeWindow(
          tester: tester,             
          frameCount: 60, 
          initialScreenSize: screenSizeBigger,
          finalScreenSize: screenSizeSmaller
        );    
      
        // Ensure that after resizing the window, the caret updated its (x,y) to match the text
        // position that was pushed down to the next line.
        final finalCaretOffset = _getCurrentDesktopCaretOffset(tester);
        final expectedFinalCaretOffset = _computeExpectedDesktopCaretOffset(tester, textPosition);
        expect(finalCaretOffset, expectedFinalCaretOffset);        
      });

      testWidgets('moves caret to preceding line when available width expands', (WidgetTester tester) async {          
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

        // Place caret at a position that will move to the preceding line when the width expands
        final tapOffset = _getOffsetForPosition(docKey, tapPosition);
        await tester.tapAt(tapOffset);        
        await tester.pumpAndSettle();

        // Ensure that the caret is displayed at the correct (x,y) in the document before resizing the window
        final initialCaretOffset = _getCurrentDesktopCaretOffset(tester);
        final expectedInitialCaretOffset = _computeExpectedDesktopCaretOffset(tester, textPosition);
        expect(initialCaretOffset, expectedInitialCaretOffset); 

        // Make the window wider, pushing the caret text position up a line.
        await _resizeWindow(
          tester: tester,             
          frameCount: 60, 
          initialScreenSize: screenSizeSmaller,
          finalScreenSize: screenSizeBigger
        );    
        
        // Ensure that after resizing the window, the caret updated its (x,y) to match the text
        // position that was pushed up to the preceding line.
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

          // Place caret at a position that will move to the preceding line when the width expands
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          // Ensure that the caret is displayed at the correct (x,y) in the document before phone rotation
          final initialCaretOffset = _getCurrentAndroidCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialCaretOffset, expectedInitialCaretOffset); 

          // Make the window wider, pushing the caret text position up a line.
          tester.binding.window.physicalSizeTestValue = screenSizeLandscape;
          await tester.pumpAndSettle(); 

          // Ensure that after rotating the phone, the caret updated its (x,y) to match the text
          // position that was pushed up to the preceding line.
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

          // Place caret at a position that will move to the next line when the width contracts
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          // Ensure that the caret is displayed at the correct (x,y) in the document before phone rotation
          final initialCaretOffset = _getCurrentAndroidCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialCaretOffset, expectedInitialCaretOffset); 

          // Make the window more narrow, pushing the caret text position up a line.
          tester.binding.window.physicalSizeTestValue = screenSizePortrait;
          await tester.pumpAndSettle(); 

          // Ensure that after rotating the phone, the caret updated its (x,y) to match the text
          // position that was pushed down to the next line.
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

          // Place caret at a position that will move to the preceding line when the width expands
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          // Ensure that the caret is displayed at the correct (x,y) in the document before phone rotation
          final initialOffset = _getIosCurrentCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialOffset, expectedInitialCaretOffset); 

          // Make the window wider, pushing the caret text position up a line.
          tester.binding.window.physicalSizeTestValue = screenSizeLandscape;
          await tester.pumpAndSettle(); 

          // Ensure that after rotating the phone, the caret updated its (x,y) to match the text
          // position that was pushed up to the preceding line.
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

          // Place caret at a position that will move to the next line when the width contracts
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          // Ensure that the caret is displayed at the correct (x,y) in the document before phone rotation
          final initialOffset = _getIosCurrentCaretOffset(tester);
          final expectedInitialCaretOffset = _computeExpectedMobileCaretOffset(tester, docKey, tapPosition);
          expect(initialOffset, expectedInitialCaretOffset);              

          // Make the window more narrow, pushing the caret text position down a line.
          tester.binding.window.physicalSizeTestValue = screenSizePortrait;
          await tester.pumpAndSettle(); 

          // Ensure that after rotating the phone, the caret updated its (x,y) to match the text
          // position that was pushed down to the next line.
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

/// Compute the center (x,y) for the given document [position]
Offset _getOffsetForPosition(GlobalKey docKey, DocumentPosition position){
  final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
  final docLayout = docKey.currentState as DocumentLayout;
  final characterBox = docLayout.getRectForPosition(position);
  return docBox.localToGlobal(characterBox!.center);
}

/// Find the caret in the widget tree and return it's (x,y)
/// 
/// Should be used only when the document gesture mode is equal to [DocumentGestureMode.mouse]
/// 
/// The reason for having different implementations is that depending on the gesture mode,
/// the widget that holds the caret offset is different
Offset _getCurrentDesktopCaretOffset(WidgetTester tester){
  final customPaint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is CaretPainter);
  final caretPainter = tester.widget<CustomPaint>(customPaint.last).painter as CaretPainter;
  return caretPainter.offset!;  
}

/// Find the caret in the widget tree and return it's (x,y)
/// 
/// Should be used only when the document gesture mode is equal to [DocumentGestureMode.android]
/// 
/// The reason for having different implementations is that depending on the gesture mode,
/// the widget that holds the caret offset is different
Offset _getCurrentAndroidCaretOffset(WidgetTester tester){
  final controls = tester.widget<AndroidDocumentTouchEditingControls>(find.byType(AndroidDocumentTouchEditingControls).last);   
  return controls.editingController.caretTop!;
}

/// Find the caret in the widget tree and return it's (x,y)
/// 
/// Should be used only when the document gesture mode is equal to [DocumentGestureMode.iOS]
/// 
/// The reason for having different implementations is that depending on the gesture mode,
/// the widget that holds the caret offset is different
Offset _getIosCurrentCaretOffset(WidgetTester tester){
  final controls = tester.widget<IosDocumentTouchEditingControls>(find.byType(IosDocumentTouchEditingControls).last);  
  return controls.editingController.caretTop!;
}

/// Given a [textPosition], compute the expected (x,y) for the caret
/// 
/// Should be used only when the document gesture mode is equal to [DocumentGestureMode.mouse]
Offset _computeExpectedDesktopCaretOffset(WidgetTester tester, TextPosition textPosition){
  final textLayoutCaret = tester.widget<TextLayoutCaret>(find.byType(TextLayoutCaret).last);
  return textLayoutCaret.textLayout.getOffsetForCaret(textPosition);  
}

/// Given a [textPosition], compute the expected (x,y) for the caret
/// 
/// Should be used only when the document gesture mode is equal to [DocumentGestureMode.android]
/// or [DocumentGestureMode.iOS]
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