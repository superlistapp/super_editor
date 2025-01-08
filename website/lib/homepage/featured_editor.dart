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
  final _viewportKey = GlobalKey();
  final _docLayoutKey = GlobalKey();

  late final MutableDocument _doc;
  late final Editor _docEditor;
  late final MutableDocumentComposer _composer;
  late final FocusNode _editorFocusNode;

  final _textFormatBarOverlayController = OverlayPortalController();

  final SelectionLayerLinks _selectionLayerLinks = SelectionLayerLinks();

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
          nodeId: _doc.last.id, // Place caret at end of document
          nodePosition: (_doc.last as TextNode).endPosition,
        ),
      ),
    );

    _composer.selectionNotifier.addListener(_updateToolbarDisplay);

    // Create the DocumentEditor, which is responsible for applying all
    // content changes to the Document.
    _docEditor = createDefaultDocumentEditor(document: _doc, composer: _composer);

    // Create a FocusNode so that we can explicitly toggle editor focus.
    _editorFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _doc.dispose();
    _editorFocusNode.dispose();
    _composer.dispose();

    super.dispose();
  }

  void _showEditorToolbar() {
    _textFormatBarOverlayController.show();
  }

  void _hideEditorToolbar() {
    // Null out the selection anchor so that when it re-appears,
    // the bar doesn't momentarily "flash" at its old anchor position.

    _textFormatBarOverlayController.hide();
    // Ensure that focus returns to the editor.
    //
    // I tried explicitly unfocus()'ing the URL textfield
    // in the toolbar but it didn't return focus to the
    // editor. I'm not sure why.
    //
    // Only do that if the primary focus is not at the root focus scope because
    // this might signify that the app is going to the background. Removing
    // the focus from the root focus scope in that situation prevents the editor
    // from re-gaining focus when the app is brought back to the foreground.
    //
    // See https://github.com/superlistapp/super_editor/issues/2279 for details.
    if (FocusManager.instance.primaryFocus != FocusManager.instance.rootScope) {
      _editorFocusNode.requestFocus();
    }
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

    final selectedNode = _doc.getNodeById(selection.extent.nodeId);

    if (selectedNode is TextNode) {
      // Show the editor's toolbar for text styling.
      _showEditorToolbar();
      return;
    } else {
      // The currently selected content is not a paragraph. We don't
      // want to show a toolbar in this case.
      _hideEditorToolbar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _textFormatBarOverlayController,
      overlayChildBuilder: _buildFloatingToolbar,
      child: KeyedSubtree(
        key: _viewportKey,
        child: CustomScrollView(
          slivers: [
            SuperEditor(
              editor: _docEditor,
              documentLayoutKey: _docLayoutKey,
              focusNode: _editorFocusNode,
              stylesheet: _getEditorStyleSheet(),
              selectionLayerLinks: _selectionLayerLinks,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingToolbar(BuildContext context) {
    return EditorToolbar(
      editorViewportKey: _viewportKey,
      editorFocusNode: _editorFocusNode,
      document: _doc,
      anchor: _selectionLayerLinks.expandedSelectionBoundsLink,
      editor: _docEditor,
      composer: _composer,
      closeToolbar: _hideEditorToolbar,
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
