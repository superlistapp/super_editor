import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Example of a rich text editor.
///
/// This editor will expand in functionality as the rich text
/// package expands.
class ExampleEditor extends StatefulWidget {
  @override
  _ExampleEditorState createState() => _ExampleEditorState();
}

class _ExampleEditorState extends State<ExampleEditor> {
  final GlobalKey _docLayoutKey = GlobalKey();

  Document _doc;
  DocumentEditor _docEditor;
  DocumentComposer _composer;

  ScrollController _scrollController;

  OverlayEntry _formatBarOverlayEntry;
  final _selectionAnchor = ValueNotifier<Offset>(null);

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument()..addListener(_onDocChange);
    _docEditor = DocumentEditor(document: _doc);
    _composer = DocumentComposer()..addListener(_onDocChange);
    _scrollController = ScrollController()..addListener(_onDocChange);
  }

  @override
  void dispose() {
    if (_formatBarOverlayEntry != null) {
      _formatBarOverlayEntry.remove();
    }

    _scrollController.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _onDocChange() {
    final selection = _composer.selection;
    if (selection == null) {
      // Nothing is selected. We don't want to show anything
      // in this case.
      _hideFormatBar();

      return;
    }
    if (selection.base.nodeId != selection.extent.nodeId) {
      // More than one node is selected. We don't want to show
      // anything in this case.
      _hideFormatBar();

      return;
    }
    if (selection.isCollapsed) {
      // We only want to show format controls when a span of text
      // is selected. Therefore, we ignore collapsed selections.
      _hideFormatBar();

      return;
    }

    final textNode = _doc.getNodeById(selection.extent.nodeId);
    if (textNode is! TextNode) {
      // The currently selected content is not a paragraph. We don't
      // want to show anything in this case.
      _hideFormatBar();

      return;
    }

    _showFormatBar();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final docBoundingBox = (_docLayoutKey.currentState as DocumentLayout)
          .getRectForSelection(_composer.selection.base, _composer.selection.extent);
      final docBox = _docLayoutKey.currentContext.findRenderObject() as RenderBox;
      final overlayBoundingBox = Rect.fromPoints(
        docBox.localToGlobal(docBoundingBox.topLeft, ancestor: context.findRenderObject()),
        docBox.localToGlobal(docBoundingBox.bottomRight, ancestor: context.findRenderObject()),
      );

      _selectionAnchor.value = overlayBoundingBox.topCenter;
    });
  }

  void _showFormatBar() {
    if (_formatBarOverlayEntry == null) {
      _formatBarOverlayEntry ??= OverlayEntry(builder: (context) {
        return TextFormatBar(
          anchor: _selectionAnchor,
          editor: _docEditor,
          composer: _composer,
          closeToolbar: _hideFormatBar,
        );
      });

      final overlay = Overlay.of(context);
      overlay.insert(_formatBarOverlayEntry);
    }
  }

  void _hideFormatBar() {
    // Null out the selection anchor so that when it re-appears,
    // the bar doesn't momentarily "flash" at its old anchor position.
    _selectionAnchor.value = null;

    if (_formatBarOverlayEntry != null) {
      _formatBarOverlayEntry.remove();
      _formatBarOverlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Editor.standard(
      editor: _docEditor,
      composer: _composer,
      scrollController: _scrollController,
      documentLayoutKey: _docLayoutKey,
      maxWidth: 600,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    );
  }
}

class TextFormatBar extends StatefulWidget {
  const TextFormatBar({
    Key key,
    this.anchor,
    @required this.editor,
    @required this.composer,
    @required this.closeToolbar,
  }) : super(key: key);

  final ValueNotifier<Offset> anchor;
  final DocumentEditor editor;
  final DocumentComposer composer;
  final VoidCallback closeToolbar;

  @override
  _TextFormatBarState createState() => _TextFormatBarState();
}

class _TextFormatBarState extends State<TextFormatBar> {
  bool _showUrlField = false;
  FocusNode _urlFocusNode;
  TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlFocusNode = FocusNode();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlFocusNode.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool _isConvertibleNode() {
    final selection = widget.composer.selection;
    if (selection.base.nodeId != selection.extent.nodeId) {
      return false;
    }

    final selectedNode = widget.editor.document.getNodeById(selection.extent.nodeId);
    return selectedNode is ParagraphNode || selectedNode is ListItemNode;
  }

