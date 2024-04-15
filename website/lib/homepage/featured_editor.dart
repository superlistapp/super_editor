import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:website/homepage/editor_toolbar.dart';

/// A Super Editor that displays itself on top of a white sheet of paper
/// with a popup editor toolbar.
///
/// This editor adjusts its padding and text styles based on the given
/// [displayMode].
///
/// Most of the implementation of this widget is about implementing the
/// popup toolbar.
class FeaturedEditor extends StatefulWidget {
  const FeaturedEditor({
    Key? key,
    this.displayMode,
  }) : super(key: key);

  final DisplayMode? displayMode;

  @override
  _FeaturedEditorState createState() => _FeaturedEditorState();
}

class _FeaturedEditorState extends State<FeaturedEditor> {
  final _docLayoutKey = GlobalKey();

  late final MutableDocument _doc;
  late final Editor _docEditor;
  late final MutableDocumentComposer _composer;
  late final FocusNode _editorFocusNode;
  late final ScrollController _scrollController;

  OverlayEntry? _formatBarOverlayEntry;

  final _selectionAnchor = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();

    // Create the initial document content.
    _doc = _createInitialDocument()..addListener(_onDocumentChange);

    // Create the DocumentComposer, which keeps track of the user's text
    // selection and the current input styles, e.g., bold or italics.
    //
    // This DocumentComposer is created because we want explicit control
    // over the initial caret position. If you don't need any external
    // control over content selection then you don't need to create your
    // own DocumentComposer. The Editor widget will do that on your behalf.
    _composer = MutableDocumentComposer(
      initialSelection: DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: _doc.nodes.last.id, // Place caret at end of document
          nodePosition: (_doc.nodes.last as TextNode).endPosition,
        ),
      ),
    )..addListener(_updateToolbarDisplay);

    // Create the DocumentEditor, which is responsible for applying all
    // content changes to the Document.
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);

    // Create a FocusNode so that we can explicitly toggle editor focus.
    _editorFocusNode = FocusNode();

    // Use our own ScrollController for the editor so that we can refresh
    // our popup toolbar position as the user scrolls the editor.
    _scrollController = ScrollController()..addListener(_updateToolbarDisplay);
  }

  @override
  void dispose() {
    _formatBarOverlayEntry?.remove();
    _doc.dispose();
    _scrollController.dispose();
    _editorFocusNode.dispose();
    _composer.dispose();

    super.dispose();
  }

  void _showEditorToolbar() {
    if (_formatBarOverlayEntry == null) {
      _formatBarOverlayEntry ??= OverlayEntry(
        builder: (context) {
          return EditorToolbar(
            doc: _doc,
            anchor: _selectionAnchor,
            editor: _docEditor,
            composer: _composer,
            closeToolbar: _hideEditorToolbar,
          );
        },
      );

      // Display the toolbar in the application overlay.
      final overlay = Overlay.of(context);
      overlay.insert(_formatBarOverlayEntry!);

      // Schedule a callback after this frame to locate the selection
      // bounds on the screen and display the toolbar near the selected
      // text.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _updateToolbarOffset();
      });
    }
  }

  void _updateToolbarOffset() {
    if (_formatBarOverlayEntry == null) {
      return;
    }

    final docBoundingBox = (_docLayoutKey.currentState! as DocumentLayout).getRectForSelection(
      _composer.selection!.base,
      _composer.selection!.extent,
    );
    final parentBox = context.findRenderObject()! as RenderBox;
    final docBox = _docLayoutKey.currentContext!.findRenderObject()! as RenderBox;
    final parentInOverlayOffset = parentBox.localToGlobal(Offset.zero);
    final overlayBoundingBox = Rect.fromPoints(
      docBox.localToGlobal(docBoundingBox!.topLeft, ancestor: parentBox),
      docBox.localToGlobal(docBoundingBox.bottomRight, ancestor: parentBox),
    ).translate(parentInOverlayOffset.dx, parentInOverlayOffset.dy);

    final offset = overlayBoundingBox.topCenter;

    _selectionAnchor.value = offset;
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
      _formatBarOverlayEntry?.remove();
      _formatBarOverlayEntry = null;
    }

    // Ensure that focus returns to the editor.
    //
    // I tried explicitly unfocus()'ing the URL textfield
    // in the toolbar but it didn't return focus to the
    // editor. I'm not sure why.
    _editorFocusNode.requestFocus();
  }

  void _onDocumentChange(_) {
    _updateToolbarDisplay();
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

    if (_formatBarOverlayEntry == null) {
      // Show the editor's toolbar for text styling.
      _showEditorToolbar();
    } else {
      _updateToolbarOffset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditor(
      editor: _docEditor,
      document: _doc,
      composer: _composer,
      documentLayoutKey: _docLayoutKey,
      focusNode: _editorFocusNode,
      stylesheet: _getEditorStyleSheet(),
    );
  }

  Stylesheet _getEditorStyleSheet() {
    switch (widget.displayMode) {
      case DisplayMode.wide:
        return _wideStylesheet;
      case DisplayMode.compact:
        return _compactStylesheet;
      default:
        throw Exception('Invalid displayMode: ${widget.displayMode}');
    }
  }
}

