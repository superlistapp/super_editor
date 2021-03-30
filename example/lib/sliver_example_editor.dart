import 'package:flutter/material.dart';
import 'package:flutter_richtext/flutter_richtext.dart';

/// Example editor to show how the Rich Text Editor is working.
///
/// As the editor has an internal scrolling mechanism, for using it with Slivers
/// you need to give them a finite height or space to fill itself. That is why
/// the [Editor] has a [SizedBox] wrapped around it to give a height.
class SliverExampleEditor extends StatefulWidget {
  @override
  _SliverExampleEditorState createState() => _SliverExampleEditorState();
}

class _SliverExampleEditorState extends State<SliverExampleEditor> {
  Document _doc;
  DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(
            'Rich Text Editor Sliver Example',
          ),
          expandedHeight: 200.0,
          leading: SizedBox(),
          flexibleSpace: FlexibleSpaceBar(
            background: Image.network(
              'https://i.ytimg.com/vi/fq4N0hgOWzU/maxresdefault.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Text(
            'Lorem Ipsum Dolor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 72,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SliverToBoxAdapter(
          child: IntrinsicHeight(
            child: Editor.standard(
              editor: _docEditor,
              padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return ListTile(
                title: Text('$index'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'SliverList element tapped with index $index.',
                      ),
                      duration: Duration(milliseconds: 500),
                    ),
                  );
                },
              );
            },
            // Or, uncomment the following line:
            // childCount: 3,
          ),
        ),
      ],
    );
  }
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: DocumentEditor.createNodeId(),
        imageUrl: 'https://i.ytimg.com/vi/fq4N0hgOWzU/maxresdefault.jpg',
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Example Document',
        ),
        metadata: {
          'blockType': 'header1',
        },
      ),
      HorizontalRuleNode(id: DocumentEditor.createNodeId()),
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
    ],
  );
}
