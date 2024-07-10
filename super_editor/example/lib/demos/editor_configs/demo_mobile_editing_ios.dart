import 'dart:io';

import 'package:example/demos/editor_configs/keyboard_overlay_clipper.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

/// Mobile iOS document editing demo.
///
/// This demo forces the editor into a mobile configuration,
/// no matter which platform or form factor you use.
class MobileEditingIOSDemo extends StatefulWidget {
  @override
  State<MobileEditingIOSDemo> createState() => _MobileEditingIOSDemoState();
}

class _MobileEditingIOSDemoState extends State<MobileEditingIOSDemo> with SingleTickerProviderStateMixin {
  final GlobalKey _docLayoutKey = GlobalKey();

  late MutableDocument _doc;
  final _docChangeSignal = SignalNotifier();
  late MutableDocumentComposer _composer;
  late Editor _docEditor;
  late CommonEditorOperations _docOps;

  FocusNode? _editorFocusNode;

  final _selectionLayerLinks = SelectionLayerLinks();

  // TODO: get rid of overlay controller once Android is refactored to use a control scope (as follow up to: https://github.com/superlistapp/super_editor/pull/1470)
  late MagnifierAndToolbarController _overlayController;
  late final SuperEditorIosControlsController _iosEditorControlsController;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument()..addListener(_onDocumentChange);
    _composer = MutableDocumentComposer();
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    _docOps = CommonEditorOperations(
      editor: _docEditor,
      document: _doc,
      composer: _composer,
      documentLayoutResolver: () => _docLayoutKey.currentState as DocumentLayout,
    );
    _editorFocusNode = FocusNode();

    // TODO: get rid of the overlay controller
    _overlayController = MagnifierAndToolbarController();
    _iosEditorControlsController = SuperEditorIosControlsController(
      toolbarBuilder: _buildIosToolbar,
      magnifierBuilder: _buildIosMagnifier,
    );
  }

  @override
  void dispose() {
    _iosEditorControlsController.dispose();

    _editorFocusNode!.dispose();
    _composer.dispose();
    _doc.removeListener(_onDocumentChange);
    super.dispose();
  }

  void _onDocumentChange(_) => _docChangeSignal.notifyListeners();

  void _cut() {
    _docOps.cut();
    // TODO: get rid of overlay controller once Android is refactored to use a control scope (as follow up to: https://github.com/superlistapp/super_editor/pull/1470)
    _overlayController.hideToolbar();
    _iosEditorControlsController.hideToolbar();
  }

  void _copy() {
    _docOps.copy();
    // TODO: get rid of overlay controller once Android is refactored to use a control scope (as follow up to: https://github.com/superlistapp/super_editor/pull/1470)
    _overlayController.hideToolbar();
    _iosEditorControlsController.hideToolbar();
  }

  void _paste() {
    _docOps.paste();
    // TODO: get rid of overlay controller once Android is refactored to use a control scope (as follow up to: https://github.com/superlistapp/super_editor/pull/1470)
    _overlayController.hideToolbar();
    _iosEditorControlsController.hideToolbar();
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(
      child: Column(
        children: [
          Expanded(
            child: SuperEditorIosControlsScope(
              controller: _iosEditorControlsController,
              child: SuperEditor(
                focusNode: _editorFocusNode,
                documentLayoutKey: _docLayoutKey,
                editor: _docEditor,
                gestureMode: DocumentGestureMode.iOS,
                inputSource: TextInputSource.ime,
                selectionLayerLinks: _selectionLayerLinks,
                stylesheet: defaultStylesheet.copyWith(
                  documentPadding: const EdgeInsets.all(16),
                ),
                overlayController: _overlayController,
                createOverlayControlsClipper: (_) => const KeyboardToolbarClipper(),
              ),
            ),
          ),
          MultiListenableBuilder(
            listenables: <Listenable>{
              _docChangeSignal,
              _composer.selectionNotifier,
            },
            builder: (_) => _buildMountedToolbar(),
          ),
        ],
      ),
    );
  }

  Widget _buildIosToolbar(BuildContext context, Key mobileToolbarKey, LeaderLink focalPoint) {
    return IOSTextEditingFloatingToolbar(
      key: mobileToolbarKey,
      focalPoint: focalPoint,
      onCutPressed: _cut,
      onCopyPressed: _copy,
      onPastePressed: _paste,
    );
  }

  Widget _buildIosMagnifier(BuildContext context, Key magnifierKey, LeaderLink focalPoint, bool isVisible) {
    return Center(
      child: IOSFollowingMagnifier.roundedRectangle(
        magnifierKey: magnifierKey,
        leaderLink: focalPoint,
        // The bottom of the magnifier sits above the focal point.
        // Leave a few pixels between the bottom of the magnifier and the focal point. This
        // value was chosen empirically.
        offsetFromFocalPoint: const Offset(0, -20),
        show: isVisible,
      ),
    );
  }

  Widget _buildMountedToolbar() {
    final selection = _composer.selection;

    if (selection == null) {
      return const SizedBox();
    }

    return KeyboardEditingToolbar(
      editor: _docEditor,
      document: _doc,
      composer: _composer,
      commonOps: _docOps,
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
        padding: const EdgeInsets.only(left: 56, right: 56, bottom: 24),
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
        text: AttributedText('This is a blockquote!'),
        metadata: {
          'blockType': blockquoteAttribution,
        },
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText('This is an unordered list item'),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText('This is another list item'),
      ),
      ListItemNode.unordered(
        id: Editor.createNodeId(),
        text: AttributedText('This is a 3rd list item'),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.',
        ),
      ),
      ListItemNode.ordered(
        id: Editor.createNodeId(),
        text: AttributedText('First thing to do'),
      ),
      ListItemNode.ordered(
        id: Editor.createNodeId(),
        text: AttributedText('Second thing to do'),
      ),
      ListItemNode.ordered(
        id: Editor.createNodeId(),
        text: AttributedText('Third thing to do'),
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
