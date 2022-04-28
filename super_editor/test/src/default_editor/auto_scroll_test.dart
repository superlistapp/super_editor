import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../_document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    group('auto-scroll', () {
      const screenSizeWithoutKeyboard = Size(390.0, 844.0);
      const screenSizeWithKeyboard = Size(390.0, 444.0);
      const keyboardExpansionFrameCount = 60;
      final shrinkPerFrame =
          (screenSizeWithoutKeyboard.height - screenSizeWithKeyboard.height) / keyboardExpansionFrameCount;

      testWidgets('on Android, keeps caret visible when keyboard appears', (WidgetTester tester) async {
        tester.binding.window
          ..physicalSizeTestValue = screenSizeWithoutKeyboard
          ..textScaleFactorTestValue = 1.0
          ..devicePixelRatioTestValue = 1.0;

        await tester.pumpWidget(
          const _SliverTestEditor(
            gestureMode: DocumentGestureMode.android,
          ),
        );

        // Select text near the bottom of the screen, where the keyboard will appear
        final tapPosition = Offset(screenSizeWithoutKeyboard.width / 2, screenSizeWithoutKeyboard.height - 1);
        await tester.tapAt(tapPosition);

        // Shrink the screen height, as if the keyboard appeared.
        await _simulateKeyboardAppearance(
          tester: tester,
          initialScreenSize: screenSizeWithoutKeyboard,
          shrinkPerFrame: shrinkPerFrame,
          frameCount: keyboardExpansionFrameCount,
        );

        // Ensure that the editor auto-scrolled to keep the caret visible.
        final handleFinder = find.byType(BlinkingCaret);
        final handleOffset = tester.getTopLeft(handleFinder.last);

        // Hard-code a reasonable line-height because carets do not currently
        // report their height.
        // TODO: look up the actual line height of the text at the selection extent
        // TODO: update caret implementation so that it reports its own height.
        const lineHeight = 18;

        final bottomOfCaret = handleOffset.dy + lineHeight;
        expect(bottomOfCaret, lessThanOrEqualTo(screenSizeWithKeyboard.height));
      });

      testWidgets('on iOS, keeps caret visible when keyboard appears', (WidgetTester tester) async {
        tester.binding.window
          ..physicalSizeTestValue = screenSizeWithoutKeyboard
          ..textScaleFactorTestValue = 1.0
          ..devicePixelRatioTestValue = 1.0;

        await tester.pumpWidget(
          const _SliverTestEditor(
            gestureMode: DocumentGestureMode.iOS,
          ),
        );

        // Select text near the bottom of the screen, where the keyboard will appear
        final tapPosition = Offset(screenSizeWithoutKeyboard.width / 2, screenSizeWithoutKeyboard.height - 1);
        await tester.tapAt(tapPosition);

        // Shrink the screen height, as if the keyboard appeared.
        await _simulateKeyboardAppearance(
          tester: tester,
          initialScreenSize: screenSizeWithoutKeyboard,
          shrinkPerFrame: shrinkPerFrame,
          frameCount: keyboardExpansionFrameCount,
        );

        // Ensure that the editor auto-scrolled to keep the caret visible.
        final handleFinder = find.byType(BlinkingCaret);
        final handleOffset = tester.getTopLeft(handleFinder.last);

        // Hard-code a reasonable line-height because carets do not currently
        // report their height.
        // TODO: look up the actual line height of the text at the selection extent
        // TODO: update caret implementation so that it reports its own height.
        const lineHeight = 18;

        final bottomOfCaret = handleOffset.dy + lineHeight;
        expect(bottomOfCaret, lessThanOrEqualTo(screenSizeWithKeyboard.height));
      });
    });
  });
}

/// Displays a [SuperEditor] within a parent [Scrollable], including additional
/// content above the [SuperEditor] and additional content on top of [Scrollable].
///
/// By including content above the [SuperEditor], it doesn't have the same origin as the parent [Scrollable].
///
/// By including content on top of [Scrollable], it doesn't have the origin at [Offset.zero].
class _SliverTestEditor extends StatefulWidget {
  const _SliverTestEditor({
    Key? key,
    required this.gestureMode,
  }) : super(key: key);

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
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 300),
          child: CustomScrollView(
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
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Slowly reduces window size to imitate the appearance of a keyboard.
Future<void> _simulateKeyboardAppearance({
  required WidgetTester tester,
  required Size initialScreenSize,
  required double shrinkPerFrame,
  required int frameCount,
}) async {
  // Shrink the height of the screen, one frame at a time.
  double keyboardHeight = 0.0;
  for (var i = 0; i < frameCount; i++) {
    // Shrink the height of the screen by a small amount.
    keyboardHeight += shrinkPerFrame;
    final currentScreenSize = (initialScreenSize - Offset(0, keyboardHeight)) as Size;
    tester.binding.window.physicalSizeTestValue = currentScreenSize;

    // Let the scrolling system auto-scroll, as desired.
    await tester.pumpAndSettle();
  }
}
