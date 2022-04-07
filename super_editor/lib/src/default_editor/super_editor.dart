import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/default_editor/list_items.dart';

import 'attributions.dart';
import 'blockquote.dart';
import 'document_gestures_mouse.dart';
import 'document_input_ime.dart';
import 'document_input_keyboard.dart';
import 'document_keyboard_actions.dart';
import 'horizontal_rule.dart';
import 'image.dart';
import 'layout_single_column/layout_single_column.dart';
import 'paragraph.dart';
import 'text.dart';
import 'unknown_component.dart';

/// A rich text editor that displays a document in a single-column layout.
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
///  * [stylesheet], which applies styles throughout the document layout,
///    including text styles and block padding.
///  * [componentStyles], which applies targeted styles to specific components
///    in the document layout.
///  * [componentBuilders], which produce every visual component within the document layout.
///  * [selectionStyles], which dictates the color of the caret and the color of
///    selected text and components
///
/// A [SuperEditor] determines how a physical keyboard interacts with the document
/// by way of [keyboardActions]. Software keyboards are integrated with the
/// [softwareKeyboardHandler].
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
    required this.editor,
    this.composer,
    this.scrollController,
    this.documentLayoutKey,
    Stylesheet? stylesheet,
    this.customStylePhases = const [],
    this.inputSource = DocumentInputSource.keyboard,
    this.gestureMode = DocumentGestureMode.mouse,
    this.androidToolbarBuilder,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.debugPaint = const DebugPaintConfig(),
    this.autofocus = false,
  })  : componentBuilders = defaultComponentBuilders,
        keyboardActions = defaultKeyboardActions,
        softwareKeyboardHandler = null,
        stylesheet = stylesheet ?? defaultStylesheet,
        selectionStyles = defaultSelectionStyle,
        super(key: key);

  @Deprecated("Use unnamed SuperEditor() constructor instead")
  SuperEditor.custom({
    Key? key,
    this.focusNode,
    required this.editor,
    this.composer,
    this.scrollController,
    this.documentLayoutKey,
    Stylesheet? stylesheet,
    this.customStylePhases = const [],
    List<ComponentBuilder>? componentBuilders,
    SelectionStyles? selectionStyle,
    this.inputSource = DocumentInputSource.keyboard,
    this.gestureMode = DocumentGestureMode.mouse,
    List<DocumentKeyboardAction>? keyboardActions,
    this.softwareKeyboardHandler,
    this.androidToolbarBuilder,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.debugPaint = const DebugPaintConfig(),
    this.autofocus = false,
  })  : stylesheet = stylesheet ?? defaultStylesheet,
        selectionStyles = selectionStyle ?? defaultSelectionStyle,
        keyboardActions = keyboardActions ?? defaultKeyboardActions,
        componentBuilders = componentBuilders != null
            ? [...componentBuilders, const UnknownComponentBuilder()]
            : [...defaultComponentBuilders, const UnknownComponentBuilder()],
        super(key: key);

  /// Creates a `Super Editor` with common (but configurable) defaults for
  /// visual components, text styles, and user interaction.
  SuperEditor({
    Key? key,
    this.focusNode,
    required this.editor,
    this.composer,
    this.scrollController,
    this.documentLayoutKey,
    Stylesheet? stylesheet,
    this.customStylePhases = const [],
    List<ComponentBuilder>? componentBuilders,
    SelectionStyles? selectionStyle,
    this.inputSource = DocumentInputSource.keyboard,
    this.gestureMode = DocumentGestureMode.mouse,
    List<DocumentKeyboardAction>? keyboardActions,
    this.androidToolbarBuilder,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.softwareKeyboardHandler,
    this.debugPaint = const DebugPaintConfig(),
    this.autofocus = false,
  })  : stylesheet = stylesheet ?? defaultStylesheet,
        selectionStyles = selectionStyle ?? defaultSelectionStyle,
        keyboardActions = keyboardActions ?? defaultKeyboardActions,
        componentBuilders = componentBuilders != null
            ? [...componentBuilders, const UnknownComponentBuilder()]
            : [...defaultComponentBuilders, const UnknownComponentBuilder()],
        super(key: key);

  /// [FocusNode] for the entire `SuperEditor`.
  final FocusNode? focusNode;

  /// Whether or not the [SuperEditor] should autofocus
  final bool autofocus;

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

  /// Style rules applied through the document presentation.
  final Stylesheet stylesheet;

  /// Styles applied to selected content.
  final SelectionStyles selectionStyles;

  /// Custom style phases that are added to the standard style phases.
  ///
  /// Documents are styled in a series of phases. A number of such
  /// phases are applied, automatically, e.g., text styles, per-component
  /// styles, and content selection styles.
  ///
  /// [customStylePhases] are added after the standard style phases. You can
  /// use custom style phases to apply styles that aren't supported with
  /// [stylesheet]s.
  ///
  /// You can also use them to apply styles to your custom [DocumentNode]
  /// types that aren't supported by Super Editor. For example, Super Editor
  /// doesn't include support for tables within documents, but you could
  /// implement a `TableNode` for that purpose. You may then want to make your
  /// table styleable. To accomplish this, you add a custom style phase that
  /// knows how to interpret and apply table styles for your visual table component.
  final List<SingleColumnLayoutStylePhase> customStylePhases;

  /// The `SuperEditor` input source, e.g., keyboard or Input Method Engine.
  final DocumentInputSource inputSource;

  /// The `SuperEditor` gesture mode, e.g., mouse or touch.
  final DocumentGestureMode? gestureMode;

  /// Builder that creates a floating toolbar when running on Android.
  final WidgetBuilder? androidToolbarBuilder;

  /// Builder that creates a floating toolbar when running on iOS.
  final WidgetBuilder? iOSToolbarBuilder;

  /// Creates a clipper that applies to overlay controls, like drag
  /// handles, magnifiers, and popover toolbars, preventing the overlay
  /// controls from appearing outside the given clipping region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// Contains a [Document] and alters that document as desired.
  final DocumentEditor editor;

  /// Owns the editor's current selection, the current attributions for
  /// text input, and other transitive editor configurations.
  final DocumentComposer? composer;

  /// Priority list of widget factories that create instances of
  /// each visual component displayed in the document layout, e.g.,
  /// paragraph component, image component, horizontal rule component, etc.
  final List<ComponentBuilder> componentBuilders;

  /// All actions that this editor takes in response to key
  /// events, e.g., text entry, newlines, character deletion,
  /// copy, paste, etc.
  ///
  /// These actions are only used when in [DocumentInputSource.keyboard]
  /// mode.
  final List<DocumentKeyboardAction> keyboardActions;

  /// Applies all software keyboard edits to the document.
  ///
  /// This handler is only used when in [DocumentInputSource.ime] mode.
  final SoftwareKeyboardHandler? softwareKeyboardHandler;

  /// Paints some extra visual ornamentation to help with
  /// debugging, when true.
  final DebugPaintConfig debugPaint;

  @override
  _SuperEditorState createState() => _SuperEditorState();
}

