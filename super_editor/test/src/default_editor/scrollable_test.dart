import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main(){  
  group('SuperEditor', (){    
    group('with a constrained maxHeight inside a scrollable widget', (){
      group('on desktop', (){ 
        testWidgets('has it\'s own scrollview', (WidgetTester tester) async {          
          await tester.pumpWidget(
            _createConstrainedHeightTestApp(
              gestureMode: DocumentGestureMode.mouse            
            )
          );

          // Ensure SuperEditor has it's own ScrollView        
          expect(
            find.descendant(
              of: find.byType(SuperEditor), 
              matching: find.byType(SingleChildScrollView),              
            ), findsOneWidget);        
        });

        testWidgets('doesn\'t overflow if it\'s content doesn\'t fit on the available space', (WidgetTester tester) async { 
          await tester.pumpWidget(
            _createConstrainedHeightTestApp(
              gestureMode: DocumentGestureMode.mouse,
            )
          );          

          // As long as this test completes without an error, SuperEditor didn't
          // overflew it's available space   
        });
          
        testWidgets('keeps it\'s selected line visible when adding lines before the selection', (WidgetTester tester) async{          
          final docKey = GlobalKey();
          final containerKey = GlobalKey();
          await tester.pumpWidget(
            _createConstrainedHeightTestApp(
              gestureMode: DocumentGestureMode.mouse,
              docKey: docKey,
              containerKey: containerKey,
            )
          );

          // Place selection at a position that will be pushed beyond vertical bounds
          const tapPosition = DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0));
          final tapOffset = _getOffsetForPosition(docKey, tapPosition);          
          await tester.tapAt(tapOffset);        
          await tester.pumpAndSettle();

          // Create new lines, pushing the selected line out of container bounds
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);        
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);   
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);   
          await tester.pumpAndSettle();

          // Ensure that after adding lines, the selected line is still visible
          Offset lineTopLeft = tester.getTopLeft(find.textContaining('Lorem ipsum', findRichText: true).last);          
          Offset containerBottomLeft = tester.getBottomLeft(find.byKey(containerKey).last);          
          expect(lineTopLeft.dy, lessThan(containerBottomLeft.dy));                  
        });     

        testWidgets('scrolls it\'s content before scrolling the ancestor scrollview', (WidgetTester tester) async{
          final docKey = GlobalKey();
          final parentContainerKey = GlobalKey();
          final parentScrollableController = ScrollController();

          await tester.pumpWidget(
            _createConstrainedHeightTestApp(
              gestureMode: DocumentGestureMode.mouse,
              docKey: docKey,
              containerKey: parentContainerKey,
              scrollViewController: parentScrollableController,
            )
          );           
          
          // Scrolls down with an offset big enough to scroll the whole
          // editor's content and the ancestor scrollable content
          await _scroll(
            tester: tester,
            origin: tester.getCenter(find.byType(SuperEditor)), 
            offset: const Offset(0, 6000),
            stepCount: 100,
          );                   

          // Ensure SuperEditor's own ScrollView has scrolled to the end          
          final lastParagraphBottomLeft = tester.getBottomLeft(find.textContaining('Ut enim ad minim veniam', findRichText: true).last);                     
          final parentContainerBottomLeft = tester.getBottomLeft(find.byKey(parentContainerKey).last);                    
          expect(lastParagraphBottomLeft.dy, parentContainerBottomLeft.dy);        

          // Ensure ancestor Scrollable has also scrolled to the end
          expect(parentScrollableController.position.atEdge, true);
          expect(parentScrollableController.position.pixels, greaterThan(0.0));
        });
      });            
    });
  
    group('with unconstrained height inside a scrollable widget', () {
      group('on desktop', () {
        testWidgets('scroll\'s its ancestor scrollview to the end', (WidgetTester tester) async{                  
          final docKey = GlobalKey();  
          final parentScrollableController = ScrollController();

          await tester.pumpWidget(
            _createUnconstrainedHeightTestApp(
              gestureMode: DocumentGestureMode.mouse,
              docKey: docKey,      
              scrollViewController: parentScrollableController,
            )
          );           
          
          // Scrolls down with an offset big enough to scroll the whole scrollview
          await _scroll(
            tester: tester,
            origin: tester.getCenter(find.byType(SuperEditor)), 
            offset: const Offset(0, 6000),
            stepCount: 100,
          );                   

          // Ensure ancestor Scrollable has scrolled to the end
          expect(parentScrollableController.position.atEdge, true);
          expect(parentScrollableController.position.pixels, greaterThan(0.0));
        });
      });
    });
  });
}

