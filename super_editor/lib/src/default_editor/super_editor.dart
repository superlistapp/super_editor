import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide SelectableText;
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_debug_paint.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_interaction.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/common_editor_operations.dart';
import 'package:super_editor/src/default_editor/debug_visualization.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/default_editor/document_scrollable.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/tasks.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/ios_document_controls.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../infrastructure/platforms/mobile_documents.dart';
import 'attributions.dart';
import 'blockquote.dart';
import 'document_caret_overlay.dart';
import 'document_gestures_mouse.dart';
import 'document_ime/document_input_ime.dart';
import 'document_hardware_keyboard/document_input_keyboard.dart';
import 'document_focus_and_selection_policies.dart';
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
/// by way of [keyboardActions].
///
/// A [SuperEditor] works with software keyboards through the platform's Input Method
/// Engine (IME). To customize how [SuperEditor] works with the IME, see [imePolicies],
/// [imeConfiguration], and [softwareKeyboardController].
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
    this.selectionPolicies = const SuperEditorSelectionPolicies(),
    this.inputSource,
    this.softwareKeyboardController,
    this.imePolicies = const SuperEditorImePolicies(),
    this.imeConfiguration = const SuperEditorImeConfiguration(),
    this.imeOverrides,
    List<DocumentKeyboardAction>? keyboardActions,
    this.gestureMode,
    this.androidHandleColor,
    this.androidToolbarBuilder,
    this.iOSHandleColor,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.documentOverlayBuilders = const [DefaultCaretOverlayBuilder()],
    this.debugPaint = const DebugPaintConfig(),
    this.autofocus = false,
    this.overlayController,
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

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

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

  /// Policies that determine how selection is modified by other factors, such as
  /// gaining or losing focus.
  final SuperEditorSelectionPolicies selectionPolicies;

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
  final TextInputSource? inputSource;

  /// Opens and closes the software keyboard.
  ///
  /// Typically, this controller should only be used when the keyboard is configured
  /// for manual control, e.g., [SuperEditorImePolicies.openKeyboardOnSelectionChange] and
  /// [SuperEditorImePolicies.clearSelectionWhenEditorLosesFocus] are `false`. Otherwise,
  /// the automatic behavior might conflict with commands to this controller.
  final SoftwareKeyboardController? softwareKeyboardController;

  /// Policies that dictate when and how [SuperEditor] should interact with the
  /// platform IME, such as automatically opening the software keyboard when
  /// [SuperEditor]'s selection changes.
  final SuperEditorImePolicies imePolicies;

  /// Preferences for how the platform IME should look and behave during editing.
  final SuperEditorImeConfiguration imeConfiguration;

  /// Overrides for IME actions.
  ///
  /// When the user edits document content in IME mode, those edits and actions
  /// are reported to a [DeltaTextInputClient], which is then responsible for
  /// applying those changes to a document. [SuperEditor] includes an implementation
  /// for all relevant editing behaviors. However, some apps may wish to implement
  /// their own custom behavior, such as when the user presses the action button,
  /// such as "Next" or "Done".
  ///
  /// Provide a [DeltaTextInputClientDecorator], to override the default [SuperEditor]
  /// behaviors for various IME messages.
  final DeltaTextInputClientDecorator? imeOverrides;

  /// The `SuperEditor` gesture mode, e.g., mouse or touch.
  final DocumentGestureMode? gestureMode;

  /// Color of the text selection drag handles on Android.
  final Color? androidHandleColor;

  /// Builder that creates a floating toolbar when running on Android.
  final WidgetBuilder? androidToolbarBuilder;

  /// Color of the text selection drag handles on iOS.
  final Color? iOSHandleColor;

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

  /// Layers that are displayed on top of the document layout, aligned
  /// with the location and size of the document layout.
  final List<DocumentLayerBuilder> documentOverlayBuilders;

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
  /// These actions are only used when in [TextInputSource.keyboard]
  /// mode.
  final List<DocumentKeyboardAction> keyboardActions;

  /// Paints some extra visual ornamentation to help with
  /// debugging.
  final DebugPaintConfig debugPaint;

  @override
  SuperEditorState createState() => SuperEditorState();
}

@visibleForTesting
class SuperEditorState extends State<SuperEditor> {
  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;
  SingleColumnLayoutPresenter? _docLayoutPresenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  late FocusNode _focusNode;
  @visibleForTesting
  FocusNode get focusNode => _focusNode;

  late DocumentComposer _composer;

  late AutoScrollController _autoScrollController;
  DocumentPosition? _previousSelectionExtent;

  @visibleForTesting
  late EditContext editContext;

  final _floatingCursorController = FloatingCursorController();

  @visibleForTesting
  SingleColumnLayoutPresenter get presenter => _docLayoutPresenter!;

