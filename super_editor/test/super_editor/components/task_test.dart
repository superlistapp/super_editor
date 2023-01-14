import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/src/test/super_editor_test/tasks_test_tools.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';
import 'package:super_editor/super_editor.dart';

import '../../test_tools.dart';

void main() {
  group("SuperEditor task component", () {
    // TODO: combine with mobile test when #927 is resolved
    testWidgetsOnDesktop("toggles on tap", (tester) async {
      final editor = DocumentEditor(
          document: MutableDocument(
        nodes: [
          TaskNode(id: "1", text: AttributedText(text: "This is a task"), isComplete: false),
        ],
      ));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              componentBuilders: [
                TaskComponentBuilder(editor),
                ...defaultComponentBuilders,
              ],
            ),
          ),
        ),
      );

      // Ensure the task isn't checked.
      expect((editor.document.nodes.first as TaskNode).isComplete, false);
      expect(TaskInspector.isChecked("1"), false);

      // Tap to check the box.
      await tester.tapOnCheckbox("1");

      // Ensure the task is checked.
      expect((editor.document.nodes.first as TaskNode).isComplete, true);
      expect(TaskInspector.isChecked("1"), true);

      // Tap to uncheck the box.
      await tester.tapOnCheckbox("1");

      // Ensure the task isn't checked.
      expect((editor.document.nodes.first as TaskNode).isComplete, false);
      expect(TaskInspector.isChecked("1"), false);
    });

    // TODO: combine with desktop test when #927 is resolved
    testWidgetsOnMobile("toggles on tap", (tester) async {
      final editor = DocumentEditor(
          document: MutableDocument(
        nodes: [
          TaskNode(id: "1", text: AttributedText(text: "This is a task"), isComplete: false),
        ],
      ));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              componentBuilders: [
                TaskComponentBuilder(editor),
                ...defaultComponentBuilders,
              ],
            ),
          ),
        ),
      );

      // Ensure the task isn't checked.
      expect((editor.document.nodes.first as TaskNode).isComplete, false);
      expect(TaskInspector.isChecked("1"), false);

      // Tap to check the box.
      await tester.tapOnCheckbox("1");

      // Ensure the task is checked.
      expect((editor.document.nodes.first as TaskNode).isComplete, true);
      expect(TaskInspector.isChecked("1"), true);

      // Tap to uncheck the box.
      await tester.tapOnCheckbox("1");

      // Ensure the task isn't checked.
      expect((editor.document.nodes.first as TaskNode).isComplete, false);
      expect(TaskInspector.isChecked("1"), false);
    }, skip: true);

    testWidgetsOnAllPlatforms("can be created from empty paragraph", (tester) async {
      final editor = DocumentEditor(
          document: MutableDocument(
        nodes: [
          ParagraphNode(id: "1", text: AttributedText(text: "This will be a task")),
        ],
      ));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              componentBuilders: [
                TaskComponentBuilder(editor),
                ...defaultComponentBuilders,
              ],
            ),
          ),
        ),
      );

      // Convert the paragraph to a task.
      editor.executeCommand(const ConvertParagraphToTaskCommand(nodeId: "1"));

      // Ensure the node is now a task.
      expect(editor.document.nodes.length, 1);
      expect(editor.document.nodes.first, isA<TaskNode>());
      expect((editor.document.nodes.first as TaskNode).text.text, "This will be a task");
    });

    testWidgetsOnAllPlatforms("inserts new task on ENTER at end of existing task", (tester) async {
      final editor = DocumentEditor(
          document: MutableDocument(
        nodes: [
          TaskNode(id: "1", text: AttributedText(text: "This is a task"), isComplete: false),
        ],
      ));
      final task = editor.document.getNodeAt(0) as TaskNode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              componentBuilders: [
                TaskComponentBuilder(editor),
                ...defaultComponentBuilders,
              ],
            ),
          ),
        ),
      );

      // Place the caret at the end of the task.
      await tester.placeCaretInParagraph("1", task.text.text.length);

      // Press enter to create a new, empty task, below the original task.
      await tester.pressEnter();

      // Ensure that a new, empty task was created.
      expect(editor.document.nodes.length, 2);
      expect(editor.document.nodes.first, isA<TaskNode>());
      expect((editor.document.nodes.first as TaskNode).text.text, "This is a task");
      expect(editor.document.nodes.last, isA<TaskNode>());
      expect((editor.document.nodes.last as TaskNode).text.text, "");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: editor.document.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });

    testWidgetsOnAllPlatforms("splits task into two on ENTER in middle of existing task", (tester) async {
      final editor = DocumentEditor(
          document: MutableDocument(
        nodes: [
          TaskNode(id: "1", text: AttributedText(text: "This is a task"), isComplete: false),
        ],
      ));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperEditor(
              editor: editor,
              componentBuilders: [
                TaskComponentBuilder(editor),
              ],
            ),
          ),
        ),
      );

      // Place the caret at "This is |a task"
      await tester.placeCaretInParagraph("1", 8);

      // Press enter to split the existing task into two.
      await tester.pressEnter();

      // Ensure that a new task was created with part of the previous task.
      expect(editor.document.nodes.length, 2);
      expect(editor.document.nodes.first, isA<TaskNode>());
      expect((editor.document.nodes.first as TaskNode).text.text, "This is ");
      expect(editor.document.nodes.last, isA<TaskNode>());
      expect((editor.document.nodes.last as TaskNode).text.text, "a task");
      expect(
        SuperEditorInspector.findDocumentSelection(),
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: editor.document.nodes.last.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
    });
  });
}
