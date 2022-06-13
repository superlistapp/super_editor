import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

/// Extensions on [WidgetTester] for interacting with a [SuperEditor] the way
/// a user would.
extension SuperEditorRobot on WidgetTester {
  Future<void> placeCaretInParagraph(String nodeId, int offset, [Finder? superEditorFinder]) async {
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

    // Tap the SuperEditor where the caret should be placed.
    await tapAt(globalTapOffset);
    await pumpAndSettle();
  }
}