/// Creates an app with a [SuperEditor] without height constraints inside a [SingleChildScrollView]
Widget _createConstrainedHeightTestApp({
    required DocumentGestureMode gestureMode, 
    GlobalKey? docKey, 
    GlobalKey? containerKey,
    ScrollController? editorScrollController,
    ScrollController? scrollViewController,
  }){
  final editor = _createTestDocEditor();   
  return MaterialApp(    
    home: Scaffold(
      body: Container(
        color: Colors.blue,       
        height: 600,        
        child: Center(
          child: SingleChildScrollView(
            controller: scrollViewController,
            child: Column(
              children: [
                ...List.generate(5, (index) => Text('text $index')),
                Container(
                  key: containerKey,
                  height: 200,
                  width: 200,
                  color: Colors.white,
                  child: SuperEditor(
                    editor: editor,                    
                    gestureMode: gestureMode,   
                    inputSource: DocumentInputSource.keyboard,                 
                    documentLayoutKey: docKey,
                    scrollController: editorScrollController,
                  ),
                ),
                ...List.generate(100, (index) => Text('text $index')),
              ],
            ),
          ),
        ),
      ),
    ),
  );              
}

/// Creates an app with a [SuperEditor] with height constraints inside a [SingleChildScrollView]
/// with content that doesn't fit on the available space
Widget _createUnconstrainedHeightTestApp({
    required DocumentGestureMode gestureMode, 
    GlobalKey? docKey,     
    ScrollController? editorScrollController,
    ScrollController? scrollViewController,
  }){
  final editor = _createTestDocEditor();   
  return MaterialApp(    
    home: Scaffold(
      body: Container(
        color: Colors.blue,       
        height: 600,        
        child: Center(
          child: SingleChildScrollView(
            controller: scrollViewController,
            child: Column(
              children: [
                ...List.generate(5, (index) => Text('text $index')),
                SuperEditor(
                  editor: editor,                    
                  gestureMode: gestureMode,   
                  inputSource: DocumentInputSource.keyboard,                 
                  documentLayoutKey: docKey,
                  scrollController: editorScrollController,
                ),
                ...List.generate(100, (index) => Text('text $index')),
              ],
            ),
          ),
        ),
      ),
    ),
  );              
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
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        ),
      ),
      ParagraphNode(
        id: '2',
        text: AttributedText(
          text:
              "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        ),
      )
    ],
  );
}

/// Compute the center (x,y) for the given document [position]
Offset _getOffsetForPosition(GlobalKey docKey, DocumentPosition position){
  final docBox = docKey.currentContext!.findRenderObject() as RenderBox;
  final docLayout = docKey.currentState as DocumentLayout;
  final characterBox = docLayout.getRectForPosition(position);
  return docBox.localToGlobal(characterBox!.center);
}

Future<void> _scroll({
  required WidgetTester tester,
  required Offset origin,
  required Offset offset,  
  required int stepCount,
}) async {  
  final dxPerStep = offset.dx / stepCount;
  final dyPerStep = offset.dy / stepCount;
  final gesture = await tester.startGesture(origin);  
  await tester.pumpAndSettle();  
  for (var i = 0; i < stepCount; i++) { 
    await gesture.moveBy(Offset(dxPerStep, dyPerStep));
    await tester.pump();
    // doing a second pump instead of pumpAndSettle because auto-scrolling seems
    // to cause pumpAndSettle to timeout
    await tester.pump();    
  }
  await gesture.up(); 
  await tester.pumpAndSettle();
}
