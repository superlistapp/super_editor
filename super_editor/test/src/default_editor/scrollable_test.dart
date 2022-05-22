import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main(){
  group('SuperEditor', (){
    group('with a constrained maxHeight inside a scrollable widget', (){
      group('on desktop', (){ 
        testWidgets('has it\'s own scrollview', (WidgetTester tester) async {          
          await tester.pumpWidget(
            _createTestApp(
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
            _createTestApp(
              gestureMode: DocumentGestureMode.mouse,
            )
          );          

          // As long as this test completes without an error, SuperEditor didn't
          // overflew it's available space   
        });
      });   
    
      group('on Android',(){
        testWidgets('has it\' own scrollview', (WidgetTester tester) async { 
          await tester.pumpWidget(
            _createTestApp(
              gestureMode: DocumentGestureMode.android,
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
            _createTestApp(
              gestureMode: DocumentGestureMode.android,
            )
          );
          
          // As long as this test completes without an error, SuperEditor didn't
          // overflew it's available space  
        });        
      });

      group('on iOS',(){
        testWidgets('has it\'s own scrollview', (WidgetTester tester) async { 
          await tester.pumpWidget(
            _createTestApp(
              gestureMode: DocumentGestureMode.iOS,
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
            _createTestApp(
              gestureMode: DocumentGestureMode.iOS,
            )
          );

          // As long as this test completes without an error, SuperEditor didn't
          // overflew it's available space  
        });
      });
    });
  });
}

/// Creates an app with a [SuperEditor] with height constraints inside a [SingleChildScrollView]
/// with content that doesn't fit on the available space
Widget _createTestApp({required DocumentGestureMode gestureMode}){
  final editor = _createTestDocEditor();   
  return MaterialApp(
    home: Scaffold(
      body: Container(
        color: Colors.blue,       
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ...List.generate(5, (_) => const Text('text')),
                Container(
                  height: 300,
                  width: 300,
                  color: Colors.white,
                  child: SuperEditor(
                    editor: editor,                    
                    gestureMode: gestureMode,                    
                  ),
                ),
                ...List.generate(5, (_) => const Text('text')),
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
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        ),
      )
    ],
  );
}