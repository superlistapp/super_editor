import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  group('Blockquote', () {
    testWidgets("applies the textStyle from SuperEditor's styleSheet", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: DocumentEditor(document: _singleBlockquoteDoc()),
              stylesheet: _styleSheet,
            ),
          ),
        ),
      );
        
      // Ensure that the textStyle from the styleSheet was applied
      expect(find.byType(LayoutAwareRichText), findsOneWidget);
      final richText = (find.byType(LayoutAwareRichText).evaluate().first.widget) as LayoutAwareRichText;      
      expect(richText.text.style!.color, Colors.blue);
      expect(richText.text.style!.fontSize, 16);
    });
  });
}

MutableDocument _singleBlockquoteDoc() => MutableDocument(
  nodes: [          
    ParagraphNode(
      id: '1',
      text: AttributedText(text: "This is a blockquote."),
      metadata: {'blockType': blockquoteAttribution},
    )
  ],
);

TextStyle _inlineTextStyler(Set<Attribution> attributions, TextStyle base) => base;
  
final _styleSheet = Stylesheet(
  inlineTextStyler: _inlineTextStyler,
  rules: [
    StyleRule(
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {              
          "textStyle": const TextStyle(
            color: Colors.blue,  
            fontSize: 16               
          ),
        };
      },
    ),
  ],
);