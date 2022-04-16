import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../_document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    group('auto-scroll', () {
      group('Android', () {
        testWidgets('maintain visible caret when the viewport is being minimized', (WidgetTester tester) async {
          final scrollController = ScrollController();

          // Setting initial fake screen size. The height would shrink later on.
          // The size should be set properly so that when the _SliverTestEditor is layed out,
          // the document is within bottom of the viewport.
          var screenHeight = 844.0;
          const screenWidth = 390.0;

          const frameCount = 60;
          const shrinkPerFrame = 5.0;

          // The position should be in the middle bottom of the screen, so that
          // if the document is layed out properly, tapping this position should place a caret to the document.
          // dy should be less than height to prevent tapping outside the screen
          final tapPosition = Offset(screenWidth / 2, screenHeight - 1);

          tester.binding.window
            ..physicalSizeTestValue = Size(screenWidth, screenHeight)
            ..textScaleFactorTestValue = 1.0
            ..devicePixelRatioTestValue = 1.0;

          final testEditor = _SliverTestEditor(
            scrollController: scrollController,
            gestureMode: DocumentGestureMode.android,
          );

          await tester.pumpWidget(testEditor);
          await tester.pumpAndSettle();

          // Place a caret to the document
          await tester.tapAt(tapPosition);
          await tester.pumpAndSettle();

          screenHeight = await _shrinkViewportAndEnsureVisibleCaret(
            tester,
            frameCount,
            shrinkPerFrame,
            screenWidth,
            screenHeight,
          );

          expect(scrollController.offset, greaterThanOrEqualTo(tapPosition.dy - screenHeight));
        });
      });
      group('iOS', () {
        testWidgets('maintain visible caret when the viewport is being minimized', (WidgetTester tester) async {
          final scrollController = ScrollController();

          // Setting initial fake screen size. The height would shrink later on.
          // The size should be set properly so that when the _SliverTestEditor is layed out,
          // the document is within bottom of the viewport.
          var screenHeight = 844.0;
          const screenWidth = 390.0;

          const frameCount = 60;
          const shrinkPerFrame = 5.0;

          // The position should be in the middle bottom of the screen, so that
          // if the document is layed out properly, tapping this position should place a caret to the document.
          // dy should be less than height to prevent tapping outside the screen
          final tapPosition = Offset(screenWidth / 2, screenHeight - 1);

          tester.binding.window
            ..physicalSizeTestValue = Size(screenWidth, screenHeight)
            ..textScaleFactorTestValue = 1.0
            ..devicePixelRatioTestValue = 1.0;

          final testEditor = _SliverTestEditor(
            scrollController: scrollController,
            gestureMode: DocumentGestureMode.iOS,
          );

          await tester.pumpWidget(testEditor);
          await tester.pumpAndSettle();

          // Place a caret to the document
          await tester.tapAt(tapPosition);
          await tester.pumpAndSettle();

          screenHeight = await _shrinkViewportAndEnsureVisibleCaret(
            tester,
            frameCount,
            shrinkPerFrame,
            screenWidth,
            screenHeight,
          );

          expect(scrollController.offset, greaterThanOrEqualTo(tapPosition.dy - screenHeight));
        });
      });
    });
  });
}

/// Slowly reduce screen size and pump
/// To mimic keyboard showing behaviour
/// Return the reduced height
Future<double> _shrinkViewportAndEnsureVisibleCaret(
  WidgetTester tester,
  int frameCount,
  double shrinkPerFrame,
  double width,
  double height,
) async {
  final handleFinder = find.byType(BlinkingCaret);

  for (var i = 0; i < frameCount; i++) {
    height -= shrinkPerFrame;
    tester.binding.window.physicalSizeTestValue = Size(width, height);
    await tester.pumpAndSettle();

    // Ensure visible caret
    final handleBox = handleFinder.evaluate().last.renderObject as RenderBox;
    final handleOffset = handleBox.localToGlobal(Offset.zero);

    expect(handleOffset.dy, lessThanOrEqualTo(height));
  }

  return height;
}

class _SliverTestEditor extends StatefulWidget {
  const _SliverTestEditor({
    Key? key,
    this.scrollController,
    required this.gestureMode,
  }) : super(key: key);

  final ScrollController? scrollController;
  final DocumentGestureMode gestureMode;

  @override
  State<_SliverTestEditor> createState() => _SliverTestEditorState();
}

class _SliverTestEditorState extends State<_SliverTestEditor> {
  late Document _doc;
  late DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();

    _doc = createExampleDocument();
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
                  return ListTile(title: Text('$index'));
                },
              ),
            ),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
