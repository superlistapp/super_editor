import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class HeaderFooterInDocumentUseCase extends StatelessWidget {
  const HeaderFooterInDocumentUseCase({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SuperEditor.custom(
      editor: DocumentEditor(document: _createInitialDocument()),
      componentBuilders: [
        _headerBuilder,
        _footerBuilder,
        ...defaultComponentBuilders,
      ],
    );
  }

  Widget? _headerBuilder(ComponentContext componentContext) {
    final node = componentContext.documentNode;

    if (node is! HeaderNode) {
      return null;
    }

    return node.child;
  }

  Widget? _footerBuilder(ComponentContext componentContext) {
    final node = componentContext.documentNode;

    if (node is! FooterNode) {
      return null;
    }

    return node.child;
  }
}

MutableDocument _createInitialDocument() {
  return MutableDocument(
    nodes: [
      HeaderNode(child: const Header()),
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
      FooterNode(child: const Footer())
    ],
  );
}

class HeaderNode extends HorizontalRuleNode {
  final Widget child;

  HeaderNode({required this.child}) : super(id: 'header');
}

class FooterNode extends HorizontalRuleNode {
  final Widget child;

  FooterNode({required this.child}) : super(id: 'header');
}

class Header extends StatelessWidget {
  const Header({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          Container(
            height: 150,
            color: Colors.red,
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
    );
  }
}

class Footer extends StatefulWidget {
  const Footer({Key? key}) : super(key: key);

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  final TextEditingController _controller = TextEditingController();
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
            'Headers/Footers may contain Text fields and buttons. Here, we have a "messaging experience"'),
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
    );
  }
}
