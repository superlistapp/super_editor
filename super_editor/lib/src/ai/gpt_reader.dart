import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// A reader, which is meant to be fed content from a generative predictive text (GPT)
/// AI system.
///
/// This reader doesn't include any AI behaviors - it's a tool to be used in conjunction
/// with an AI system.
class GptReader extends StatefulWidget {
  const GptReader({
    super.key,
    required this.gptFeed,
    required this.stylesheet,
    this.reactions = const [],
  });

  final GptReaderFeed gptFeed;
  final Stylesheet stylesheet;

  final List<EditReaction> reactions;

  @override
  State<GptReader> createState() => _GptReaderState();
}

class _GptReaderState extends State<GptReader> with TickerProviderStateMixin {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  late final FocusNode _editorFocusNode;

  late final FadeInTextStyler _fadeInStylePhase;

  @override
  void initState() {
    super.initState();

    _document = MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText()),
      ],
    );
    _composer = MutableDocumentComposer(
      initialSelection: const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 0)),
      ),
    );
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: [
        ...defaultRequestHandlers,
      ],
      reactionPipeline: [
        ...widget.reactions,
        ...List.from(defaultEditorReactions)..remove(const DashConversionReaction()),
      ],
    );

    _editorFocusNode = FocusNode();

    _fadeInStylePhase = FadeInTextStyler(this);

    widget.gptFeed.attachEditor(_editor);
  }

  @override
  void didUpdateWidget(GptReader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.gptFeed != oldWidget.gptFeed) {
      oldWidget.gptFeed.detachEditor();
      widget.gptFeed.attachEditor(_editor);
    }
  }

  @override
  void dispose() {
    widget.gptFeed.detachEditor();

    _fadeInStylePhase.dispose();

    _editorFocusNode.dispose();

    _composer.dispose();
    _editor.dispose();
    _document.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperReader(
      document: _editor.document,
      focusNode: _editorFocusNode,
      componentBuilders: [
        TaskComponentBuilder(_editor),
        ...defaultComponentBuilders,
      ],
      customStylePhases: [
        _fadeInStylePhase,
      ],
      documentOverlayBuilders: [
        // SuperEditorIosToolbarFocalPointDocumentLayerBuilder(),
        // SuperEditorIosHandlesDocumentLayerBuilder(),
        // SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder(),
        // SuperEditorAndroidHandlesDocumentLayerBuilder(),
        // DefaultCaretOverlayBuilder(
        //   caretStyle: CaretStyle(
        //     color: Colors.red,
        //     width: 4,
        //     borderRadius: BorderRadius.circular(2),
        //   ),
        // ),
      ],
      stylesheet: widget.stylesheet,
    );
  }
}

abstract class GptReaderFeed {
  @protected
  Editor? editor;

  void attachEditor(Editor editor) => this.editor = editor;

  void detachEditor() => editor = null;

  void ensureEditorIsAttached() {
    if (editor == null) {
      print("Editor is null. Throwing exception.");
      throw Exception("Tried to submit GPT content but no Editor was attached.");
    }
  }
}

class DirectGptReaderFeed extends GptReaderFeed {
  void insertPlainText(String text) {
    ensureEditorIsAttached();
    editor!.execute([
      InsertPlainTextAtCaretRequest(
        text,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  void insertStyledText(AttributedText text) {
    ensureEditorIsAttached();
    editor!.execute([
      InsertStyledTextAtCaretRequest(
        text,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  void insertBlockNode(BlockNode node) {
    ensureEditorIsAttached();
    editor!.execute([
      InsertNodeAfterNodeRequest(
        existingNodeId: editor!.document.last.id,
        newNode: node.copyWithAddedMetadata({
          'createdAt': DateTime.now(),
        }),
      ),
    ]);
  }
}
