import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'example_editor/_toolbar.dart';

/// Example of a rich text editor.
///
/// This editor will expand in functionality as package
/// capabilities expand.
class CustomElementsExampleEditor extends StatefulWidget {
  @override
  _CustomElementsExampleEditorState createState() =>
      _CustomElementsExampleEditorState();
}

class _CustomElementsExampleEditorState
    extends State<CustomElementsExampleEditor> {
  final GlobalKey _docLayoutKey = GlobalKey();

  late Document _doc;
  DocumentEditor? _docEditor;
  DocumentComposer? _composer;

  FocusNode? _editorFocusNode;

  ScrollController? _scrollController;

  OverlayEntry? _formatBarOverlayEntry;
  final _selectionAnchor = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument()..addListener(_hideOrShowToolbar);
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
    _composer = DocumentComposer()..addListener(_hideOrShowToolbar);
    _editorFocusNode = FocusNode();
    _scrollController = ScrollController()..addListener(_hideOrShowToolbar);
  }

  @override
  void dispose() {
    if (_formatBarOverlayEntry != null) {
      _formatBarOverlayEntry!.remove();
    }

    _scrollController!.dispose();
    _editorFocusNode!.dispose();
    _composer!.dispose();
    super.dispose();
  }

  void _hideOrShowToolbar() {
    final selection = _composer!.selection;
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
      _formatBarOverlayEntry ??= OverlayEntry(builder: (context) {
        return EditorToolbar(
          anchor: _selectionAnchor,
          editor: _docEditor,
          composer: _composer,
          closeToolbar: _hideEditorToolbar,
        );
      });

      // Display the toolbar in the application overlay.
      final overlay = Overlay.of(context)!;
      overlay.insert(_formatBarOverlayEntry!);
    }

    // Schedule a callback after this frame to locate the selection
    // bounds on the screen and display the toolbar near the selected
    // text.
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      if (_formatBarOverlayEntry == null) {
        return;
      }

      final docBoundingBox = (_docLayoutKey.currentState as DocumentLayout)
          .getRectForSelection(
              _composer!.selection!.base, _composer!.selection!.extent)!;
      final docBox =
          _docLayoutKey.currentContext!.findRenderObject() as RenderBox;
      final overlayBoundingBox = Rect.fromPoints(
        docBox.localToGlobal(docBoundingBox.topLeft,
            ancestor: context.findRenderObject()),
        docBox.localToGlobal(docBoundingBox.bottomRight,
            ancestor: context.findRenderObject()),
      );

      _selectionAnchor.value = overlayBoundingBox.topCenter;
    });
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
      _formatBarOverlayEntry!.remove();
      _formatBarOverlayEntry = null;
    }

    // Ensure that focus returns to the editor.
    //
    // I tried explicitly unfocus()'ing the URL textfield
    // in the toolbar but it didn't return focus to the
    // editor. I'm not sure why.
    _editorFocusNode!.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditor.custom(
      editor: _docEditor!,
      composer: _composer,
      focusNode: _editorFocusNode,
      scrollController: _scrollController,
      documentLayoutKey: _docLayoutKey,
      maxWidth: 600, // arbitrary choice for maximum width
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      componentBuilders: [
        checkBoxBuilder,
        ...defaultComponentBuilders,
      ],
    );
  }
}

Widget? checkBoxBuilder(ComponentContext componentContext) {
  final checkBoxNode = componentContext.documentNode;
  if (checkBoxNode is! CheckBoxNode) {
    return null;
  }

  final textSelection =
      componentContext.nodeSelection?.nodeSelection as TextSelection?;
  final showCaret = componentContext.showCaret &&
      (componentContext.nodeSelection?.isExtent ?? false);

  return CheckBoxComponent(
    textKey: componentContext.componentKey,
    text: checkBoxNode.text,
    styleBuilder: componentContext.extensions[textStylesExtensionKey],
    checked: checkBoxNode.checked,
    onChanged: (value) {
      if (value != null) {
        checkBoxNode.checked = value;
      }
    },
    indent: checkBoxNode.indent,
    textSelection: textSelection,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey]
            as SelectionStyle)
        .selectionColor,
    showCaret: showCaret,
    caretColor: (componentContext.extensions[selectionStylesExtensionKey]
            as SelectionStyle)
        .textCaretColor,
  );
}

class CheckBoxComponent extends StatelessWidget {
  const CheckBoxComponent({
    Key? key,
    required this.textKey,
    required this.text,
    required this.styleBuilder,
    this.indent = 0,
    this.indentExtent = 25,
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.showDebugPaint = false,
    required this.onChanged,
    this.checked = false,
  }) : super(key: key);

  final GlobalKey textKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final int indent;
  final int indentExtent;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool showDebugPaint;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  TextStyle _textStyleBuilder(Set<Attribution> attributions) {
    // apply default style.
    final style = styleBuilder(attributions);

    // apply checkbox item specific style
    return style.copyWith(
      color: checked ? Colors.black : Colors.grey.shade600,
      fontWeight: checked ? FontWeight.bold : FontWeight.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: checked, onChanged: onChanged),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextComponent(
              key: textKey,
              text: text,
              textStyleBuilder: _textStyleBuilder,
              textSelection: textSelection,
              selectionColor: selectionColor,
              showCaret: showCaret,
              caretColor: caretColor,
              showDebugPaint: showDebugPaint,
            ),
          ),
        ),
      ],
    );
  }
}

class CheckBoxNode extends ParagraphNode {
  CheckBoxNode({
    required String id,
    required AttributedText text,
    bool checked = false,
    int indent = 0,
    Map<String, dynamic>? metadata,
  })  : _checked = checked,
        _indent = indent,
        super(
          id: id,
          text: text,
          metadata: metadata,
        );

  bool _checked;
  bool get checked => _checked;
  set checked(bool value) {
    if (value == _checked) return;
    _checked = value;
    notifyListeners();
  }

  int _indent;
  int get indent => _indent;
  set indent(int newIndent) {
    if (newIndent == _indent) return;
    _indent = newIndent;
    notifyListeners();
  }
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'H1 sample content',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              'Hanami (花見, "flower viewing") is the Japanese traditional custom of enjoying the transient beauty of flowers; flowers ("hana") are in this case almost always referring to those of the cherry ("sakura") or, less frequently, plum ("ume") trees. From the end of March to early May, cherry trees bloom all over Japan. The blossom forecast cherry blossom front is announced each year by the weather bureau - check https://www.jnto.go.jp/sakura/eng/index.php for details - and should watched carefully by those planning hanami as the blossoms only last a week or two.',
        ),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Decide to visit Okinawa or Honshu',
          spans: AttributedSpans(
            attributions: [
              const SpanMarker(
                attribution: strikethroughAttribution,
                offset: 0,
                markerType: SpanMarkerType.start,
              ),
              const SpanMarker(
                attribution: strikethroughAttribution,
                offset: 100, // TODO: Calculate this based on text length
                markerType: SpanMarkerType.end,
              ),
            ],
          ),
        ),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Select an airline and a place to stay'),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Book everything'),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: "Don't forget to bring your camera"),
      ),
      HorizontalRuleNode(id: DocumentEditor.createNodeId()),
      CheckBoxNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Gotta do this thing right now'),
      ),
      CheckBoxNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Gotta do this thing right now'),
      ),
      CheckBoxNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(text: 'Gotta do this thing right now'),
      ),
    ],
  );
}
