import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// This demo proves that a read-only document can layout and
/// scroll in a `CustomScrollView`.
///
/// The read-only document is represented as a `DefaultDocumentLayout`.
/// It doesn't respond to any user interaction.
///
/// The demo begins with a collapsing tool bar at the top, followed by
/// the read-only document, and then an infinite number of list items.
class ReadOnlyCustomScrollViewDemo extends StatefulWidget {
  @override
  _ReadOnlyCustomScrollViewDemoState createState() => _ReadOnlyCustomScrollViewDemoState();
}

class _ReadOnlyCustomScrollViewDemoState extends State<ReadOnlyCustomScrollViewDemo> {
  late Document _doc;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildCollapsingAppBar(),
        SliverToBoxAdapter(
          child: _buildReadOnlyDocument(),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
            return _buildListItem(index);
          }),
        ),
      ],
    );
  }

  Widget _buildCollapsingAppBar() {
    return SliverAppBar(
      title: const Text(
        'Rich Text Editor Sliver Example',
      ),
      expandedHeight: 200.0,
      leading: const SizedBox(),
      backgroundColor: Colors.blue,
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          'https://i.imgur.com/fSZwM7G.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildReadOnlyDocument() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 96.0, vertical: 48.0),
      child: SingleColumnDocumentLayout(
        presenter: SingleColumnLayoutPresenter(
          document: _doc,
          componentBuilders: defaultComponentBuilders,
          pipeline: [
            SingleColumnStylesheetStyler(stylesheet: defaultStylesheet),
          ],
        ),
        componentBuilders: defaultComponentBuilders,
      ),
    );
  }

  Widget _buildListItem(int index) {
    return ListTile(
      title: Text('$index'),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SliverList element tapped with index $index.',
            ),
            duration: const Duration(milliseconds: 500),
          ),
        );
      },
    );
  }
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: DocumentEditor.createNodeId(),
        imageUrl: 'https://i.imgur.com/fSZwM7G.jpg',
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Example Document',
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
