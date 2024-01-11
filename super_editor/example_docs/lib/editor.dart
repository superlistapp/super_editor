import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import 'theme.dart';

/// An editable document within a Docs app.
///
/// This is the primary editing experience for the app. A [DocsEditor] takes up
/// all the space beneath the app header pane.
class DocsEditor extends StatefulWidget {
  const DocsEditor({super.key});

  @override
  State<DocsEditor> createState() => _DocsEditorState();
}

class _DocsEditorState extends State<DocsEditor> {
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;

  final _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _document = _createInitialDocument();
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _document, composer: _composer);
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();

    _editor.dispose();
    _composer.dispose();
    _document.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _editorFocusNode,
      builder: (context, child) {
        return SuperEditor(
          focusNode: _editorFocusNode,
          editor: _editor,
          document: _document,
          composer: _composer,
          stylesheet: defaultStylesheet.copyWith(
            addRulesAfter: docsStylesheet,
          ),
          selectionStyle: _editorFocusNode.hasPrimaryFocus //
              ? _standardEditorSelectionStyle
              : _unfocusedEditorSelectionStyle,
          selectionPolicies: const SuperEditorSelectionPolicies(
            clearSelectionWhenEditorLosesFocus: false,
            clearSelectionWhenImeConnectionCloses: false,
          ),
          documentOverlayBuilders: const [
            DefaultCaretOverlayBuilder(
              displayCaretWithExpandedSelection: false,
            ),
          ],
        );
      },
    );
  }
}

// Selection styles when the editor has focus.
const _standardEditorSelectionStyle = defaultSelectionStyle;

// Selection styles when the editor doesn't have focus.
final _unfocusedEditorSelectionStyle = SelectionStyles(
  selectionColor: const Color(0xFFDDDDDD),
  highlightEmptyTextBlocks: defaultSelectionStyle.highlightEmptyTextBlocks,
);

// Creates the document that's initially displayed when the app launches.
MutableDocument _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("Welcome to a Super Editor version of Docs!"),
        metadata: {
          "blockType": header1Attribution,
        },
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText("By: The Super Editor Team"),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
            "This is an example document editor experience, which is meant to mimic the UX of Google Docs. We created this example app to ensure that common desktop word processing UX can be built with Super Editor."),
      ),
      ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(
            "A typical desktop word processor is comprised of a pane at the top of the window, which includes some combination of information about the current document, as well as toolbars that present editing options. The remainder of the window is filled by an editable document."),
      ),
    ],
  );
}
