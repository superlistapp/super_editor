import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';

import 'document_gestures_mouse.dart';
import 'document_gestures_touch.dart';
import 'document_input_ime.dart';
import 'document_input_keyboard.dart';
import 'document_keyboard_actions.dart';
import 'layout.dart';
import 'paragraph.dart';
import 'styles.dart';
import 'text.dart';
import 'unknown_component.dart';

/// A text editor for styled text and multi-media elements.
///
/// A [SuperEditor] brings together the key pieces needed
/// to display a user-editable document:
///  * document model
///  * document editor
///  * document layout
///  * document interaction (tapping, dragging, typing, scrolling)
///  * document composer (current selection, and styles to apply to next character)
///
/// A [SuperEditor] determines the visual styling by way of:
///  * [componentBuilders], which produce individual components
///     within the document layout
///  * [textStyleBuilder], which vends [TextStyle]s for every
///     combination of text attributions
///  * [selectionStyle], which dictates the color of the caret
///     and the color of selected text and components
///
/// A [SuperEditor] determines how the keyboard interacts with the
/// document by way of [keyboardActions].
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
/// Document composer is responsible for owning document selection and
/// the current text entry mode.
class SuperEditor extends StatefulWidget {
  @Deprecated("Use unnamed SuperEditor() constructor instead")
  SuperEditor.standard({
    Key? key,
    this.focusNode,
    this.scrollController,
    this.padding = EdgeInsets.zero,
    this.documentLayoutKey,
    this.maxWidth = 600,
    this.inputSource = DocumentInputSource.keyboard,
    this.gestureMode = DocumentGestureMode.mouse,
    required this.editor,
    this.composer,
    this.componentVerticalSpacing = 16,
    this.showDebugPaint = false,
  })  : componentBuilders = defaultComponentBuilders,
        keyboardActions = defaultKeyboardActions,
        textStyleBuilder = defaultStyleBuilder,
        selectionStyle = defaultSelectionStyle,
        super(key: key);

  @Deprecated("Use unnamed SuperEditor() constructor instead")
  SuperEditor.custom({
    Key? key,
    this.focusNode,
    this.padding = EdgeInsets.zero,
    this.scrollController,
    this.documentLayoutKey,
    this.maxWidth = 600,
    this.inputSource = DocumentInputSource.keyboard,
    this.gestureMode = DocumentGestureMode.mouse,
    required this.editor,
    this.composer,
    AttributionStyleBuilder? textStyleBuilder,
    SelectionStyle? selectionStyle,
    List<DocumentKeyboardAction>? keyboardActions,
    List<ComponentBuilder>? componentBuilders,
    this.componentVerticalSpacing = 16,
    this.showDebugPaint = false,
  })  : textStyleBuilder = textStyleBuilder ?? defaultStyleBuilder,
        selectionStyle = selectionStyle ?? defaultSelectionStyle,
        keyboardActions = keyboardActions ?? defaultKeyboardActions,
        componentBuilders = componentBuilders ?? defaultComponentBuilders,
        super(key: key);

  /// Creates a `Super Editor` with common (but configurable) defaults for
  /// visual components, text styles, and user interaction.
  SuperEditor({
    Key? key,
    this.focusNode,
    this.padding = EdgeInsets.zero,
    this.scrollController,
    this.documentLayoutKey,
    this.maxWidth = 600,
    this.inputSource = DocumentInputSource.keyboard,
    this.gestureMode = DocumentGestureMode.mouse,
    required this.editor,
    this.composer,
    AttributionStyleBuilder? textStyleBuilder,
    SelectionStyle? selectionStyle,
    List<DocumentKeyboardAction>? keyboardActions,
    List<ComponentBuilder>? componentBuilders,
    this.componentVerticalSpacing = 16,
    this.showDebugPaint = false,
  })  : textStyleBuilder = textStyleBuilder ?? defaultStyleBuilder,
        selectionStyle = selectionStyle ?? defaultSelectionStyle,
        keyboardActions = keyboardActions ?? defaultKeyboardActions,
        componentBuilders = componentBuilders ?? defaultComponentBuilders,
        super(key: key);

  /// [FocusNode] for the entire `SuperEditor`.
  final FocusNode? focusNode;

  /// Padding between the boundary of this `SuperEditor` and its
  /// document content, i.e., insets the content of this document
  /// by the given amount.
  final EdgeInsetsGeometry padding;

  /// The [ScrollController] that governs this `SuperEditor`'s scroll
  /// offset.
  ///
  /// `scrollController` is not used if this `SuperEditor` has an ancestor
  /// `Scrollable`.
  final ScrollController? scrollController;

  /// [GlobalKey] that's bound to the [DocumentLayout] within
  /// this `SuperEditor`.
  ///
  /// This key can be used to lookup visual components in the document
  /// layout within this `SuperEditor`.
  final GlobalKey? documentLayoutKey;