  @override
  void initState() {
    super.initState();

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    _composer = widget.composer ?? DocumentComposer();
    _composer.addListener(_updateComposerPreferencesAtSelection);

    _autoScrollController = AutoScrollController();

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _createEditContext();
    _createLayoutPresenter();
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

    if (widget.editor != oldWidget.editor) {
      _createEditContext();
      _createLayoutPresenter();
    } else if (widget.selectionStyles != oldWidget.selectionStyles) {
      _docLayoutSelectionStyler.selectionStyles = widget.selectionStyles;
    }

    if (widget.stylesheet != oldWidget.stylesheet) {
      _docStylesheetStyler.stylesheet = widget.stylesheet;
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
    editContext = EditContext(
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

    final document = editContext.editor.document;

    _docStylesheetStyler = SingleColumnStylesheetStyler(stylesheet: widget.stylesheet);

    _docLayoutPerComponentBlockStyler = SingleColumnLayoutCustomComponentStyler();

    _docLayoutSelectionStyler = SingleColumnLayoutSelectionStyler(
      document: document,
      selection: editContext.composer.selectionNotifier,
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
    _docLayoutSelectionStyler.shouldDocumentShowCaret = _focusNode.hasFocus && gestureMode == DocumentGestureMode.mouse;
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
      // attributions immediately following it (except links).
      // TODO: attribution expansion policy should probably be configurable
      final allStyles = node.text
          .getAllAttributionsAt(textPosition.offset + 1)
          .where((attribution) => attribution is! LinkAttribution)
          .toSet();
      _composer.preferences.addStyles(allStyles);
    } else {
      // Inserted text assumes the attributions immediately preceding it
      // (except links).
      // TODO: attribution expansion policy should probably be configurable
      final allStyles = node.text
          .getAllAttributionsAt(textPosition.offset - 1)
          .where((attribution) => attribution is! LinkAttribution)
          .toSet();
      _composer.preferences.addStyles(allStyles);
    }
  }

  @visibleForTesting
  DocumentGestureMode get gestureMode {
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

  /// Returns the [TextInputSource] which should be used.
  ///
  /// If the `inputSource` is configured, it is used. Otherwise,
  /// the [TextInputSource] is chosen based on the platform.
  @visibleForTesting
  TextInputSource get inputSource {
    if (widget.inputSource != null) {
      return widget.inputSource!;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return TextInputSource.ime;
      default:
        return TextInputSource.keyboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditorFocusDebugVisuals(
      focusNode: _focusNode,
      child: EditorSelectionAndFocusPolicy(
        focusNode: _focusNode,
        selection: _composer.selectionNotifier,
        getDocumentLayout: () => editContext.documentLayout,
        placeCaretAtEndOfDocumentOnGainFocus: widget.selectionPolicies.placeCaretAtEndOfDocumentOnGainFocus,
        restorePreviousSelectionOnGainFocus: widget.selectionPolicies.restorePreviousSelectionOnGainFocus,
        clearSelectionWhenEditorLosesFocus: widget.selectionPolicies.clearSelectionWhenEditorLosesFocus,
        child: _buildInputSystem(
          child: _buildGestureSystem(
            documentLayout: SingleColumnDocumentLayout(
              key: _docLayoutKey,
              presenter: _docLayoutPresenter!,
              componentBuilders: widget.componentBuilders,
              showDebugPaint: widget.debugPaint.layout,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the widget tree that applies user input, e.g., key
  /// presses from a keyboard, or text deltas from the IME.
  Widget _buildInputSystem({
    required Widget child,
  }) {
    switch (inputSource) {
      case TextInputSource.keyboard:
        return SuperEditorHardwareKeyHandler(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          editContext: editContext,
          keyboardActions: widget.keyboardActions,
          child: child,
        );
      case TextInputSource.ime:
        return SuperEditorImeInteractor(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          editContext: editContext,
          clearSelectionWhenImeConnectionCloses: widget.selectionPolicies.clearSelectionWhenImeConnectionCloses,
          softwareKeyboardController: widget.softwareKeyboardController,
          imePolicies: widget.imePolicies,
          imeConfiguration: widget.imeConfiguration,
          imeOverrides: widget.imeOverrides,
          hardwareKeyboardActions: widget.keyboardActions,
          floatingCursorController: _floatingCursorController,
          child: child,
        );
    }
  }

  /// Builds the widget tree that handles user gesture interaction
  /// with the document, e.g., mouse input on desktop, or touch input
  /// on mobile.
  Widget _buildGestureSystem({
    required Widget documentLayout,
  }) {
    switch (gestureMode) {
      case DocumentGestureMode.mouse:
        return _buildDesktopGestureSystem(documentLayout);
      case DocumentGestureMode.android:
        return AndroidDocumentTouchInteractor(
          focusNode: _focusNode,
          document: editContext.editor.document,
          getDocumentLayout: () => editContext.documentLayout,
          selection: editContext.composer.selectionNotifier,
          scrollController: widget.scrollController,
          documentKey: _docLayoutKey,
          handleColor: widget.androidHandleColor ?? Theme.of(context).primaryColor,
          popoverToolbarBuilder: widget.androidToolbarBuilder ?? (_) => const SizedBox(),
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          overlayController: widget.overlayController,
          showDebugPaint: widget.debugPaint.gestures,
          child: documentLayout,
        );
      case DocumentGestureMode.iOS:
        return IOSDocumentTouchInteractor(
          focusNode: _focusNode,
          document: editContext.editor.document,
          getDocumentLayout: () => editContext.documentLayout,
          selection: editContext.composer.selectionNotifier,
          scrollController: widget.scrollController,
          documentKey: _docLayoutKey,
          handleColor: widget.iOSHandleColor ?? Theme.of(context).primaryColor,
          popoverToolbarBuilder: widget.iOSToolbarBuilder ?? (_) => const SizedBox(),
          floatingCursorController: _floatingCursorController,
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          overlayController: widget.overlayController,
          showDebugPaint: widget.debugPaint.gestures,
          child: documentLayout,
        );
    }
  }

  Widget _buildDesktopGestureSystem(Widget documentLayout) {
    return LayoutBuilder(builder: (context, viewportConstraints) {
      return DocumentScrollable(
        autoScroller: _autoScrollController,
        scrollController: widget.scrollController,
        scrollingMinimapId: widget.debugPaint.scrollingMinimapId,
        showDebugPaint: widget.debugPaint.scrolling,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // When SuperEditor installs its own Viewport, we want the gesture
            // detection to span throughout the Viewport. Because the gesture
            // system sits around the DocumentLayout, within the Viewport, we
            // have to explicitly tell the gesture area to be at least as tall
            // as the viewport (in case the document content is shorter than
            // the viewport).
            minWidth: viewportConstraints.maxWidth < double.infinity ? viewportConstraints.maxWidth : 0,
            minHeight: viewportConstraints.maxHeight < double.infinity ? viewportConstraints.maxHeight : 0,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // A layer that sits beneath the document and handles gestures.
              // It's beneath the document so that components that include
              // interactive UI, like a Checkbox, can intercept their own
              // touch events.
              Positioned.fill(
                child: DocumentMouseInteractor(
                  focusNode: _focusNode,
                  document: editContext.editor.document,
                  getDocumentLayout: () => editContext.documentLayout,
                  selectionChanges: editContext.composer.selectionChanges,
                  selectionNotifier: editContext.composer.selectionNotifier,
                  autoScroller: _autoScrollController,
                  showDebugPaint: widget.debugPaint.gestures,
                  child: const SizedBox(),
                ),
              ),
              // The document that the user is editing.
              Align(
                alignment: Alignment.topCenter,
                child: Stack(
                  children: [
                    documentLayout,
                    // We display overlay builders in this inner-Stack so that they
                    // match the document size, rather than the viewport size.
                    for (final overlayBuilder in widget.documentOverlayBuilders)
                      Positioned.fill(
                        child: overlayBuilder.build(context, editContext),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// A collection of policies that dictate how a [SuperEditor]'s selection will change
/// based on other behaviors, such as focus changes.
class SuperEditorSelectionPolicies {
  const SuperEditorSelectionPolicies({
    this.placeCaretAtEndOfDocumentOnGainFocus = true,
    this.restorePreviousSelectionOnGainFocus = true,
    this.clearSelectionWhenEditorLosesFocus = true,
    this.clearSelectionWhenImeConnectionCloses = true,
  });

  /// Whether the editor should automatically place the caret at the end of the document,
  /// if the editor receives focus without an existing selection.
  ///
  /// [restorePreviousSelectionOnGainFocus] takes priority over this policy.
  final bool placeCaretAtEndOfDocumentOnGainFocus;

  /// Whether the editor's previous selection should be restored when the editor re-gains
  /// focus, after having previous lost focus.
  final bool restorePreviousSelectionOnGainFocus;

  /// Whether the editor's selection should be removed when the editor loses
  /// all focus (not just primary focus).
  ///
  /// If `true`, when focus moves to a different subtree, such as a popup text
  /// field, or a button somewhere else on the screen, the editor will remove
  /// its selection. When focus returns to the editor, the previous selection can
  /// be restored, but that's controlled by other policies.
  ///
  /// If `false`, the editor will retain its selection, including a visual caret
  /// and selected content, even when the editor doesn't have any focus, and can't
  /// process any input.
  final bool clearSelectionWhenEditorLosesFocus;

  /// Whether the editor's selection should be removed when the editor closes or loses
  /// its IME connection.
  ///
  /// Defaults to `true`.
  ///
  /// Apps that include a custom input mode, such as an editing panel that sometimes
  /// replaces the software keyboard, should set this to `false` and instead control the
  /// IME connection manually.
  final bool clearSelectionWhenImeConnectionCloses;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuperEditorSelectionPolicies &&
          runtimeType == other.runtimeType &&
          placeCaretAtEndOfDocumentOnGainFocus == other.placeCaretAtEndOfDocumentOnGainFocus &&
          restorePreviousSelectionOnGainFocus == other.restorePreviousSelectionOnGainFocus &&
          clearSelectionWhenEditorLosesFocus == other.clearSelectionWhenEditorLosesFocus &&
          clearSelectionWhenImeConnectionCloses == other.clearSelectionWhenImeConnectionCloses;

  @override
  int get hashCode =>
      placeCaretAtEndOfDocumentOnGainFocus.hashCode ^
      restorePreviousSelectionOnGainFocus.hashCode ^
      clearSelectionWhenEditorLosesFocus.hashCode ^
      clearSelectionWhenImeConnectionCloses.hashCode;
}

/// Builds widgets that are displayed at the same position and size as
/// the document layout within a [SuperEditor].
abstract class DocumentLayerBuilder {
  Widget build(BuildContext context, EditContext editContext);
}

/// A [DocumentLayerBuilder] that's implemented with a given function, so
/// that simple use-cases don't need to sub-class [DocumentLayerBuilder].
class FunctionalDocumentLayerBuilder implements DocumentLayerBuilder {
  const FunctionalDocumentLayerBuilder(this._delegate);

  final Widget Function(BuildContext context, EditContext editContext) _delegate;

  @override
  Widget build(BuildContext context, EditContext editContext) => _delegate(context, editContext);
}

/// A [DocumentLayerBuilder] that paints a caret at the primary selection extent
/// in a [SuperEditor].
class DefaultCaretOverlayBuilder implements DocumentLayerBuilder {
  const DefaultCaretOverlayBuilder([
    this.caretStyle = const CaretStyle(
      width: 2,
      color: Colors.black,
    ),
  ]);

  /// Styles applied to the caret that's painted by this caret overlay.
  final CaretStyle caretStyle;

  @override
  Widget build(BuildContext context, EditContext editContext) {
    return CaretDocumentOverlay(
      composer: editContext.composer,
      documentLayoutResolver: () => editContext.documentLayout,
      caretStyle: caretStyle,
      document: editContext.editor.document,
    );
  }
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
  collapseSelectionWhenEscIsPressed,
  selectAllWhenCmdAIsPressed,
  moveUpDownLeftAndRightWithArrowKeys,
  moveToLineStartWithHome,
  moveToLineEndWithEnd,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  backspaceToUnIndentListItem,
  backspaceToClearParagraphBlockType,
  cmdBToToggleBold,
  cmdIToToggleItalics,
  shiftEnterToInsertNewlineInBlock,
  enterToInsertNewTask,
  enterToInsertBlockNewline,
  backspaceToRemoveUpstreamContent,
  deleteToRemoveDownstreamContent,
  moveToLineStartOrEndWithCtrlAOrE,
  deleteLineWithCmdBksp,
  deleteWordWithAltBksp,
  anyCharacterOrDestructiveKeyToDeleteSelection,
  anyCharacterToInsertInParagraph,
  anyCharacterToInsertInTextContent,
];

/// Keyboard actions for a [SuperEditor] running with IME on
/// desktop.
///
/// Using the IME on desktop involves partial input from the IME
/// and partial input from non-content keys, like arrow keys.
final defaultImeKeyboardActions = <DocumentKeyboardAction>[
  doNothingWhenThereIsNoSelection,
  pasteWhenCmdVIsPressed,
  copyWhenCmdCIsPressed,
  cutWhenCmdXIsPressed,
  selectAllWhenCmdAIsPressed,
  moveUpDownLeftAndRightWithArrowKeys,
  moveToLineStartWithHome,
  moveToLineEndWithEnd,
  enterToInsertNewTask,
  enterToInsertBlockNewline,
  tabToIndentListItem,
  shiftTabToUnIndentListItem,
  backspaceToUnIndentListItem,
  backspaceToClearParagraphBlockType,
  cmdBToToggleBold,
  cmdIToToggleItalics,
  shiftEnterToInsertNewlineInBlock,
  backspaceToRemoveUpstreamContent,
  deleteToRemoveDownstreamContent,
];

/// Stylesheet applied to all [SuperEditor]s by default.
final defaultStylesheet = Stylesheet(
  rules: [
    StyleRule(
      BlockSelector.all,
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
      const BlockSelector("blockquote"),
      (doc, docNode) {
        return {
          "textStyle": const TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.last(),
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
  selectionColor: Color(0xFFACCEF7),
);