enum DisplayMode {
  wide,
  compact,
}

// The editor does not yet have an underline attribution and style by
// default. Until it does, we create our own attribution here and then
// we style the text ourselves in the "text style builders" that we
// provide to the Editor widget.
const _underlineAttribution = NamedAttribution('underline');

MutableDocument _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'A supercharged rich text editor for Flutter',
        ),
        metadata: {
          'blockType': header1Attribution,
          'textAlign': 'center',
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'The missing WYSIWYG editor for Flutter.',
          AttributedSpans(
            attributions: [
              const SpanMarker(
                attribution: boldAttribution,
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: boldAttribution,
                offset: 25,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Open source and written entirely in Dart. Comes with a modular architecture that allows you to customize it to your needs.',
          AttributedSpans(
            attributions: [
              const SpanMarker(
                attribution: _underlineAttribution,
                offset: 16,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: _underlineAttribution,
                offset: 40,
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
          'Try it right here >>',
        ),
      ),
    ],
  );
}

const _baseTextStyle = TextStyle(
  fontFamily: 'Aeonik',
  fontWeight: FontWeight.w400,
  fontSize: 18,
  height: 27 / 18,
  color: Color(0xFF003F51),
);

/// Produces all [TextStyle]s for the editor in compact mode.
final _compactStylesheet = defaultStylesheet.copyWith(
  documentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, docNode) => {'textStyle': _baseTextStyle}),
    StyleRule(
      BlockSelector.all.after(header1Attribution.name),
      (doc, docNode) => {Styles.padding: const CascadingPadding.only(top: 24)},
    ),
    StyleRule(
      BlockSelector(header1Attribution.name),
      (doc, docNode) {
        return {
          Styles.textStyle: _baseTextStyle.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        };
      },
    ),
    StyleRule(BlockSelector(header2Attribution.name), (doc, docNode) {
      return {
        Styles.textStyle: _baseTextStyle.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      };
    }),
    StyleRule(BlockSelector(header3Attribution.name), (doc, docNode) {
      return {
        Styles.textStyle: _baseTextStyle.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      };
    }),
    StyleRule(BlockSelector(blockquoteAttribution.name), (doc, docNode) {
      return {
        Styles.textStyle: _baseTextStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      };
    }),
  ],
);

/// Produces all [TextStyle]s for the editor in wide mode.
final _wideStylesheet = defaultStylesheet.copyWith(
  documentPadding: const EdgeInsets.symmetric(horizontal: 54, vertical: 60),
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, docNode) => {Styles.textStyle: _baseTextStyle}),
    StyleRule(
      BlockSelector.all.after(header1Attribution.name),
      (doc, docNode) => {Styles.padding: const CascadingPadding.only(top: 48)},
    ),
    StyleRule(
      BlockSelector(header1Attribution.name),
      (doc, docNode) {
        return {
          Styles.textStyle: _baseTextStyle.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector(header2Attribution.name),
      (doc, docNode) {
        return {
          Styles.textStyle: _baseTextStyle.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector(header3Attribution.name),
      (doc, docNode) {
        return {
          Styles.textStyle: _baseTextStyle.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector(blockquoteAttribution.name),
      (doc, docNode) {
        return {
          Styles.textStyle: _baseTextStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        };
      },
    ),
  ],
);
