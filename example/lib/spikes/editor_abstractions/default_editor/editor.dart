import 'package:example/spikes/editor_abstractions/core/attributed_text.dart';
import 'package:example/spikes/editor_abstractions/core/edit_context.dart';
import 'package:example/spikes/editor_abstractions/default_editor/box_component.dart';
import 'package:example/spikes/editor_abstractions/default_editor/document_interaction.dart';
import 'package:example/spikes/editor_abstractions/default_editor/unknown_component.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/rendering.dart';

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
import 'styles.dart';

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
/// An `Editor` determines the visual styling by way of:
///  * `componentBuilders`, which produce individual components
///     within the document layout
///  * `textStyleBuilder`, which vends `TextStyle`s for every
///     combination of text attributions
///  * `selectionStyle`, which dictates the color of the caret
///     and the color of selected text and components
///
/// An `Editor` determines how the keyboard interacts with the
/// document by way of `keyboardActions`.
///
/// All styling artifacts and `keyboardActions` are configurable
/// via the `Editor.custom` constructor.
///
/// ## Deeper explanation of core artifacts:
///
/// The document model is responsible for holding the content of a
/// document in a structured and query-able manner.
///
/// The document editor is responsible for mutating the document
/// structure.
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
/// selection and the current text entry mode.
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
      componentBuilders: defaultComponentBuilders,
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
    List<ComponentBuilder> componentBuilders,
    ScrollController scrollController,
    bool showDebugPaint = false,
  }) {
    return Editor._(
      key: key,
      document: document,
      editor: editor,
      composer: composer,
      componentBuilders: componentBuilders ?? defaultComponentBuilders,
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
    @required this.componentBuilders,
    @required this.textStyleBuilder,
    @required this.selectionStyle,
    @required this.keyboardActions,
    this.scrollController,
    this.showDebugPaint = false,
  })  : assert(document != null),
        assert(editor != null),
        assert(composer != null),
        assert(componentBuilders != null),
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

  /// Priority list of widget factories that creates instances of
  /// each visual component displayed in the document layout, e.g.,
  /// paragraph component, image component,
  /// horizontal rule component, etc.
  final List<ComponentBuilder> componentBuilders;

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
                componentBuilders: widget.componentBuilders,
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

/// Default visual styles related to content selection.
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
///
/// These builders are in priority order. The first builder
/// to return a non-null component is used. The final
/// `unknownComponentBuilder` always returns a component.
final defaultComponentBuilders = <ComponentBuilder>[
  titleHintBuilder,
  firstParagraphHintBuilder,
  paragraphBuilder,
  unorderedListItemBuilder,
  orderedListItemBuilder,
  imageBuilder,
  horizontalRuleBuilder,
  unknownComponentBuilder,
];

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