  TextType _getCurrentTextType() {
    final selectedNode = widget.editor.document.getNodeById(widget.composer.selection.extent.nodeId);
    if (selectedNode is ParagraphNode) {
      final type = selectedNode.metadata['blockType'];

      if (type == header1Attribution) {
        return TextType.header1;
      } else if (type == header2Attribution) {
        return TextType.header2;
      } else if (type == header3Attribution) {
        return TextType.header3;
      } else if (type == blockquoteAttribution) {
        return TextType.blockquote;
      } else {
        return TextType.paragraph;
      }
    } else if (selectedNode is ListItemNode) {
      return selectedNode.type == ListItemType.ordered ? TextType.orderedListItem : TextType.unorderedListItem;
    } else {
      throw Exception('Invalid node type: $selectedNode');
    }
  }

  TextAlign _getCurrentTextAlignment() {
    final selectedNode = widget.editor.document.getNodeById(widget.composer.selection.extent.nodeId);
    if (selectedNode is ParagraphNode) {
      final align = selectedNode.metadata['textAlign'];
      switch (align) {
        case 'left':
          return TextAlign.left;
        case 'center':
          return TextAlign.center;
        case 'right':
          return TextAlign.right;
        case 'justify':
          return TextAlign.justify;
        default:
          return TextAlign.left;
      }
    } else {
      throw Exception('Alignment does not apply to node of type: $selectedNode');
    }
  }

  bool _isTextAlignable() {
    final selection = widget.composer.selection;
    if (selection.base.nodeId != selection.extent.nodeId) {
      return false;
    }

    final selectedNode = widget.editor.document.getNodeById(selection.extent.nodeId);
    return selectedNode is ParagraphNode;
  }

  void _convertTextToNewType(TextType newType) {
    final existingTextType = _getCurrentTextType();

    if (existingTextType == newType) {
      // The text is already the desired type. Return.
      return;
    }

    if (_isListItem(existingTextType) && _isListItem(newType)) {
      widget.editor.executeCommand(
        ChangeListItemTypeCommand(
          nodeId: widget.composer.selection.extent.nodeId,
          newType: newType == TextType.orderedListItem ? ListItemType.ordered : ListItemType.unordered,
        ),
      );
    } else if (_isListItem(existingTextType) && !_isListItem(newType)) {
      widget.editor.executeCommand(
        ConvertListItemToParagraphCommand(
          nodeId: widget.composer.selection.extent.nodeId,
          paragraphMetadata: {
            'blockType': _getBlockTypeAttribution(newType),
          },
        ),
      );
    } else if (!_isListItem(existingTextType) && _isListItem(newType)) {
      widget.editor.executeCommand(
        ConvertParagraphToListItemCommand(
          nodeId: widget.composer.selection.extent.nodeId,
          type: newType == TextType.orderedListItem ? ListItemType.ordered : ListItemType.unordered,
        ),
      );
    } else {
      // Apply a new block type to an existing paragraph node.
      final existingNode = widget.editor.document.getNodeById(widget.composer.selection.extent.nodeId);
      (existingNode as ParagraphNode).metadata['blockType'] = _getBlockTypeAttribution(newType);
    }
  }

  bool _isListItem(TextType type) {
    return type == TextType.orderedListItem || type == TextType.unorderedListItem;
  }

  Attribution _getBlockTypeAttribution(TextType newType) {
    switch (newType) {
      case TextType.header1:
        return header1Attribution;
      case TextType.header2:
        return header2Attribution;
      case TextType.header3:
        return header3Attribution;
      case TextType.blockquote:
        return blockquoteAttribution;
      case TextType.paragraph:
      default:
        return null;
    }
  }

