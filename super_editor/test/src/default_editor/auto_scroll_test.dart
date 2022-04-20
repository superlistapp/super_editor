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

          // Setting initial fake screen size. The height will shrink later.
          var screenHeight = 844.0;
          const screenWidth = 390.0;

          const frameCount = 60;
          const shrinkPerFrame = 5.0;

          // Tap offset to select an arbitrary text position in the document.
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

          // Place a caret in the document
          await tester.tapAt(tapPosition);

          final unscrolledOffset = await _shrinkViewportAndEnsureVisibleCaret(
            tester: tester,
            frameCount: frameCount,
            shrinkPerFrame: shrinkPerFrame,
            width: screenWidth,
            height: screenHeight,
          );

          // After shrinking, screenHeight is reduced
          screenHeight = screenHeight - frameCount * shrinkPerFrame;

          final handleFinder = find.byType(BlinkingCaret);
          final handleOffset = tester.getTopLeft(handleFinder.last);

          final editorFinder = find.byType(SuperEditor);
          final editorOffset = tester.getTopLeft(editorFinder.last);

          final handleToEditorOffset = handleOffset - editorOffset;

          // Determine the caret's height. Related to the tapped text position
          const lineHeight = 18;

          // Dy from the SuperEditor to its Scrollable parent
          const editorOffsetDy = 212.0;

          // DragAutoScrollBoundary.trailing of default_editor in [AndroidDocumentTouchInteractor]
          const dragAutoScrollBoundary = 54.0;

          // The math was taken from [ensureOffsetIsVisible] in [document_gestures_touch.dart]
          // The [unscrolledOffset] is subtracted because at the last of the shrinking frame process,
          // the screenHeight (viewport) is reduced but it doesn't meet the condition to scroll
          expect(
            scrollController.offset,
            equals((handleToEditorOffset.dy + lineHeight) +
                dragAutoScrollBoundary -
                screenHeight +
                editorOffsetDy -
                unscrolledOffset),
          );
        });
      });
      group('iOS', () {
        testWidgets('maintain visible caret when the viewport is being minimized', (WidgetTester tester) async {
          final scrollController = ScrollController();

          // Setting initial fake screen size. The height will shrink later.
          var screenHeight = 844.0;
          const screenWidth = 390.0;

          const frameCount = 60;
          const shrinkPerFrame = 5.0;

          // Tap offset to select an arbitrary text position in the document.
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

          // Place a caret to the document
          await tester.tapAt(tapPosition);

          final unscrolledOffset = await _shrinkViewportAndEnsureVisibleCaret(
            tester: tester,
            frameCount: frameCount,
            shrinkPerFrame: shrinkPerFrame,
            width: screenWidth,
            height: screenHeight,
          );

          // After shrinking, screenHeight is reduced
          screenHeight = screenHeight - frameCount * shrinkPerFrame;

          final handleFinder = find.byType(BlinkingCaret);
          final handleOffset = tester.getTopLeft(handleFinder.last);

          final editorFinder = find.byType(SuperEditor);
          final editorOffset = tester.getTopLeft(editorFinder.last);

          final handleToEditorOffset = handleOffset - editorOffset;

          // Determine the caret's height. Related to the tapped text position
          const lineHeight = 18;

          // Dy from the SuperEditor to its Scrollable parent
          const editorOffsetDy = 212.0;

          // DragAutoScrollBoundary.trailing of default_editor in [iOSDocumentTouchInteractor]
          const dragAutoScrollBoundary = 54.0;

          // The math was taken from [ensureOffsetIsVisible] in [document_gestures_touch.dart]
          // The [unscrolledOffset] is subtracted because at the last of the shrinking frame process,
          // the screenHeight (viewport) is reduced but it doesn't meet the condition to scroll
          expect(
            scrollController.offset,
            equals((handleToEditorOffset.dy + lineHeight) +
                dragAutoScrollBoundary -
                screenHeight +
                editorOffsetDy -
                unscrolledOffset),
          );
        });
      });
    });
  });
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

/// Slowly reduces window size while ensuring the caret is being displayed
///
/// To mimic the keyboard showing behaviour, the window size will be shrinking
/// for a number of [frameCount], each time it reduces an amount of [shrinkPerFrame]
///
/// During the shrinking, the editor might not scroll on every frame.
/// Returns the total scroll offset of continuously not scrolling in those last frames.
Future<double> _shrinkViewportAndEnsureVisibleCaret({
  required WidgetTester tester,
  required int frameCount,
  required double shrinkPerFrame,
  required double width,
  required double height,
}) async {
  final handleFinder = find.byType(BlinkingCaret);

  int framesBeforeScroll = 0;
  double prevHandleOffsetDy = 0;

  for (var i = 0; i < frameCount; i++) {
    height -= shrinkPerFrame;
    tester.binding.window.physicalSizeTestValue = Size(width, height);
    await tester.pumpAndSettle();

    // Ensure visible caret
    final handleOffset = tester.getBottomLeft(handleFinder.last);

    expect(handleOffset.dy, lessThanOrEqualTo(height));

    if (prevHandleOffsetDy != handleOffset.dy) {
      // HandleOffset changed, means the editor scrolled
      framesBeforeScroll = 0;
      prevHandleOffsetDy = handleOffset.dy;
    } else {
      framesBeforeScroll++;
    }
  }
  // Returns the total scroll offset of continuously not scrolling in the last frames
  return framesBeforeScroll * shrinkPerFrame;
}
