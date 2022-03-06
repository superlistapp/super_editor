import 'dart:io';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'keyboard_overlay_clipper.dart';

/// Mobile Android document editing demo.
///
/// This demo forces the editor into a mobile configuration,
/// no matter which platform or form factor you use.
class MobileEditingAndroidDemo extends StatefulWidget {
  @override
  _MobileEditingAndroidDemoState createState() => _MobileEditingAndroidDemoState();
}

class _MobileEditingAndroidDemoState extends State<MobileEditingAndroidDemo> {
  final GlobalKey _docLayoutKey = GlobalKey();

  late Document _doc;
  late DocumentEditor _docEditor;
  late DocumentComposer _composer;
  late CommonEditorOperations _docOps;
  late SoftwareKeyboardHandler _softwareKeyboardHandler;

  FocusNode? _editorFocusNode;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
    _composer = DocumentComposer()..addListener(_configureImeActionButton);
    _docOps = CommonEditorOperations(
      editor: _docEditor,
      composer: _composer,
      documentLayoutResolver: () => _docLayoutKey.currentState as DocumentLayout,
    );
    _softwareKeyboardHandler = SoftwareKeyboardHandler(
      editor: _docEditor,
      composer: _composer,
      commonOps: _docOps,
    );
    _editorFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _editorFocusNode!.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _configureImeActionButton() {
    if (_composer.selection == null || !_composer.selection!.isCollapsed) {
      _composer.imeConfiguration.value = _composer.imeConfiguration.value.copyWith(
        keyboardActionButton: TextInputAction.newline,
      );
      return;
    }

    final selectedNode = _doc.getNodeById(_composer.selection!.extent.nodeId);
    if (selectedNode is ListItemNode) {
      _composer.imeConfiguration.value = _composer.imeConfiguration.value.copyWith(
        keyboardActionButton: TextInputAction.done,
      );
      return;
    }

    _composer.imeConfiguration.value = _composer.imeConfiguration.value.copyWith(
      keyboardActionButton: TextInputAction.newline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(
      child: Column(
        children: [
          Expanded(
            child: SuperEditor(
              focusNode: _editorFocusNode,
              documentLayoutKey: _docLayoutKey,
              editor: _docEditor,
              composer: _composer,
              softwareKeyboardHandler: _softwareKeyboardHandler,
              gestureMode: DocumentGestureMode.android,
              inputSource: DocumentInputSource.ime,
              androidToolbarBuilder: (_) => AndroidTextEditingFloatingToolbar(
                onCutPressed: () => _docOps.cut(),
                onCopyPressed: () => _docOps.copy(),
                onPastePressed: () => _docOps.paste(),
                onSelectAllPressed: () => _docOps.selectAll(),
              ),
              stylesheet: defaultStylesheet.copyWith(
                documentPadding: const EdgeInsets.all(16),
              ),
              createOverlayControlsClipper: (_) => const KeyboardToolbarClipper(),
            ),
          ),
          MultiListenableBuilder(
            listenables: <Listenable>{
              _doc,
              _composer.selectionNotifier,
            },
            builder: (_) => _buildMountedToolbar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMountedToolbar() {
    final selection = _composer.selection;

    if (selection == null) {
      return const SizedBox();
    }

    return KeyboardEditingToolbar(
      document: _doc,
      composer: _composer,
      commonOps: CommonEditorOperations(
        editor: _docEditor,
        composer: _composer,
        documentLayoutResolver: () => _docLayoutKey.currentState as DocumentLayout,
      ),
    );
  }

  Widget _buildScaffold({
    required Widget child,
  }) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxHeight / constraints.maxWidth > 1;

          if (Platform.isAndroid || Platform.isIOS || isPortrait) {
            return child;
          } else {
            return _buildPhoneSizedArea(
              child: child,
            );
          }
        },
      ),
    );
  }

  /// Builds an area at the center of the screen that's roughly the size
  /// of a mobile phone screen, with the given [child] constrained to that
  /// area.
  ///
  /// This simulates a layout that's similar to a mobile device.
  Widget _buildPhoneSizedArea({
    required Widget child,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: AspectRatio(
          aspectRatio: 9 / 19.5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
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
          text: 'This is a blockquote!',
        ),
        metadata: {
          'blockType': blockquoteAttribution,
        },
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'This is an unordered list item',
        ),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'This is another list item',
        ),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'This is a 3rd list item',
        ),
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
            text:
                'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
      ),
      ListItemNode.ordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'First thing to do',
        ),
      ),
      ListItemNode.ordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Second thing to do',
        ),
      ),
      ListItemNode.ordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Third thing to do',
        ),
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