  /// The maximum width for document content within this `SuperEditor`.
  final double maxWidth;

  /// The `SuperEditor` input source, e.g., keyboard or Input Method Engine.
  final DocumentInputSource inputSource;

  /// The `SuperEditor` gesture mode, e.g., mouse or touch.
  final DocumentGestureMode gestureMode;

  /// Contains a [Document] and alters that document as desired.
  final DocumentEditor editor;

  /// Owns the editor's current selection, the current attributions for
  /// text input, and other transitive editor configurations.
  final DocumentComposer? composer;

  /// Priority list of widget factories that creates instances of
  /// each visual component displayed in the document layout, e.g.,
  /// paragraph component, image component,
  /// horizontal rule component, etc.
  final List<ComponentBuilder> componentBuilders;

  /// Factory that creates [TextStyle]s based on given
  /// attributions. An attribution can be anything. It is up
  /// to the [textStyleBuilder] to interpret attributions
  /// as desired to produce corresponding styles.
  final AttributionStyleBuilder textStyleBuilder;

  /// Styles to be applied to selected text.
  final SelectionStyle selectionStyle;

  /// All actions that this editor takes in response to key
  /// events, e.g., text entry, newlines, character deletion,
  /// copy, paste, etc.
  final List<DocumentKeyboardAction> keyboardActions;

  /// The vertical distance between visual components in the document layout.
  final double componentVerticalSpacing;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when true.
  final bool showDebugPaint;

  @override
  _SuperEditorState createState() => _SuperEditorState();
}

class _SuperEditorState extends State<SuperEditor> {
  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;

  late FocusNode _focusNode;
  late DocumentComposer _composer;

  DocumentPosition? _previousSelectionExtent;

  late EditContext _editContext;

  @override
  void initState() {
    super.initState();

    _composer = widget.composer ?? DocumentComposer();
    _composer.addListener(_updateComposerPreferencesAtSelection);

    _focusNode = widget.focusNode ?? FocusNode();

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _createEditContext();
  }

  @override
  void didUpdateWidget(SuperEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.composer != oldWidget.composer) {
      _composer.removeListener(_updateComposerPreferencesAtSelection);

      _composer = widget.composer ?? DocumentComposer();
      _composer.addListener(_updateComposerPreferencesAtSelection);
    }
    if (widget.editor != oldWidget.editor) {
      // The content displayed in this Editor was switched
      // out. Remove any content selection from the previous
      // document.
      _composer.selection = null;
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode = widget.focusNode ?? FocusNode();
    }
    if (widget.documentLayoutKey != oldWidget.documentLayoutKey) {
      _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();
    }

    _createEditContext();
  }

  @override
  void dispose() {
    if (widget.composer == null) {
      _composer.dispose();
    }

    if (widget.focusNode == null) {
      // We are using our own private FocusNode. Dispose it.
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _createEditContext() {
    _editContext = EditContext(
      editor: widget.editor,
      composer: _composer,
      getDocumentLayout: () => _docLayoutKey.currentState as DocumentLayout,
      commonOps: CommonEditorOperations(
        editor: widget.editor,
        composer: _composer,
        documentLayoutResolver: () => _docLayoutKey.currentState as DocumentLayout,
      ),
    );
  }

  void _updateComposerPreferencesAtSelection() {
    if (_composer.selection?.extent == _previousSelectionExtent) {
      return;
    }
    _previousSelectionExtent = _composer.selection?.extent;

    _composer.preferences.clearStyles();

    if (_composer.selection == null || !_composer.selection!.isCollapsed) {
      return;
    }

    final node = widget.editor.document.getNodeById(_composer.selection!.extent.nodeId);
    if (node is! TextNode) {
      return;
    }

    final textPosition = _composer.selection!.extent.nodePosition as TextPosition;

    if (textPosition.offset == 0) {
      if (node.text.text.isEmpty) {
        return;
      }

      // Inserted text at the very beginning of a text blob assumes the
      // attributions immediately following it.
      final allStyles = node.text.getAllAttributionsAt(textPosition.offset + 1);
      _composer.preferences.addStyles(allStyles);
    } else {
      // Inserted text assumes the attributions immediately preceding it.
      final allStyles = node.text.getAllAttributionsAt(textPosition.offset - 1);
      _composer.preferences.addStyles(allStyles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildInputSystem(
      child: _buildGestureSystem(
        child: _buildDocumentLayout(),
      ),
    );
  }

  /// Builds the widget tree that applies user input, e.g., key
  /// presses from a keyboard, or text deltas from the IME.
  Widget _buildInputSystem({
    required Widget child,
  }) {
    switch (widget.inputSource) {
      case DocumentInputSource.keyboard:
        return DocumentKeyboardInteractor(
          focusNode: _focusNode,
          editContext: _editContext,
          keyboardActions: widget.keyboardActions,
          child: child,
        );
      case DocumentInputSource.ime:
        return DocumentImeInteractor(
          focusNode: _focusNode,
          editContext: _editContext,
          child: child,
        );
    }
  }

  /// Builds the widget tree that handles user gesture interaction
  /// with the document, e.g., mouse input on desktop, or touch input
  /// on mobile.
  Widget _buildGestureSystem({
    required Widget child,
  }) {
    switch (widget.gestureMode) {
      case DocumentGestureMode.mouse:
        return DocumentMouseInteractor(
          focusNode: _focusNode,
          editContext: _editContext,
          scrollController: widget.scrollController,
          showDebugPaint: widget.showDebugPaint,
          child: child,
        );
      case DocumentGestureMode.touch:
        return DocumentTouchInteractor(
          focusNode: _focusNode,
          editContext: _editContext,
          scrollController: widget.scrollController,
          documentKey: _docLayoutKey,
          showDebugPaint: widget.showDebugPaint,
          child: child,
        );
    }
  }

  /// Builds the `DocumentLayout` with a constrained width, and a builder
  /// that re-runs when various artifacts change, e.g., the document changes.
  Widget _buildDocumentLayout() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
      ),
      child: MultiListenableBuilder(
        listenables: {
          _focusNode,
          _composer,
          widget.editor.document,
        },
        builder: (context) {
          return DefaultDocumentLayout(
            key: _docLayoutKey,
            document: widget.editor.document,
            documentSelection: _composer.selection,
            componentBuilders: widget.componentBuilders,
            showCaret: _focusNode.hasFocus,
            margin: widget.padding,
            componentVerticalSpacing: widget.componentVerticalSpacing,
            extensions: {
              textStylesExtensionKey: widget.textStyleBuilder,
              selectionStylesExtensionKey: widget.selectionStyle,
            },
            showDebugPaint: widget.showDebugPaint,
          );
        },
      ),
    );
  }
}

