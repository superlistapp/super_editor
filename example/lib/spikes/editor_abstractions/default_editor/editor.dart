import 'package:example/spikes/editor_abstractions/core/attributed_text.dart';
import 'package:example/spikes/editor_abstractions/core/edit_context.dart';
import 'package:example/spikes/editor_abstractions/default_editor/box_component.dart';
import 'package:example/spikes/editor_abstractions/default_editor/document_interaction.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/document.dart';
import '../core/document_composer.dart';
import '../core/document_editor.dart';
import '../core/document_layout.dart';
import '../custom_components/text_with_hint.dart';
import '../default_editor/document_keyboard_actions.dart';
import '../default_editor/horizontal_rule.dart';
import '../default_editor/image.dart';
import '../default_editor/list_items.dart';
import '../default_editor/paragraph.dart';
import '../default_editor/text.dart';

/// A text editor for styled text and multi-media elements.
///
/// An `Editor` brings together the key pieces needed
/// to display a user-editable document:
///  * document model
///  * document editor
///  * document layout
///  * document interaction (tapping, dragging, typing, scrolling)
///  * document composer
///
/// The document model is responsible for holding the content of a
/// document. The document model provides access to the
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
/// Document composer is responsible for owning document
/// selection.
class Editor extends StatefulWidget {
  factory Editor.standard({
    Key key,
    @required Document document,
    @required DocumentEditor editor,
    @required DocumentComposer composer,
    ScrollController scrollController,
    bool showDebugPaint = false,
  }) {
    return Editor._(
      key: key,
      document: document,
      editor: editor,
      composer: composer,
      componentBuilder: defaultComponentBuilder,
      textStyleBuilder: defaultStyleBuilder,
      selectionStyle: defaultSelectionStyle,
      keyboardActions: defaultKeyboardActions,
      scrollController: scrollController,
      showDebugPaint: showDebugPaint,
    );
  }

  factory Editor.custom({
    Key key,
    @required Document document,
    @required DocumentEditor editor,
    @required DocumentComposer composer,
    AttributionStyleBuilder textStyleBuilder,
    SelectionStyle selectionStyle,
    List<DocumentKeyboardAction> keyboardActions,
    ComponentBuilder componentBuilder,
    ScrollController scrollController,
    bool showDebugPaint = false,
  }) {
    return Editor._(
      key: key,
      document: document,
      editor: editor,
      composer: composer,
      componentBuilder: componentBuilder ?? defaultComponentBuilder,
      textStyleBuilder: textStyleBuilder ?? defaultStyleBuilder,
      selectionStyle: selectionStyle ?? defaultSelectionStyle,
      keyboardActions: keyboardActions ?? defaultKeyboardActions,
      scrollController: scrollController,
      showDebugPaint: showDebugPaint,
    );
  }

  const Editor._({
    Key key,
    @required this.document,
    @required this.editor,
    @required this.composer,
    @required this.componentBuilder,
    @required this.textStyleBuilder,
    @required this.selectionStyle,
    @required this.keyboardActions,
    this.scrollController,
    this.showDebugPaint = false,
  })  : assert(document != null),
        assert(editor != null),
        assert(composer != null),
        assert(componentBuilder != null),
        assert(textStyleBuilder != null),
        assert(keyboardActions != null),
        super(key: key);

  /// The rich text document to be edited within this `EditableDocument`.
  ///
  /// Changing the `document` instance will clear any existing
  /// user selection and replace the entire previous document
  /// with the new one.
  final Document document;

  /// The `editor` is responsible for performing all content
  /// manipulation operations on the supplied `document`.
  final DocumentEditor editor;

  final DocumentComposer composer;

  /// Factory that creates instances of each visual component
  /// displayed in the document layout, e.g., paragraph
  /// component, image component, horizontal rule component, etc.
  final ComponentBuilder componentBuilder;

  /// Factory that creates `TextStyle`s based on given
  /// attributions. An attribution can be anything. It is up
  /// to the `textStyleBuilder` to interpret attributions
  /// as desired to produce corresponding styles.
  final AttributionStyleBuilder textStyleBuilder;

  /// Styles to be applied to selected text.
  final SelectionStyle selectionStyle;

  /// All actions that this editor takes in response to key
  /// events, e.g., text entry, newlines, character deletion,
  /// copy, paste, etc.
  final List<DocumentKeyboardAction> keyboardActions;

  final ScrollController scrollController;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when true.
  final showDebugPaint;

  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  // GlobalKey used to access the `DocumentLayoutState` to figure
  // out where in the document the user taps or drags.
  final _docLayoutKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return DocumentInteractor(
      documentLayoutKey: _docLayoutKey,
      editContext: EditContext(
        document: widget.document,
        editor: widget.editor,
        composer: widget.composer,
        documentLayout: _docLayoutKey.currentState as DocumentLayout,
      ),
      keyboardActions: widget.keyboardActions,
      showDebugPaint: widget.showDebugPaint,
      child: AnimatedBuilder(
        animation: widget.composer,
        builder: (context, child) {
          return AnimatedBuilder(
            animation: widget.document,
            builder: (context, child) {
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                print('Doc layout key state: ${_docLayoutKey.currentState}');
              });

              return DefaultDocumentLayout(
                key: _docLayoutKey,
                document: widget.document,
                documentSelection: widget.composer.selection,
                componentBuilder: widget.componentBuilder,
                extensions: {
                  textStylesExtensionKey: widget.textStyleBuilder,
                  selectionStylesExtensionKey: widget.selectionStyle,
                },
                showDebugPaint: widget.showDebugPaint,
              );
            },
          );
        },
      ),
    );
  }
}

