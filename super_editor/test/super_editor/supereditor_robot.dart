import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

/// Extensions on [WidgetTester] for interacting with a [SuperEditor] the way
/// a user would.
extension SuperEditorRobot on WidgetTester {
  /// Place the caret at the given [offset] in a paragraph with the given [nodeId],
  /// by simulating a user gesture.
  ///
  /// The simulated user gesture is probably a tap, but the only guarantee is that
  /// the caret is placed with a gesture.
  Future<void> placeCaretInParagraph(String nodeId, int offset, [Finder? superEditorFinder]) async {
    await _tapInParagraph(nodeId, offset, 1, superEditorFinder);
  }

  /// Simulates a double tap at the given [offset] within the paragraph with the given
  /// [nodeId].
  Future<void> doubleTapInParagraph(String nodeId, int offset, [Finder? superEditorFinder]) async {
    await _tapInParagraph(nodeId, offset, 2, superEditorFinder);
  }

  /// Simulates a triple tap at the given [offset] within the paragraph with the given
  /// [nodeId].
  Future<void> tripleTapInParagraph(String nodeId, int offset, [Finder? superEditorFinder]) async {
    await _tapInParagraph(nodeId, offset, 3, superEditorFinder);
  }

  Future<void> _tapInParagraph(String nodeId, int offset, int tapCount, [Finder? superEditorFinder]) async {
    late final Finder layoutFinder;
    if (superEditorFinder != null) {
      layoutFinder = find.descendant(of: superEditorFinder, matching: find.byType(SingleColumnDocumentLayout));
    } else {
      layoutFinder = find.byType(SingleColumnDocumentLayout);
    }
    final documentLayoutElement = layoutFinder.evaluate().single as StatefulElement;
    final documentLayout = documentLayoutElement.state as DocumentLayout;

    // Collect the various text UI artifacts needed to find the
    // desired caret offset.
    final textComponentState = documentLayout.getComponentByNodeId(nodeId) as State;
    final textComponentKey = textComponentState.widget.key as GlobalKey;
    final textLayout = (textComponentKey.currentState as TextComponentState).textLayout;
    final textRenderBox = textComponentKey.currentContext!.findRenderObject() as RenderBox;

    // Calculate the global tap position based on the TextLayout and desired
    // TextPosition.
    final position = TextPosition(offset: offset);
    // For the local tap offset, we add a small vertical adjustment downward. This
    // prevents flaky edge effects, which might occur if we try to tap exactly at the
    // top of the line. In general, we could use the caret height to choose a vertical
    // offset, but the caret height is null when the text is empty. So we use a
    // hard-coded value, instead.
    final localTapOffset = textLayout.getOffsetForCaret(position) + const Offset(0, 5);
    final globalTapOffset = localTapOffset + textRenderBox.localToGlobal(Offset.zero);

    // Tap the desired number of times in SuperEditor at the given position.
    for (int i = 0; i < tapCount; i += 1) {
      await tapAt(globalTapOffset);
      await pump(kTapMinTime + const Duration(milliseconds: 1));
    }

    await pumpAndSettle();
  }
}
