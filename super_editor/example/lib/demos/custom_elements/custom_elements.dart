import 'dart:async';

import 'package:example/demos/custom_elements/task.dart';
import 'package:example/demos/custom_elements/task_item.dart';
import 'package:example/demos/custom_elements/task_syntax.dart';
import 'package:example/demos/custom_elements/tasks_repository.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

const _initialDocument = '''
# H1 sample content

Hanami (花見, "flower viewing") is the Japanese traditional custom of enjoying the transient beauty of flowers; flowers 
("hana") are in this case almost always referring to those of the cherry ("sakura") or, less frequently, plum ("ume") 
trees. From the end of March to early May, cherry trees bloom all over Japan. The blossom forecast cherry blossom front 
is announced each year by the weather bureau - check https://www.jnto.go.jp/sakura/eng/index.php for details - and 
should watched carefully by those planning hanami as the blossoms only last a week or two.

* Decide to visit Okinawa or Honshu
* Select an airline and a place to stay
* Book everything
* Don't forget to bring your camera

<@ task:aaa111 @>
<@ task:bbb222 @>
<@ task:ccc333 @>
<@ task:toggling-all-the-time @>

---
''';

const _tasks = [
  Task(id: 'aaa111', checked: true, text: 'First task.'),
  Task(id: 'bbb222', checked: false, text: 'Second task.'),
  Task(id: 'ccc333', checked: true, text: 'Third task.'),
  Task(
    id: 'toggling-all-the-time',
    checked: false,
    text: "I'm the task that is constantly toggling its checked state all the time.",
  ),
];

class CustomElementsExampleEditor extends StatefulWidget {
  @override
  _CustomElementsExampleEditorState createState() => _CustomElementsExampleEditorState();
}

class _CustomElementsExampleEditorState extends State<CustomElementsExampleEditor> {
  late Document _doc;
  late DocumentEditor _docEditor;
  late DocumentComposer _composer;
  late FocusNode _editorFocusNode;
  late Timer _taskToggleTimer;
  late Timer _markdownTimer;

  String _markdown = '';

  @override
  void initState() {
    super.initState();
    const repository = TasksRepository();
    repository.insertAll(_tasks);
    _doc = deserializeMarkdownToDocument(
      _initialDocument,
      customNodeVisitor: const TaskNodeVisitor(repository),
      customBlockSyntaxes: [const TaskSyntax()],
    );

    _docEditor = DocumentEditor(document: _doc as MutableDocument);
    _composer = DocumentComposer();
    _editorFocusNode = FocusNode();
    _taskToggleTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        final task = await repository.getTaskById('toggling-all-the-time');
        if (task != null) {
          repository.updateTask(task.copyWith(checked: !task.checked));
        }
      },
    );

    _markdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        setState(() {
          _markdown = serializeDocumentToMarkdown(
            _doc,
            customSerializer: (node) {
              if (node is TaskItemNode) {
                return '<@ task:${node.id} @>';
              }

              return null;
            },
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    _composer.dispose();
    _taskToggleTimer.cancel();
    _markdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SuperEditor.custom(
            editor: _docEditor,
            composer: _composer,
            focusNode: _editorFocusNode,
            maxWidth: 600, // arbitrary choice for maximum width
            padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
            componentBuilders: [
              taskItemBuilder,
              ...defaultComponentBuilders,
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: double.infinity,
            color: const Color(0xFF222222),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Text(
                  _markdown,
                  style: const TextStyle(
                    color: Color(0xFFEEEEEE),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