/// The key in the `extensions` map that corresponds to the
/// text style builder within the `ComponentContext` that
/// is used to build each component in the document layout.
final String textStylesExtensionKey = 'editor.text_styles';

/// The key in the `extensions` map that corresponds to the
/// styles applied to selected content.
final String selectionStylesExtensionKey = 'editor.selection_styles';

class SelectionStyle {
  const SelectionStyle({
    this.textCaretColor,
    this.selectionColor,
  });

  final Color textCaretColor;
  final Color selectionColor;
}

final defaultSelectionStyle = const SelectionStyle(
  textCaretColor: Colors.black,
  selectionColor: Colors.lightBlueAccent,
);

/// Creates `TextStyles` for the standard `Editor`.
TextStyle defaultStyleBuilder(Set<dynamic> attributions) {
  TextStyle newStyle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    height: 1.4,
  );

  for (final attribution in attributions) {
    if (attribution is! String) {
      continue;
    }

    switch (attribution) {
      case 'header1':
        newStyle = newStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.0,
        );
        break;
      case 'header2':
        newStyle = newStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF888888),
          height: 1.0,
        );
        break;
      case 'blockquote':
        newStyle = newStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.4,
          color: Colors.grey,
        );
        break;
      case 'bold':
        newStyle = newStyle.copyWith(
          fontWeight: FontWeight.bold,
        );
        break;
      case 'italics':
        newStyle = newStyle.copyWith(
          fontStyle: FontStyle.italic,
        );
        break;
      case 'strikethrough':
        newStyle = newStyle.copyWith(
          decoration: TextDecoration.lineThrough,
        );
        break;
    }
  }
  return newStyle;
}

