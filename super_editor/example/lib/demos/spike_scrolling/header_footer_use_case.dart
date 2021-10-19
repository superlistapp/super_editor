import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'sliver_stick_to_bottom.dart';

class HeaderFooterUseCase extends StatefulWidget {
  @override
  _HeaderFooterUseCaseState createState() => _HeaderFooterUseCaseState();
}

class _HeaderFooterUseCaseState extends State<HeaderFooterUseCase> {
  final TextEditingController _controller = TextEditingController();
  late Document _doc;
  late DocumentEditor _docEditor;
  final List<String> _messages = [
    'Dummy',
    'List',
    'Of',
    'Fake',
    'Messages',
    'Between',
    'Users',
  ];

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: Stack(
              children: [
                Container(
                  height: 150,
                  color: Colors.blue,
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 600,
                      height: 170,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return const AlertDialog(
                                  title: Text('Header Button pressed'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: IntrinsicHeight(
            child: SuperEditor.standard(
              editor: _docEditor,
              padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
            ),
          ),
        ),
        SliverStickToBottom(
          child: Column(
            children: [
              const Text(
                  'Headers/Footers may contain Text fields and buttons. Here, we have a "messaging experience" that sticks to the bottom of the screen if the document isn\'t large enough, or scrolls with the document if the document is large enough'),
              for (final message in _messages)
                ListTile(
                  title: Text(message),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter message...',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (_controller.text.isNotEmpty) {
                      _messages.add(_controller.text);
                    }
                  });
                },
                child: const Text("Send message"),
              ),
            ],
          ),
        )
      ],
    );
  }
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Complex Headers & Footers',
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
              'Document should take up as much space as it needs. (No scroll within a scroll, which can happen depending on the size of this window). Document should be surrounded by interactive / "complex" headers and footers. Users need to be able to interact with Buttons and Text fields as they normally would.',
        ),
      ),
    ],
  );
}
