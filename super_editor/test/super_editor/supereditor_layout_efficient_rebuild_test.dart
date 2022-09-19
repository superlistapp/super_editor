import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:logging/logging.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group("Super Editor layout rebuilds efficiently", () {
    testWidgetsOnAllPlatforms("when the caret moves within a paragraph", (tester) async {
      final buildTracker = await _pumpDocument(tester);
      await tester.placeCaretInParagraph("1", 0);

      buildTracker.clear();
      await tester.pressRightArrow();

      // Ensure the caret moved.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 1),
          ),
        ),
      );

      // Ensure that no components were rebuilt because the caret is moved
      // in the document overlay, not within the document layout.
      expect(buildTracker.getBuildCount("1"), 0);
      expect(buildTracker.getBuildCount("2"), 0);
      expect(buildTracker.getBuildCount("3"), 0);
      expect(buildTracker.getBuildCount("4"), 0);
    });

    testWidgetsOnAllPlatforms("when the caret moves to a different paragraph", (tester) async {
      final buildTracker = await _pumpDocument(tester);
      await tester.placeCaretInParagraph("1", 0);
      // Add enough time to prevent the next tap being processed as
      // a drag.
      await tester.pump(const Duration(milliseconds: 200));

      buildTracker.clear();
      await tester.placeCaretInParagraph("2", 0);

      // Ensure the caret moved.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );

      // Ensure that no components were rebuilt because the caret is moved
      // in the document overlay.
      expect(buildTracker.getBuildCount("1"), 0);
      expect(buildTracker.getBuildCount("2"), 0);
      expect(buildTracker.getBuildCount("3"), 0);
      expect(buildTracker.getBuildCount("4"), 0);
    });

    testWidgetsOnAllPlatforms("when the caret moves within a horizontal rule", (tester) async {
      final buildTracker = await _pumpDocument(tester,
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "3",
              nodePosition: UpstreamDownstreamNodePosition.upstream(),
            ),
          ));

      buildTracker.clear();
      await tester.pressRightArrow();

      // Ensure the caret moved.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
      );

      // Ensure that we didn't rebuild any nodes, because caret movement for
      // an HR only requires a change to the document overlay.
      expect(buildTracker.getBuildCount("1"), 0);
      expect(buildTracker.getBuildCount("2"), 0);
      expect(buildTracker.getBuildCount("3"), 0);
      expect(buildTracker.getBuildCount("4"), 0);
    });

    testWidgetsOnAllPlatforms("when the user types into a paragraph", (tester) async {
      final buildTracker = await _pumpDocument(tester);
      await tester.placeCaretInParagraph("1", 0);

      buildTracker.clear();
      await tester.typeKeyboardText("H");

      // Ensure the text was inserted.
      expect(SuperEditorInspector.findTextInParagraph("1").text.startsWith("H"), true);

      // Ensure that we only rebuilt one node, one time for each character.
      expect(buildTracker.getBuildCount("1"), 1);
      expect(buildTracker.getBuildCount("2"), 0);
      expect(buildTracker.getBuildCount("3"), 0);
      expect(buildTracker.getBuildCount("4"), 0);
    });

    testWidgetsOnAllPlatforms("when the user deletes text across two paragraphs", (tester) async {
      await _pumpDocument(tester);

      // TODO:
    });

    testWidgetsOnAllPlatforms("when the user drags a selection across multiple paragraphs", (tester) async {
      await _pumpDocument(tester);

      // TODO:
    });
  });
}

Future<_ComponentBuildTracker> _pumpDocument(
  WidgetTester tester, {
  DocumentSelection? initialSelection,
}) async {
  final buildTracker = _ComponentBuildTracker();

  await tester
      .createDocument() //
      .withCustomContent(_createDocument()) //
      .withComponentBuilders([
        _BuildCountAwareParagraphComponentBuilder(buildTracker),
        ...defaultComponentBuilders,
      ]) //
      .forDesktop()
      .withSelection(initialSelection) //
      .autoFocus(initialSelection != null)
      .pump();

  await tester.pumpAndSettle();

  return buildTracker;
}

MutableDocument _createDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: "1",
        text: AttributedText(text: "This is paragraph one."),
      ),
      ParagraphNode(
        id: "2",
        text: AttributedText(text: "This is paragraph two."),
      ),
      HorizontalRuleNode(id: "3"),
      ParagraphNode(
        id: "4",
        text: AttributedText(text: "This is paragraph three."),
      ),
    ],
  );
}

class _BuildCountAwareParagraphComponentBuilder extends ComponentBuilder {
  _BuildCountAwareParagraphComponentBuilder(this._buildTracker);

  final _paragraphComponentBuilder = const ParagraphComponentBuilder();

  final _ComponentBuildTracker _buildTracker;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    return _paragraphComponentBuilder.createViewModel(document, node);
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    final widget = _paragraphComponentBuilder.createComponent(componentContext, componentViewModel);

    if (widget != null) {
      _buildTracker.logBuild(componentViewModel.nodeId);
    }

    return widget;
  }
}

class _ComponentBuildTracker {
  final _buildCount = <String, int>{};

  void clear() => _buildCount.clear();

  int getBuildCount(String nodeId) => _buildCount[nodeId] ?? 0;

  void logBuild(String nodeId) {
    final currentBuildCount = _buildCount[nodeId] ?? 0;
    _buildCount[nodeId] = currentBuildCount + 1;
  }
}
