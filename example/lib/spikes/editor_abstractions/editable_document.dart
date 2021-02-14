import 'package:example/spikes/editor_abstractions/default_editor/box_component.dart';
import 'package:example/spikes/editor_abstractions/default_editor/document_interaction.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'core/document.dart';
import 'core/document_composer.dart';
import 'core/document_editor.dart';
import 'core/document_layout.dart';
import 'core/document_selection.dart';
import 'custom_components/text_with_hint.dart';
import 'default_editor/document_composer_actions.dart';
import 'default_editor/horizontal_rule.dart';
import 'default_editor/image.dart';
import 'default_editor/list_items.dart';
import 'default_editor/paragraph.dart';
import 'default_editor/styles.dart';
import 'default_editor/text.dart';

/// A user-editable rich text document.
///
/// An `EditableDocument` brings together the key pieces needed
/// to display a user-editable rich text document:
///  * document model
///  * document layout
///  * document interaction (tapping, dragging, typing, scrolling)
///  * document composer
///
/// The document model is responsible for holding the content of a
/// rich text document. The document model provides access to the
/// nodes within the document, and facilitates document edit
/// operations.
///
/// Document layout is responsible for positioning and rendering the
/// various visual components in the document. It's also responsible
/// for linking logical document nodes to visual document components
/// to facilitate user interactions like tapping and dragging.
///
/// Document interaction is responsible for taking appropriate actions
/// in response to user taps, drags, and key presses.
///
/// Document composer is responsible for owning and altering document
/// selection, as well as manipulating the logical document, e.g.,
/// typing new characters, deleting characters, deleting selections.
class EditableDocument extends StatefulWidget {
  const EditableDocument({
    Key key,
    this.document,
    @required this.editor,
    this.scrollController,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// The rich text document to be edited within this `EditableDocument`.
  ///
  /// Changing the `document` instance will clear any existing
  /// user selection and replace the entire previous document
  /// with the new one.
  final RichTextDocument document;

  /// The `editor` is responsible for performing all content
  /// manipulation operations on the supplied `document`.
  final DocumentEditor editor;

  final ScrollController scrollController;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when true.
  final showDebugPaint;

  @override
  _EditableDocumentState createState() => _EditableDocumentState();
}

class _EditableDocumentState extends State<EditableDocument> {
  // Holds a reference to the current `RichTextDocument` and
  // maintains a `DocumentSelection`. The `DocumentComposer`
  // is responsible for editing the `RichTextDocument` based on
  // the current `DocumentSelection`.
  DocumentComposer _documentComposer;

  // GlobalKey used to access the `DocumentLayoutState` to figure
  // out where in the document the user taps or drags.
  final _docLayoutKey = GlobalKey();
  DocumentLayout get _layout => _docLayoutKey.currentState as DocumentLayout;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(EditableDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document) {
      _createDocumentComposer();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _createDocumentComposer() {
    print('Creating the document composer');
    if (_documentComposer != null) {
      _documentComposer.selection.removeListener(_onSelectionChange);
    }
    setState(() {
      _documentComposer = DocumentComposer(
        document: widget.document,
        editor: widget.editor,
        layout: _layout,
        keyboardActions: _composerKeyboardActions,
      );
      _documentComposer.selection.addListener(_onSelectionChange);
      _onSelectionChange();
    });
  }

  void _onSelectionChange() {
    print('EditableDocument: _onSelectionChange()');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_documentComposer == null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _createDocumentComposer();
      });
      return SizedBox();
    }

    return DocumentInteractor(
      documentLayoutKey: _docLayoutKey,
      composer: _documentComposer,
      showDebugPaint: widget.showDebugPaint,
      // TODO: combine the ValueListenableBuilder and AnimatedBuilder
      //       into a single rebuilder on either event.
      child: ValueListenableBuilder(
        valueListenable: _documentComposer?.selection ?? AlwaysStoppedAnimation(0),
        builder: (context, value, child) {
          return AnimatedBuilder(
            animation: widget.document,
            builder: (context, child) {
              return DefaultDocumentLayout(
                key: _docLayoutKey,
                document: widget.document,
                documentSelection: _documentComposer?.selection?.value,
                componentBuilder: defaultComponentBuilder,
                showDebugPaint: widget.showDebugPaint,
              );
            },
          );
        },
      ),
    );
  }
}

