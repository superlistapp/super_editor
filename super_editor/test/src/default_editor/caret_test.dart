import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() { 
  //position at doc|ument
  const caretPosition = DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 46));

  group("SuperEditor", () {
    group('window resizing', () {
      const screenSizeBigger = Size(1000.0, 400.0);
      const screenSizeSmaller = Size(250.0, 400.0);  
      testWidgets('updates caret offset when selected position is displayed in a line below', (WidgetTester tester) async {          
        tester.binding.window
          ..devicePixelRatioTestValue = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSizeTestValue = screenSizeBigger;  
        await tester.pumpWidget(
          _createTestApp(
            gestureMode:  DocumentGestureMode.mouse, 
            initialPosition: caretPosition,
          ),
        );
        await tester.pumpAndSettle();            
        BlinkingCaret blinkingCaret = tester.widget<BlinkingCaret>(find.byType(BlinkingCaret));
        final initialCaretOffset = blinkingCaret.caretOffset ?? Offset.zero;            
        expect(initialCaretOffset.dx.floor(), 306);
        expect(initialCaretOffset.dy.floor(), 24);

        await _resizeWindow(
          tester: tester,             
          frameCount: 60, 
          initialScreenSize: screenSizeBigger,
          finalScreenSize: screenSizeSmaller
        );    

        blinkingCaret = tester.widget<BlinkingCaret>(find.byType(BlinkingCaret));      
        final finalCaretOffset = blinkingCaret.caretOffset ?? Offset.zero;      
        expect(finalCaretOffset.dx.floor(), 36);
        expect(finalCaretOffset.dy.floor(), 124);      
      });

      testWidgets('updates caret offset when selected position is displayed in a line above', (WidgetTester tester) async {          
        tester.binding.window
          ..devicePixelRatioTestValue = 1.0
          ..platformDispatcher.textScaleFactorTestValue = 1.0
          ..physicalSizeTestValue = screenSizeSmaller;              
        await tester.pumpWidget(
          _createTestApp(
            gestureMode: DocumentGestureMode.mouse, 
            initialPosition: caretPosition,
          ),
        );  
        await tester.pumpAndSettle();            
        BlinkingCaret blinkingCaret = tester.widget<BlinkingCaret>(find.byType(BlinkingCaret));
        final initialCaretOffset = blinkingCaret.caretOffset ?? Offset.zero;
        expect(initialCaretOffset.dx.floor(), 36);
        expect(initialCaretOffset.dy.floor(), 124);          

        await _resizeWindow(
          tester: tester,             
          frameCount: 60, 
          initialScreenSize: screenSizeSmaller,
          finalScreenSize: screenSizeBigger
        );    

        blinkingCaret = tester.widget<BlinkingCaret>(find.byType(BlinkingCaret));      
        final finalCaretOffset = blinkingCaret.caretOffset ?? Offset.zero;      
        expect(finalCaretOffset.dx.floor(), 306);
        expect(finalCaretOffset.dy.floor(), 24);
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

          final tapOffset = _getOffsetForPosition(docKey, caretPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          Finder caretFinder = find.byType(BlinkingCaret);
          final initialCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(initialCaretTopLeft.dx.floor(), 168);
          expect(initialCaretTopLeft.dy.floor(), 73);

          tester.binding.window.physicalSizeTestValue = screenSizeLandscape;
          await tester.pumpAndSettle(); 

          caretFinder = find.byType(BlinkingCaret);
          final finalCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(finalCaretTopLeft.dx.floor(), 510);
          expect(finalCaretTopLeft.dy.floor(), 48);               
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

          final tapOffset = _getOffsetForPosition(docKey, caretPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          Finder caretFinder = find.byType(BlinkingCaret);
          final initialCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(initialCaretTopLeft.dx.floor(), 510);
          expect(initialCaretTopLeft.dy.floor(), 48);

          tester.binding.window.physicalSizeTestValue = screenSizePortrait;
          await tester.pumpAndSettle(); 

          caretFinder = find.byType(BlinkingCaret);
          final finalCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(finalCaretTopLeft.dx.floor(), 168);
          expect(finalCaretTopLeft.dy.floor(), 73);           
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

          final tapOffset = _getOffsetForPosition(docKey, caretPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          Finder caretFinder = find.byType(BlinkingCaret);
          final initialCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(initialCaretTopLeft.dx.floor(), 167);
          expect(initialCaretTopLeft.dy.floor(), 73);

          tester.binding.window.physicalSizeTestValue = screenSizeLandscape;
          await tester.pumpAndSettle(); 

          caretFinder = find.byType(BlinkingCaret);
          final finalCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(finalCaretTopLeft.dx.floor(), 509);
          expect(finalCaretTopLeft.dy.floor(), 48);                
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

          final tapOffset = _getOffsetForPosition(docKey, caretPosition);
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();  

          Finder caretFinder = find.byType(BlinkingCaret);
          final initialCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(initialCaretTopLeft.dx.floor(), 509);
          expect(initialCaretTopLeft.dy.floor(), 48);               

          tester.binding.window.physicalSizeTestValue = screenSizePortrait;
          await tester.pumpAndSettle(); 

          caretFinder = find.byType(BlinkingCaret);
          final finalCaretTopLeft = tester.getTopLeft(caretFinder.last);      
          expect(finalCaretTopLeft.dx.floor(), 167);
          expect(finalCaretTopLeft.dy.floor(), 73);         
        });   
      });
    });  
  });
}

Widget _createTestApp({required DocumentGestureMode gestureMode, DocumentPosition? initialPosition, GlobalKey? docKey}){
  final editor = _createTestDocEditor();  
  final composer = DocumentComposer(
    initialSelection: initialPosition != null  
      ? DocumentSelection.collapsed(position: initialPosition) 
      : null,   
  );        
  return MaterialApp(
    home: Scaffold(
      body: SuperEditor(                
        documentLayoutKey: docKey,
        editor: editor,        
        composer: composer,
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