  void _toggleBold() {
    widget.editor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: widget.composer.selection,
        attributions: {boldAttribution},
      ),
    );
  }

  void _toggleItalics() {
    widget.editor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: widget.composer.selection,
        attributions: {italicsAttribution},
      ),
    );
  }

  void _toggleStrikethrough() {
    widget.editor.executeCommand(
      ToggleTextAttributionsCommand(
        documentSelection: widget.composer.selection,
        attributions: {strikethroughAttribution},
      ),
    );
  }

  bool _isSingleLinkSelected() {
    return _getSelectedLinkSpans().length == 1;
  }

  bool _areMultipleLinksSelected() {
    return _getSelectedLinkSpans().length >= 2;
  }

  Set<AttributionSpan> _getSelectedLinkSpans() {
    final selection = widget.composer.selection;
    final baseOffset = (selection.base.nodePosition as TextPosition).offset;
    final extentOffset = (selection.extent.nodePosition as TextPosition).offset;
    final selectionStart = min(baseOffset, extentOffset);
    final selectionEnd = max(baseOffset, extentOffset);
    final selectionRange = TextRange(start: selectionStart, end: selectionEnd - 1);
    print('Selection from: $baseOffset to $extentOffset');

    final textNode = widget.editor.document.getNodeById(selection.extent.nodeId) as TextNode;
    print('Text node: $textNode');
    final text = textNode.text;
    print('Selected text: "${text.text.substring(selectionStart, selectionEnd)}"');

    final overlappingLinkAttributions = text.getAttributionSpansInRange(
      attributionFilter: (Attribution attribution) => attribution is LinkAttribution,
      range: selectionRange,
    );

    print('Found ${overlappingLinkAttributions.length} links');
    for (final attributionSpan in overlappingLinkAttributions) {
      print(' - ${attributionSpan.attribution}, ${attributionSpan.start} -> ${attributionSpan.end}');
    }
    return overlappingLinkAttributions;
  }

  void _onLinkPressed() {
    print('_onLinkPressed');
    final selection = widget.composer.selection;
    final baseOffset = (selection.base.nodePosition as TextPosition).offset;
    final extentOffset = (selection.extent.nodePosition as TextPosition).offset;
    final selectionStart = min(baseOffset, extentOffset);
    final selectionEnd = max(baseOffset, extentOffset);
    final selectionRange = TextRange(start: selectionStart, end: selectionEnd - 1);
    print('Selection from: $baseOffset to $extentOffset');

    final textNode = widget.editor.document.getNodeById(selection.extent.nodeId) as TextNode;
    print('Text node: $textNode');
    final text = textNode.text;

    final overlappingLinkAttributions = text.getAttributionSpansInRange(
      attributionFilter: (Attribution attribution) => attribution is LinkAttribution,
      range: selectionRange,
    );

    if (overlappingLinkAttributions.length >= 2) {
      // Do nothing when multiple links are selected.
      print('There are 2+ links in the selection. Doing nothing.');
      return;
    }

    if (overlappingLinkAttributions.isNotEmpty) {
      // The selected text contains one other link.
      final overlappingLinkSpan = overlappingLinkAttributions.first;
      final isLinkSelectionOnTrailingEdge =
          (overlappingLinkSpan.start >= selectionRange.start && overlappingLinkSpan.start <= selectionRange.end) ||
              (overlappingLinkSpan.end >= selectionRange.start && overlappingLinkSpan.end <= selectionRange.end);

      if (isLinkSelectionOnTrailingEdge) {
        // The selected text covers the beginning, or the end, or the entire
        // existing link. Remove the link attribution from the selected text.
        print('Removing trailing edge of existing link');
        text.removeAttribution(overlappingLinkSpan.attribution, selectionRange);
      } else {
        // The selected text sits somewhere within the existing link. Remove
        // the entire link attribution.
        print('Selection is within a link. Removing entire link.');
        text.removeAttribution(
          overlappingLinkSpan.attribution,
          TextRange(start: overlappingLinkSpan.start, end: overlappingLinkSpan.end),
        );
      }
    } else {
      // There are no other links in the selection. Show the URL text field.
      setState(() {
        _showUrlField = true;
        _urlFocusNode.requestFocus();
      });
    }
  }

  void _applyLink() {
    final url = _urlController.text;

    final selection = widget.composer.selection;
    final baseOffset = (selection.base.nodePosition as TextPosition).offset;
    final extentOffset = (selection.extent.nodePosition as TextPosition).offset;
    final selectionStart = min(baseOffset, extentOffset);
    final selectionEnd = max(baseOffset, extentOffset);
    final selectionRange = TextRange(start: selectionStart, end: selectionEnd - 1);
    print('Selection from: $baseOffset to $extentOffset');

    final textNode = widget.editor.document.getNodeById(selection.extent.nodeId) as TextNode;
    print('Text node: $textNode');
    final text = textNode.text;

    final trimmedRange = _trimTextRangeWhitespace(text, selectionRange);

    final linkAttribution = LinkAttribution(url: Uri.parse(url));
    print('Adding $linkAttribution from ${trimmedRange.start} to ${trimmedRange.end}');
    text.addAttribution(
      linkAttribution,
      trimmedRange,
    );

    // Clear the field and hide the URL bar
    _urlController.clear();
    setState(() {
      _showUrlField = false;
      _urlFocusNode.unfocus();
      widget.closeToolbar();
    });
  }

  TextRange _trimTextRangeWhitespace(AttributedText text, TextRange range) {
    int startOffset = range.start;
    int endOffset = range.end;

    while (startOffset < range.end && text.text[startOffset] == ' ') {
      startOffset += 1;
    }
    while (endOffset > startOffset && text.text[endOffset] == ' ') {
      endOffset -= 1;
    }

    return TextRange(start: startOffset, end: endOffset);
  }

  void _changeAlignment(TextAlign newAlignment) {
    String newAlignmentValue;
    switch (newAlignment) {
      case TextAlign.left:
      case TextAlign.start:
        newAlignmentValue = 'left';
        break;
      case TextAlign.center:
        newAlignmentValue = 'center';
        break;
      case TextAlign.right:
      case TextAlign.end:
        newAlignmentValue = 'right';
        break;
      case TextAlign.justify:
        newAlignmentValue = 'justify';
        break;
    }

    final selectedNode = widget.editor.document.getNodeById(widget.composer.selection.extent.nodeId) as ParagraphNode;
    selectedNode.metadata['textAlign'] = newAlignmentValue;
  }

  String _getTextTypeName(TextType textType) {
    switch (textType) {
      case TextType.header1:
        return AppLocalizations.of(context).labelHeader1;
      case TextType.header2:
        return AppLocalizations.of(context).labelHeader2;
      case TextType.header3:
        return AppLocalizations.of(context).labelHeader3;
      case TextType.paragraph:
        return AppLocalizations.of(context).labelParagraph;
      case TextType.blockquote:
        return AppLocalizations.of(context).labelBlockquote;
      case TextType.orderedListItem:
        return AppLocalizations.of(context).labelOrderedListItem;
      case TextType.unorderedListItem:
        return AppLocalizations.of(context).labelUnorderedListItem;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.anchor,
      builder: (context, offset, child) {
        if (widget.anchor.value == null || widget.composer.selection == null) {
          return SizedBox();
        }

        return SizedBox.expand(
          child: Stack(
            children: [
              if (_showUrlField)
                Positioned(
                  left: widget.anchor.value.dx,
                  top: widget.anchor.value.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0.0),
                    child: _buildUrlField(),
                  ),
                ),
              Positioned(
                left: widget.anchor.value.dx,
                top: widget.anchor.value.dy,
                child: FractionalTranslation(
                  translation: Offset(-0.5, -1.4),
                  child: _buildToolbar(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Material(
      shape: StadiumBorder(),
      elevation: 5,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isConvertibleNode()) ...[
              Tooltip(
                message: AppLocalizations.of(context).labelTextBlockType,
                child: DropdownButton<TextType>(
                  value: _getCurrentTextType(),
                  items: TextType.values
                      .map((textType) => DropdownMenuItem<TextType>(
                            value: textType,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(_getTextTypeName(textType)),
                            ),
                          ))
                      .toList(),
                  icon: Icon(Icons.arrow_drop_down),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                  ),
                  underline: SizedBox(),
                  elevation: 0,
                  itemHeight: 48,
                  onChanged: _convertTextToNewType,
                ),
              ),
              _buildVerticalDivider(),
            ],
            Center(
              child: IconButton(
                onPressed: _toggleBold,
                icon: Icon(Icons.format_bold),
                splashRadius: 16,
                tooltip: AppLocalizations.of(context).labelBold,
              ),
            ),
            Center(
              child: IconButton(
                onPressed: _toggleItalics,
                icon: Icon(Icons.format_italic),
                splashRadius: 16,
                tooltip: AppLocalizations.of(context).labelItalics,
              ),
            ),
            Center(
              child: IconButton(
                onPressed: _toggleStrikethrough,
                icon: Icon(Icons.strikethrough_s),
                splashRadius: 16,
                tooltip: AppLocalizations.of(context).labelStrikethrough,
              ),
            ),
            Center(
              child: IconButton(
                onPressed: _areMultipleLinksSelected() ? null : _onLinkPressed,
                icon: Icon(Icons.link),
                color: _isSingleLinkSelected() ? const Color(0xFF007AFF) : IconTheme.of(context).color,
                splashRadius: 16,
                tooltip: AppLocalizations.of(context).labelLink,
              ),
            ),
            if (_isTextAlignable()) ...[
              _buildVerticalDivider(),
              Tooltip(
                message: AppLocalizations.of(context).labelTextAlignment,
                child: DropdownButton<TextAlign>(
                  value: _getCurrentTextAlignment(),
                  items: [TextAlign.left, TextAlign.center, TextAlign.right, TextAlign.justify]
                      .map((textAlign) => DropdownMenuItem<TextAlign>(
                            value: textAlign,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(_buildTextAlignIcon(textAlign)),
                            ),
                          ))
                      .toList(),
                  icon: Icon(Icons.arrow_drop_down),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                  ),
                  underline: SizedBox(),
                  elevation: 0,
                  itemHeight: 48,
                  onChanged: _changeAlignment,
                ),
              ),
            ],
            _buildVerticalDivider(),
            Center(
              child: IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_vert),
                splashRadius: 16,
                tooltip: AppLocalizations.of(context).labelMoreOptions,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlField() {
    print('Building url field');
    return Material(
      shape: StadiumBorder(),
      elevation: 5,
      clipBehavior: Clip.hardEdge,
      child: Container(
        width: 400,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          focusNode: _urlFocusNode,
          controller: _urlController,
          decoration: InputDecoration(
            hintText: 'enter url...',
            border: InputBorder.none,
          ),
          onSubmitted: (newValue) => _applyLink(),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  IconData _buildTextAlignIcon(TextAlign align) {
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        return Icons.format_align_left;
      case TextAlign.center:
        return Icons.format_align_center;
      case TextAlign.right:
      case TextAlign.end:
        return Icons.format_align_right;
      case TextAlign.justify:
        return Icons.format_align_justify;
    }
  }
}

enum TextType {
  header1,
  header2,
  header3,
  paragraph,
  blockquote,
  orderedListItem,
  unorderedListItem,
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      // ImageNode(
      //   id: DocumentEditor.createNodeId(),
      //   imageUrl: 'https://i.ytimg.com/vi/fq4N0hgOWzU/maxresdefault.jpg',
      // ),
      // ParagraphNode(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'Example Document',
      //   ),
      //   metadata: {
      //     'blockType': header1Attribution,
      //   },
      // ),
      // HorizontalRuleNode(id: DocumentEditor.createNodeId()),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
      // ParagraphNode(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'This is a blockquote!',
      //   ),
      //   metadata: {
      //     'blockType': blockquoteAttribution,
      //   },
      // ),
      // ListItemNode.unordered(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'This is an unordered list item',
      //   ),
      // ),
      // ListItemNode.unordered(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'This is another list item',
      //   ),
      // ),
      // ListItemNode.unordered(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'This is a 3rd list item',
      //   ),
      // ),
      // ParagraphNode(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //       text:
      //           'Cras vitae sodales nisi. Vivamus dignissim vel purus vel aliquet. Sed viverra diam vel nisi rhoncus pharetra. Donec gravida ut ligula euismod pharetra. Etiam sed urna scelerisque, efficitur mauris vel, semper arcu. Nullam sed vehicula sapien. Donec id tellus volutpat, eleifend nulla eget, rutrum mauris.'),
      // ),
      // ListItemNode.ordered(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'First thing to do',
      //   ),
      // ),
      // ListItemNode.ordered(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'Second thing to do',
      //   ),
      // ),
      // ListItemNode.ordered(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text: 'Third thing to do',
      //   ),
      // ),
      // ParagraphNode(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text:
      //         'Nam hendrerit vitae elit ut placerat. Maecenas nec congue neque. Fusce eget tortor pulvinar, cursus neque vitae, sagittis lectus. Duis mollis libero eu scelerisque ullamcorper. Pellentesque eleifend arcu nec augue molestie, at iaculis dui rutrum. Etiam lobortis magna at magna pellentesque ornare. Sed accumsan, libero vel porta molestie, tortor lorem eleifend ante, at egestas leo felis sed nunc. Quisque mi neque, molestie vel dolor a, eleifend tempor odio.',
      //   ),
      // ),
      // ParagraphNode(
      //   id: DocumentEditor.createNodeId(),
      //   text: AttributedText(
      //     text:
      //         'Etiam id lacus interdum, efficitur ex convallis, accumsan ipsum. Integer faucibus mollis mauris, a suscipit ante mollis vitae. Fusce justo metus, congue non lectus ac, luctus rhoncus tellus. Phasellus vitae fermentum orci, sit amet sodales orci. Fusce at ante iaculis nunc aliquet pharetra. Nam placerat, nisl in gravida lacinia, nisl nibh feugiat nunc, in sagittis nisl sapien nec arcu. Nunc gravida faucibus massa, sit amet accumsan dolor feugiat in. Mauris ut elementum leo.',
      //   ),
      // ),
    ],
  );
}
