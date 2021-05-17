import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:website/editor_toolbar.dart';

class EditorShowcase extends StatefulWidget {
  const EditorShowcase();

  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<EditorShowcase> {
  final _docLayoutKey = GlobalKey();

  MutableDocument _doc;
  DocumentEditor _docEditor;
  DocumentComposer _composer;

  FocusNode _editorFocusNode;

  ScrollController _scrollController;

  OverlayEntry _formatBarOverlayEntry;
  final _selectionAnchor = ValueNotifier<Offset>(null);

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument()..addListener(_updateToolbarDisplay);
    _docEditor = DocumentEditor(document: _doc);
    _composer = DocumentComposer()..addListener(_updateToolbarDisplay);
    _editorFocusNode = FocusNode();
    _scrollController = ScrollController()..addListener(_updateToolbarDisplay);
  }

  @override
  void dispose() {
    if (_formatBarOverlayEntry != null) {
      _formatBarOverlayEntry.remove();
    }

    _doc.dispose();
    _scrollController.dispose();
    _editorFocusNode.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _updateToolbarDisplay() {
    final selection = _composer.selection;
    if (selection == null) {
      // Nothing is selected. We don't want to show a toolbar
      // in this case.
      _hideEditorToolbar();

      return;
    }
    if (selection.base.nodeId != selection.extent.nodeId) {
      // More than one node is selected. We don't want to show
      // a toolbar in this case.
      _hideEditorToolbar();

      return;
    }
    if (selection.isCollapsed) {
      // We only want to show the toolbar when a span of text
      // is selected. Therefore, we ignore collapsed selections.
      _hideEditorToolbar();

      return;
    }

    final textNode = _doc.getNodeById(selection.extent.nodeId);
    if (textNode is! TextNode) {
      // The currently selected content is not a paragraph. We don't
      // want to show a toolbar in this case.
      _hideEditorToolbar();

      return;
    }

    // Show the editor's toolbar for text styling.
    _showEditorToolbar();
  }

  void _showEditorToolbar() {
    if (_formatBarOverlayEntry == null) {
      // Create an overlay entry to build the editor toolbar.
      // TODO: add an overlay to the Editor widget to avoid using the
      //       application overlay
      _formatBarOverlayEntry ??= OverlayEntry(
        builder: (context) {
          return EditorToolbar(
            anchor: _selectionAnchor,
            editor: _docEditor,
            composer: _composer,
            closeToolbar: _hideEditorToolbar,
          );
        },
      );

      // Display the toolbar in the application overlay.
      final overlay = Overlay.of(context);
      overlay.insert(_formatBarOverlayEntry);

      // Schedule a callback after this frame to locate the selection
      // bounds on the screen and display the toolbar near the selected
      // text.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        final windowWidth = MediaQuery.of(context).size.width;
        final docBoundingBox =
            (_docLayoutKey.currentState as DocumentLayout).getRectForSelection(
          _composer.selection.base,
          _composer.selection.extent,
        );
        final parentBox = context.findRenderObject() as RenderBox;
        final docBox =
            _docLayoutKey.currentContext.findRenderObject() as RenderBox;
        final overlayBoundingBox = Rect.fromPoints(
          docBox.localToGlobal(docBoundingBox.topLeft, ancestor: parentBox),
          docBox.localToGlobal(docBoundingBox.bottomRight, ancestor: parentBox),
        ).translate(0, windowWidth < 540 ? 90 : 120);

        // A hacky piece of code that tries to ensure the editor toolbar doesn't
        // go out of window bounds. Assumes that the editor toolbar is fixed height.
        var offset = overlayBoundingBox.topCenter;
        if (offset.dx < 172) {
          offset = offset.translate(172, 0);
        } else if (offset.dx > windowWidth - 132) {
          offset = offset.translate(-132, 0);
        }

        _selectionAnchor.value = offset;
      });
    }
  }

  void _hideEditorToolbar() {
    // Null out the selection anchor so that when it re-appears,
    // the bar doesn't momentarily "flash" at its old anchor position.
    _selectionAnchor.value = null;

    if (_formatBarOverlayEntry != null) {
      // Remove the toolbar overlay and null-out the entry.
      // We null out the entry because we can't query whether
      // or not the entry exists in the overlay, so in our
      // case, null implies the entry is not in the overlay,
      // and non-null implies the entry is in the overlay.
      _formatBarOverlayEntry.remove();
      _formatBarOverlayEntry = null;
    }

    // Ensure that focus returns to the editor.
    //
    // I tried explicitly unfocus()'ing the URL textfield
    // in the toolbar but it didn't return focus to the
    // editor. I'm not sure why.
    _editorFocusNode.requestFocus();
  }

  static MutableDocument _createInitialDocument() {
    return MutableDocument(
      nodes: [
        ParagraphNode(
          id: DocumentEditor.createNodeId(),
          text: AttributedText(
            text: 'A supercharged rich text editor for Flutter',
          ),
          metadata: {
            'blockType': header1Attribution,
            'textAlign': 'center',
          },
        ),
      ],
    );
  }

  static TextStyle Function(Set<Attribution> attributions) _textStyleBuilder(
    bool isNarrowScreen,
  ) {
    return (Set<Attribution> attributions) {
      var result = const TextStyle(
        fontFamily: 'Aeonik',
        fontWeight: FontWeight.w400,
        fontSize: 18,
        height: 27 / 18,
        color: Color(0xFF003F51),
      );

      for (final attribution in attributions) {
        if (attribution == header1Attribution) {
          result = result.copyWith(
            fontSize: isNarrowScreen ? 40 : 68,
            fontWeight: FontWeight.w700,
            height: 1.2,
          );
        } else if (attribution == header2Attribution) {
          result = result.copyWith(
            fontSize: isNarrowScreen ? 32 : 56,
            fontWeight: FontWeight.w700,
            height: 1.2,
          );
        } else if (attribution == header3Attribution) {
          result = result.copyWith(
            fontSize: isNarrowScreen ? 26 : 36,
            fontWeight: FontWeight.w700,
            height: 1.2,
          );
        } else if (attribution == blockquoteAttribution) {
          result = result.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          );
        } else if (attribution == boldAttribution) {
          result = result.copyWith(fontWeight: FontWeight.bold);
        } else if (attribution == italicsAttribution) {
          result = result.copyWith(fontStyle: FontStyle.italic);
        } else if (attribution == strikethroughAttribution) {
          result = result.copyWith(decoration: TextDecoration.lineThrough);
        }
      }
      return result;
    };
  }

  static Widget _centeredHeaderBuilder(ComponentContext context) {
    final node = context.documentNode;

    if (node is ParagraphNode && node.metadata['blockType'] == 'header1') {
      return Center(child: paragraphBuilder(context));
    }

    return null;
  }

  static Widget _blockquoteBuilder(ComponentContext context) {
    final node = context.documentNode;

    if (node is ParagraphNode &&
        node.metadata['blockType'] == blockquoteAttribution) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.black26,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 8),
        child: paragraphBuilder(context),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrowScreen = constraints.biggest.width <= 768;

          return Container(
            constraints: const BoxConstraints(maxWidth: 1112)
                .tighten(height: isNarrowScreen ? 400 : 632),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(0.79),
                  blurRadius: 75,
                ),
              ],
            ),
            child: Editor.custom(
              editor: _docEditor,
              composer: _composer,
              documentLayoutKey: _docLayoutKey,
              focusNode: _editorFocusNode,
              maxWidth: 1112,
              padding: isNarrowScreen
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.symmetric(horizontal: 96, vertical: 60),
              textStyleBuilder: _textStyleBuilder(isNarrowScreen),
              componentBuilders: [
                _centeredHeaderBuilder,
                _blockquoteBuilder,
                ...defaultComponentBuilders,
              ],
            ),
          );
        },
      ),
    );
  }
}