/// Creates visual components for the standard `Editor`.
final ComponentBuilder defaultComponentBuilder = (componentContext) {
  print('Building a document component for node: ${componentContext.currentNode.id}');
  if (componentContext.currentNode is ParagraphNode) {
    final textSelection =
        componentContext.nodeSelection == null || componentContext.nodeSelection.nodeSelection is! TextSelection
            ? null
            : componentContext.nodeSelection.nodeSelection as TextSelection;
    if (componentContext.nodeSelection != null && componentContext.nodeSelection.nodeSelection is! TextSelection) {
      print(
          'ERROR: Building a paragraph component but the selection is not a TextSelection: ${componentContext.currentNode.id}');
    }
    final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;
    final highlightWhenEmpty =
        componentContext.nodeSelection == null ? false : componentContext.nodeSelection.highlightWhenEmpty;

    // print(' - ${docNode.id}: ${selectedNode?.nodeSelection}');
    // if (hasCursor) {
    //   print('   - ^ has cursor');
    // }

    print(' - building a paragraph with selection:');
    print('   - base: ${textSelection?.base}');
    print('   - extent: ${textSelection?.extent}');

    TextAlign textAlign = TextAlign.left;
    final textAlignName = (componentContext.currentNode as TextNode).metadata['textAlign'];
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

    if (componentContext.document.getNodeIndex(componentContext.currentNode) == 0 &&
        (componentContext.currentNode as TextNode).text.text.isEmpty &&
        !hasCursor) {
      print(' - this is the title node');
      return TextWithHintComponent(
        documentComponentKey: componentContext.componentKey,
        text: (componentContext.currentNode as TextNode).text,
        styleBuilder: componentContext.extensions[textStylesExtensionKey],
        metadata: (componentContext.currentNode as TextNode).metadata,
        hintText: 'Enter your title',
        textAlign: textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: componentContext.showDebugPaint,
      );
    } else if (componentContext.document.nodes.length <= 2 &&
        componentContext.document.getNodeIndex(componentContext.currentNode) == 1 &&
        (componentContext.currentNode as TextNode).text.text.isEmpty &&
        !hasCursor) {
      print(' - this is the 1st paragraph node');
      return TextWithHintComponent(
        documentComponentKey: componentContext.componentKey,
        text: (componentContext.currentNode as TextNode).text,
        styleBuilder: componentContext.extensions[textStylesExtensionKey],
        metadata: (componentContext.currentNode as TextNode).metadata,
        hintText: 'Enter your content...',
        textAlign: textAlign,
        textSelection: textSelection,
        hasCursor: hasCursor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: componentContext.showDebugPaint,
      );
    } else {
      print(
          'Building text component with caret color: ${(componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor}');

      return TextComponent(
        key: componentContext.componentKey,
        text: (componentContext.currentNode as TextNode).text,
        textStyleBuilder: componentContext.extensions[textStylesExtensionKey],
        metadata: (componentContext.currentNode as TextNode).metadata,
        textAlign: textAlign,
        textSelection: textSelection,
        selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
        hasCaret: hasCursor,
        caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
        highlightWhenEmpty: highlightWhenEmpty,
        showDebugPaint: componentContext.showDebugPaint,
      );
    }
  } else if (componentContext.currentNode is ImageNode) {
    final selection =
        componentContext.nodeSelection == null ? null : componentContext.nodeSelection.nodeSelection as BinarySelection;
    final isSelected = selection != null && selection.position.isIncluded;

    return ImageComponent(
      componentKey: componentContext.componentKey,
      imageUrl: (componentContext.currentNode as ImageNode).imageUrl,
      isSelected: isSelected,
      selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    );
  } else if (componentContext.currentNode is ListItemNode &&
      (componentContext.currentNode as ListItemNode).type == ListItemType.unordered) {
    final textSelection =
        componentContext.nodeSelection == null ? null : componentContext.nodeSelection.nodeSelection as TextSelection;
    final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;

    return UnorderedListItemComponent(
      textKey: componentContext.componentKey,
      text: (componentContext.currentNode as ListItemNode).text,
      styleBuilder: componentContext.extensions[textStylesExtensionKey],
      indent: (componentContext.currentNode as ListItemNode).indent,
      textSelection: textSelection,
      selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
      hasCaret: hasCursor,
      caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
      showDebugPaint: componentContext.showDebugPaint,
    );
  } else if (componentContext.currentNode is ListItemNode &&
      (componentContext.currentNode as ListItemNode).type == ListItemType.ordered) {
    int index = 1;
    DocumentNode nodeAbove = componentContext.document.getNodeBefore(componentContext.currentNode);
    while (nodeAbove != null &&
        nodeAbove is ListItemNode &&
        nodeAbove.type == ListItemType.ordered &&
        nodeAbove.indent >= (componentContext.currentNode as ListItemNode).indent) {
      if ((nodeAbove as ListItemNode).indent == (componentContext.currentNode as ListItemNode).indent) {
        index += 1;
      }
      nodeAbove = componentContext.document.getNodeBefore(nodeAbove);
    }

    final textSelection =
        componentContext.nodeSelection == null ? null : componentContext.nodeSelection.nodeSelection as TextSelection;
    final hasCursor = componentContext.nodeSelection != null ? componentContext.nodeSelection.isExtent : false;

    return OrderedListItemComponent(
      textKey: componentContext.componentKey,
      listIndex: index,
      text: (componentContext.currentNode as ListItemNode).text,
      styleBuilder: componentContext.extensions[textStylesExtensionKey],
      textSelection: textSelection,
      selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
      hasCaret: hasCursor,
      caretColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).textCaretColor,
      indent: (componentContext.currentNode as ListItemNode).indent,
      showDebugPaint: componentContext.showDebugPaint,
    );
  } else if (componentContext.currentNode is HorizontalRuleNode) {
    final selection =
        componentContext.nodeSelection == null ? null : componentContext.nodeSelection.nodeSelection as BinarySelection;
    final isSelected = selection != null && selection.position.isIncluded;

    return HorizontalRuleComponent(
      componentKey: componentContext.componentKey,
      isSelected: isSelected,
      selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
    );
  } else {
    return SizedBox(
      key: componentContext.componentKey,
      width: double.infinity,
      height: 100,
      child: Placeholder(),
    );
  }
};

/// Keyboard actions for the standard `Editor`.
final defaultKeyboardActions = <DocumentKeyboardAction>[
  DocumentKeyboardAction.simple(
    action: doNothingWhenThereIsNoSelection,
  ),
  DocumentKeyboardAction.simple(
    action: indentListItemWhenBackspaceIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: unindentListItemWhenBackspaceIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: splitListItemWhenEnterPressed,
  ),
  DocumentKeyboardAction.simple(
    action: pasteWhenCmdVIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: copyWhenCmdVIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: applyBoldWhenCmdBIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: applyItalicsWhenCmdIIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: collapseSelectionWhenDirectionalKeyIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: deleteExpandedSelectionWhenCharacterOrDestructiveKeyPressed,
  ),
  DocumentKeyboardAction.simple(
    action: deleteBoxWhenBackspaceOrDeleteIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: insertCharacterInParagraph,
  ),
  DocumentKeyboardAction.simple(
    action: insertCharacterInTextComposable,
  ),
  DocumentKeyboardAction.simple(
    action: insertNewlineInParagraph,
  ),
  DocumentKeyboardAction.simple(
    action: splitParagraphWhenEnterPressed,
  ),
  DocumentKeyboardAction.simple(
    action: deleteCharacterWhenBackspaceIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: mergeNodeWithPreviousWhenBackspaceIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: deleteEmptyParagraphWhenBackspaceIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: moveParagraphSelectionUpWhenBackspaceIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: deleteCharacterWhenDeleteIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: mergeNodeWithNextWhenDeleteIsPressed,
  ),
  DocumentKeyboardAction.simple(
    action: moveUpDownLeftAndRightWithArrowKeys,
  ),
];
