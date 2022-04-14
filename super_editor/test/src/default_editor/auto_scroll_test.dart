import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperEditor', () {
    group('auto-scroll', () {
      group('Android', () {
        testAutoScroll(
          'maintain visible caret when the viewport is being minimized',
          DocumentGestureMode.android,
        );
      });
      group('iOS', () {
        testAutoScroll(
          'maintain visible caret when the viewport is being minimized',
          DocumentGestureMode.iOS,
        );
      });
    });
  });
}

void testAutoScroll(
  String description,
  DocumentGestureMode gestureMode,
) {
  testWidgets(description, (WidgetTester tester) async {
    final scrollController = ScrollController();

    var height = 844.0;
    const width = 390.0;
    const tapDy = 800.0;

    tester.binding.window
      ..physicalSizeTestValue = Size(width, height)
      ..textScaleFactorTestValue = 1.0
      ..devicePixelRatioTestValue = 1.0;

    final testEditor = SliverTestEditor(
      scrollController: scrollController,
      gestureMode: gestureMode,
    );

    await tester.pumpWidget(testEditor);
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0.0);

    // Tap at the middle bottom of the screen
    await tester.tapAt(const Offset(width / 2, tapDy));
    await tester.pumpAndSettle();

    // Slowly reduce screen size and pump
    // To mimic keyboard showing behaviour
    for (var i = 0; i < 30; i++) {
      height -= 10;
      tester.binding.window.physicalSizeTestValue = Size(width, height);
      await tester.pumpAndSettle();

      // Maintain visible caret
      final handleFinder = find.byType(
        gestureMode == DocumentGestureMode.iOS ? IOSCollapsedHandle : AndroidSelectionHandle,
      );
      expect(handleFinder.evaluate(), isNotEmpty);
    }

    expect(scrollController.offset, greaterThanOrEqualTo(tapDy - height));
  });
}

class SliverTestEditor extends StatefulWidget {
  const SliverTestEditor({
    Key? key,
    this.scrollController,
    required this.gestureMode,
  }) : super(key: key);

  final ScrollController? scrollController;
  final DocumentGestureMode gestureMode;

  @override
  State<SliverTestEditor> createState() => SliverTestEditorState();
}

class SliverTestEditorState extends State<SliverTestEditor> {
  late Document _doc;
  late DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();

    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
  }

  @override
  void dispose() {
    widget.scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverAppBar(
              title: const Text(
                'Rich Text Editor Sliver Example',
              ),
              expandedHeight: 200.0,
              leading: const SizedBox(),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(color: Colors.blue),
              ),
            ),
            const SliverToBoxAdapter(
              child: Text(
                'Lorem Ipsum Dolor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SliverToBoxAdapter(
              child: SuperEditor(
                editor: _docEditor,
                stylesheet: defaultStylesheet.copyWith(
                  documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                ),
                gestureMode: widget.gestureMode,
                inputSource: DocumentInputSource.ime,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return ListTile(
                    title: Text('$index'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'SliverList element tapped with index $index.',
                          ),
                          duration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  Document _createInitialDocument() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text: 'Example Document',
          ),
          metadata: {
            'blockType': header1Attribution,
          },
        ),
        HorizontalRuleNode(id: DocumentEditor.createNodeId()),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text:
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
          ),
        ),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
              text:
                  'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
        ),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text:
                'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
          ),
        ),
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text:
                'Etiam id lacus interdum, efficitur ex convallis, accumsan ipsum. Integer faucibus mollis mauris, a suscipit ante mollis vitae. Fusce justo metus, congue non lectus ac, luctus rhoncus tellus. Phasellus vitae fermentum orci, sit amet sodales orci. Fusce at ante iaculis nunc aliquet pharetra. Nam placerat, nisl in gravida lacinia, nisl nibh feugiat nunc, in sagittis nisl sapien nec arcu. Nunc gravida faucibus massa, sit amet accumsan dolor feugiat in. Mauris ut elementum leo.',
          ),
        ),
      ],
    );
  }
}