final ComponentBuilder defaultComponentBuilder = ({
  @required BuildContext context,
  @required RichTextDocument document,
  @required DocumentNode currentNode,
  @required DocumentNodeSelection nodeSelection,
  @required GlobalKey key,
  bool showDebugPaint = false,
}) {
  print('Building a document component for node: ${currentNode.id}');
  if (currentNode is ParagraphNode) {
    final textSelection = nodeSelection == null || nodeSelection.nodeSelection is! TextSelection
        ? null
        : nodeSelection.nodeSelection as TextSelection;
    if (nodeSelection != null && nodeSelection.nodeSelection is! TextSelection) {
      print('ERROR: Building a paragraph component but the selection is not a TextSelection: ${currentNode.id}');
    }
    final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;
    final highlightWhenEmpty = nodeSelection == null ? false : nodeSelection.highlightWhenEmpty;

    // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
    // if (hasCursor) {
    //   print('   - ^ has cursor');
    // }

    print(' - building a paragraph with selection:');
    print('   - base: ${textSelection?.base}');
    print('   - extent: ${textSelection?.extent}');

    TextAlign textAlign = TextAlign.left;
    final textAlignName = currentNode.metadata['textAlign'];
    switch (textAlignName) {
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }

    if (document.getNodeIndex(currentNode) == 0 && currentNode.text.text.isEmpty && !hasCursor) {
      print(' - this is the title node');
      return TextWithHintComponent(
        documentComponentKey: key,
        text: currentNode.text,
        styleBuilder: defaultStyleBuilder,
        metadata: currentNode.metadata,
        hintText: 'Enter your title',
        textAlign: textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: showDebugPaint,
      );
    } else if (document.nodes.length <= 2 &&
        document.getNodeIndex(currentNode) == 1 &&
        currentNode.text.text.isEmpty &&
        !hasCursor) {
      print(' - this is the 1st paragraph node');
      return TextWithHintComponent(
        documentComponentKey: key,
        text: currentNode.text,
        styleBuilder: defaultStyleBuilder,
        metadata: currentNode.metadata,
        hintText: 'Enter your content...',
        textAlign: textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: showDebugPaint,
      );
    } else {
      return TextComponent(
        key: key,
        text: currentNode.text,
        styleBuilder: defaultStyleBuilder,
        metadata: currentNode.metadata,
        textAlign: textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: showDebugPaint,
      );
    }
  } else if (currentNode is ImageNode) {
    final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as BinarySelection;
    final isSelected = selection != null && selection.position.isIncluded;

    return ImageComponent(
      componentKey: key,
      imageUrl: currentNode.imageUrl,
      isSelected: isSelected,
    );
  } else if (currentNode is ListItemNode && currentNode.type == ListItemType.unordered) {
    final textSelection = nodeSelection == null ? null : nodeSelection.nodeSelection as TextSelection;
    final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;

    return UnorderedListItemComponent(
      textKey: key,
      text: currentNode.text,
      indent: currentNode.indent,
      textSelection: textSelection,
      hasCursor: hasCursor,
      showDebugPaint: showDebugPaint,
    );
  } else if (currentNode is ListItemNode && currentNode.type == ListItemType.ordered) {
    int index = 1;
    DocumentNode nodeAbove = document.getNodeBefore(currentNode);
    while (nodeAbove != null &&
        nodeAbove is ListItemNode &&
        nodeAbove.type == ListItemType.ordered &&
        nodeAbove.indent >= currentNode.indent) {
      if ((nodeAbove as ListItemNode).indent == currentNode.indent) {
        index += 1;
      }
      nodeAbove = document.getNodeBefore(nodeAbove);
    }

    final textSelection = nodeSelection == null ? null : nodeSelection.nodeSelection as TextSelection;
    final hasCursor = nodeSelection != null ? nodeSelection.isExtent : false;

    return OrderedListItemComponent(
      textKey: key,
      listIndex: index,
      text: currentNode.text,
      textSelection: textSelection,
      hasCursor: hasCursor,
      indent: currentNode.indent,
      showDebugPaint: showDebugPaint,
    );
  } else if (currentNode is HorizontalRuleNode) {
    final selection = nodeSelection == null ? null : nodeSelection.nodeSelection as BinarySelection;
    final isSelected = selection != null && selection.position.isIncluded;

    return HorizontalRuleComponent(
      componentKey: key,
      isSelected: isSelected,
    );
  } else {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 100,
      child: Placeholder(),
    );
  }
};

final _composerKeyboardActions = <ComposerKeyboardAction>[
  ComposerKeyboardAction.simple(
    action: doNothingWhenThereIsNoSelection,
  ),
  ComposerKeyboardAction.simple(
    action: indentListItemWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: unindentListItemWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: splitListItemWhenEnterPressed,
  ),
  ComposerKeyboardAction.simple(
    action: pasteWhenCmdVIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: copyWhenCmdVIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: applyBoldWhenCmdBIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: applyItalicsWhenCmdIIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: collapseSelectionWhenDirectionalKeyIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteExpandedSelectionWhenCharacterOrDestructiveKeyPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteBoxWhenBackspaceOrDeleteIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: insertCharacterInParagraph,
  ),
  ComposerKeyboardAction.simple(
    action: insertCharacterInTextComposable,
  ),
  ComposerKeyboardAction.simple(
    action: insertNewlineInParagraph,
  ),
  ComposerKeyboardAction.simple(
    action: splitParagraphWhenEnterPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteCharacterWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: mergeNodeWithPreviousWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteEmptyParagraphWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: moveParagraphSelectionUpWhenBackspaceIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: deleteCharacterWhenDeleteIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: mergeNodeWithNextWhenDeleteIsPressed,
  ),
  ComposerKeyboardAction.simple(
    action: moveUpDownLeftAndRightWithArrowKeys,
  ),
];