class _SuperEditorState extends State<SuperEditor> {
  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;
  SingleColumnLayoutPresenter? _docLayoutPresenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  late FocusNode _focusNode;
  late DocumentComposer _composer;

  DocumentPosition? _previousSelectionExtent;

  late EditContext _editContext;
  late SoftwareKeyboardHandler _softwareKeyboardHandler;
  final _floatingCursorController = FloatingCursorController();

  @override
  void initState() {
    super.initState();

    _composer = widget.composer ?? DocumentComposer();
    _composer.addListener(_updateComposerPreferencesAtSelection);

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _createEditContext();
    _createLayoutPresenter();

    _softwareKeyboardHandler = widget.softwareKeyboardHandler ??
        SoftwareKeyboardHandler(
          editor: _editContext.editor,
          composer: _editContext.composer,
          commonOps: _editContext.commonOps,
        );
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
      _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);
    }
    if (widget.documentLayoutKey != oldWidget.documentLayoutKey) {
      _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();
    }
    if (widget.softwareKeyboardHandler != oldWidget.softwareKeyboardHandler) {
      _softwareKeyboardHandler = widget.softwareKeyboardHandler ??
          SoftwareKeyboardHandler(
            editor: _editContext.editor,
            composer: _editContext.composer,
            commonOps: _editContext.commonOps,
          );
    }

    if (widget.editor != oldWidget.editor) {
      _createEditContext();
      _createLayoutPresenter();
    }

    if (widget.stylesheet != oldWidget.stylesheet) {
      // TODO:
    }

    _recomputeIfLayoutShouldShowCaret();
  }

  @override
  void dispose() {
    if (widget.composer == null) {
      _composer.dispose();
    }

    _focusNode.removeListener(_onFocusChange);
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

  void _createLayoutPresenter() {
    if (_docLayoutPresenter != null) {
      _docLayoutPresenter!.dispose();
    }

    final document = _editContext.editor.document;

    _docStylesheetStyler = SingleColumnStylesheetStyler(stylesheet: widget.stylesheet);

    _docLayoutPerComponentBlockStyler = SingleColumnLayoutCustomComponentStyler();

    _docLayoutSelectionStyler = SingleColumnLayoutSelectionStyler(
      document: document,
      composer: _editContext.composer,
      selectionStyles: widget.selectionStyles,
    );

    _docLayoutPresenter = SingleColumnLayoutPresenter(
      document: document,
      componentBuilders: widget.componentBuilders,
      pipeline: [
        _docStylesheetStyler,
        _docLayoutPerComponentBlockStyler,
        ...widget.customStylePhases,
        // Selection changes are very volatile. Put that phase last
        // to minimize view model recalculations.
        _docLayoutSelectionStyler,
      ],
    );

    _recomputeIfLayoutShouldShowCaret();
  }

  void _onFocusChange() {
    _recomputeIfLayoutShouldShowCaret();
  }

  void _recomputeIfLayoutShouldShowCaret() {
    _docLayoutSelectionStyler.shouldDocumentShowCaret =
        _focusNode.hasFocus && _gestureMode == DocumentGestureMode.mouse;
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

  DocumentGestureMode get _gestureMode {
    if (widget.gestureMode != null) {
      return widget.gestureMode!;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return DocumentGestureMode.android;
      case TargetPlatform.iOS:
        return DocumentGestureMode.iOS;
      default:
        return DocumentGestureMode.mouse;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildInputSystem(
      child: _buildGestureSystem(
        child: SingleColumnDocumentLayout(
          key: _docLayoutKey,
          presenter: _docLayoutPresenter!,
          componentBuilders: widget.componentBuilders,
          showDebugPaint: widget.debugPaint.layout,
        ),
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
          autofocus: widget.autofocus,
          editContext: _editContext,
          keyboardActions: widget.keyboardActions,
          child: child,
        );
      case DocumentInputSource.ime:
        return DocumentImeInteractor(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          editContext: _editContext,
          softwareKeyboardHandler: _softwareKeyboardHandler,
          floatingCursorController: _floatingCursorController,
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
    switch (_gestureMode) {
      case DocumentGestureMode.mouse:
        return DocumentMouseInteractor(
          focusNode: _focusNode,
          editContext: _editContext,
          scrollController: widget.scrollController,
          showDebugPaint: widget.debugPaint.gestures,
          scrollingMinimapId: widget.debugPaint.scrollingMinimapId,
          child: child,
        );
      case DocumentGestureMode.android:
        return AndroidDocumentTouchInteractor(
          focusNode: _focusNode,
          composer: _editContext.composer,
          document: _editContext.editor.document,
          getDocumentLayout: () => _editContext.documentLayout,
          scrollController: widget.scrollController,
          documentKey: _docLayoutKey,
          popoverToolbarBuilder: widget.androidToolbarBuilder ?? (_) => const SizedBox(),
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          showDebugPaint: widget.debugPaint.gestures,
          child: child,
        );
      case DocumentGestureMode.iOS:
        return IOSDocumentTouchInteractor(
          focusNode: _focusNode,
          composer: _editContext.composer,
          document: _editContext.editor.document,
          getDocumentLayout: () => _editContext.documentLayout,
          scrollController: widget.scrollController,
          documentKey: _docLayoutKey,
          popoverToolbarBuilder: widget.iOSToolbarBuilder ?? (_) => const SizedBox(),
          floatingCursorController: _floatingCursorController,
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          showDebugPaint: widget.debugPaint.gestures,
          child: child,
        );
    }
  }
}

enum DocumentInputSource {
  keyboard,
  ime,
}

enum DocumentGestureMode {
  mouse,
  android,
  iOS,
}

/// Configures the aspects of the editor that show debug paint.
class DebugPaintConfig {
  const DebugPaintConfig({
    this.scrolling = false,
    this.gestures = false,
    this.scrollingMinimapId,
    this.layout = false,
  });

  final bool scrolling;
  final bool gestures;
  final String? scrollingMinimapId;
  final bool layout;
}

/// Creates visual components for the standard [SuperEditor].
///
/// These builders are in priority order. The first builder
/// to return a non-null component is used.
final defaultComponentBuilders = <ComponentBuilder>[
  const BlockquoteComponentBuilder(),
  const ParagraphComponentBuilder(),
  const ListItemComponentBuilder(),
  const ImageComponentBuilder(),
  const HorizontalRuleComponentBuilder(),
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

/// Stylesheet applied to all [SuperEditor]s by default.
final defaultStylesheet = Stylesheet(
  rules: [
    StyleRule(
      const BlockSelector.all(),
      (doc, docNode) {
        return {
          "maxWidth": 640.0,
          "padding": const CascadingPadding.symmetric(horizontal: 24),
          "textStyle": const TextStyle(
            color: Colors.black,
            fontSize: 18,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header1"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 40),
          "textStyle": const TextStyle(
            color: Color(0xFF333333),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header2"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 32),
          "textStyle": const TextStyle(
            color: Color(0xFF333333),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("header3"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 28),
          "textStyle": const TextStyle(
            color: Color(0xFF333333),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 24),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header1"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header2"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("paragraph").after("header3"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 0),
        };
      },
    ),
    StyleRule(
      const BlockSelector("listItem"),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(top: 24),
        };
      },
    ),
    StyleRule(
      const BlockSelector.all().last(),
      (doc, docNode) {
        return {
          "padding": const CascadingPadding.only(bottom: 96),
        };
      },
    ),
  ],
  inlineTextStyler: defaultInlineTextStyler,
);

TextStyle defaultInlineTextStyler(Set<Attribution> attributions, TextStyle existingStyle) {
  return existingStyle.merge(defaultStyleBuilder(attributions));
}

/// Creates [TextStyles] for the standard [SuperEditor].
TextStyle defaultStyleBuilder(Set<Attribution> attributions) {
  TextStyle newStyle = const TextStyle();

  for (final attribution in attributions) {
    if (attribution == boldAttribution) {
      newStyle = newStyle.copyWith(
        fontWeight: FontWeight.bold,
      );
    } else if (attribution == italicsAttribution) {
      newStyle = newStyle.copyWith(
        fontStyle: FontStyle.italic,
      );
    } else if (attribution == underlineAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.underline
            : TextDecoration.combine([TextDecoration.underline, newStyle.decoration!]),
      );
    } else if (attribution == strikethroughAttribution) {
      newStyle = newStyle.copyWith(
        decoration: newStyle.decoration == null
            ? TextDecoration.lineThrough
            : TextDecoration.combine([TextDecoration.lineThrough, newStyle.decoration!]),
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

/// Default visual styles related to content selection.
const defaultSelectionStyle = SelectionStyles(
  caretColor: Colors.black,
  selectionColor: Color(0xFFACCEF7),
);
