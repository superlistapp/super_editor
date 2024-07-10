import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Example editor to show how the Rich Text Editor is working.
///
/// As the editor has an internal scrolling mechanism, for using it with Slivers
/// you need to give them a finite height or space to fill itself. That is why
/// the [SuperEditor] has a [SizedBox] wrapped around it to give a height.
class SliverExampleEditor extends StatefulWidget {
  @override
  State<SliverExampleEditor> createState() => _SliverExampleEditorState();
}

class _SliverExampleEditorState extends State<SliverExampleEditor> {
  // Toggle this, as a developer, to turn auto-scrolling debug
  // paint on/off.
  static const _showDebugPaint = false;

  final _scrollableKey = GlobalKey(debugLabel: "sliver_scrollable");
  late ScrollController _scrollController;
  final _minimapKey = GlobalKey(debugLabel: "sliver_minimap");

  late MutableDocument _doc;
  late MutableDocumentComposer _composer;
  late Editor _docEditor;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    _doc = _createInitialDocument();
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollingMinimaps(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              key: _scrollableKey,
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  title: const Text(
                    'Rich Text Editor Sliver Example',
                  ),
                  expandedHeight: 200.0,
                  leading: const SizedBox(),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Image.network(
                      'https://i.imgur.com/fSZwM7G.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
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
                  child: SuperEditor(
                    editor: _docEditor,
                    stylesheet: defaultStylesheet.copyWith(
                      documentPadding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                    ),
                    debugPaint: const DebugPaintConfig(
                      gestures: _showDebugPaint,
                      scrollingMinimapId: _showDebugPaint ? "sliver_demo" : null,
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
                              duration: const Duration(milliseconds: 500),
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
            ),
          ),
          if (_showDebugPaint) _buildScrollingMinimap(),
        ],
      ),
    );
  }

  Widget _buildScrollingMinimap() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: 200,
      child: ColoredBox(
        color: Colors.black.withOpacity(0.2),
        child: Center(
          child: ScrollingMinimap.fromRepository(
            key: _minimapKey,
            minimapId: "sliver_demo",
            minimapScale: 0.1,
          ),
        ),
      ),
    );
  }
}

MutableDocument _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: Editor.createNodeId(),
        imageUrl: 'https://i.imgur.com/fSZwM7G.jpg',
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Example Document'),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      HorizontalRuleNode(id: Editor.createNodeId()),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Etiam id lacus interdum, efficitur ex convallis, accumsan ipsum. Integer faucibus mollis mauris, a suscipit ante mollis vitae. Fusce justo metus, congue non lectus ac, luctus rhoncus tellus. Phasellus vitae fermentum orci, sit amet sodales orci. Fusce at ante iaculis nunc aliquet pharetra. Nam placerat, nisl in gravida lacinia, nisl nibh feugiat nunc, in sagittis nisl sapien nec arcu. Nunc gravida faucibus massa, sit amet accumsan dolor feugiat in. Mauris ut elementum leo.',
        ),
      ),
    ],
  );
}