enum DocumentInputSource {
  keyboard,
  ime,
}

enum DocumentGestureMode {
  mouse,
  touch,
}

/// Default visual styles related to content selection.
const defaultSelectionStyle = SelectionStyle(
  textCaretColor: Colors.black,
  selectionColor: Color(0xFFACCEF7),
);

/// Creates [TextStyles] for the standard [SuperEditor].
TextStyle defaultStyleBuilder(Set<Attribution> attributions) {
  print('Building styles for attributions: $attributions');
  TextStyle newStyle = const TextStyle(
    color: Colors.black,
    fontSize: 13,
    height: 1.4,
  );

  for (final attribution in attributions) {
    if (attribution == header1Attribution) {
      newStyle = newStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.0,
      );
    } else if (attribution == header2Attribution) {
      newStyle = newStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF888888),
        height: 1.0,
      );
    } else if (attribution == blockquoteAttribution) {
      newStyle = newStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: Colors.grey,
      );
    } else if (attribution == boldAttribution) {
      newStyle = newStyle.copyWith(
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == italicsAttribution) {
      newStyle = newStyle.copyWith(
        fontStyle: FontStyle.italic,
      );
    } else if (attribution == strikethroughAttribution) {
      newStyle = newStyle.copyWith(
        decoration: TextDecoration.lineThrough,
      );
    } else if (attribution is LinkAttribution) {
      newStyle = newStyle.copyWith(
        color: Colors.lightBlue,
        decoration: TextDecoration.underline,
      );
    }
  }
  return newStyle;
}

/// Creates visual components for the standard [SuperEditor].
///
/// These builders are in priority order. The first builder
/// to return a non-null component is used. The final
/// `unknownComponentBuilder` always returns a component.
final defaultComponentBuilders = <ComponentBuilder>[
  paragraphBuilder,
  unorderedListItemBuilder,
  orderedListItemBuilder,
  blockquoteBuilder,
  imageBuilder,
  horizontalRuleBuilder,
  unknownComponentBuilder,
];

/// Keyboard actions for the standard [SuperEditor].
final defaultKeyboardActions = <DocumentKeyboardAction>[
  doNothingWhenThereIsNoSelection,
  pasteWhenCmdVIsPressed,
  copyWhenCmdCIsPressed,
  cutWhenCmdXIsPressed,
  selectAllWhenCmdAIsPressed,
  moveUpDownLeftAndRightWithArrowKeys,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  backspaceToUnIndentListItem,
  backspaceToClearParagraphBlockType,
  cmdBToToggleBold,
  cmdIToToggleItalics,
  shiftEnterToInsertNewlineInBlock,
  enterToInsertBlockNewline,
  backspaceToRemoveUpstreamContent,
  deleteToRemoveDownstreamContent,
  anyCharacterOrDestructiveKeyToDeleteSelection,
  anyCharacterToInsertInParagraph,
  anyCharacterToInsertInTextContent,
];
