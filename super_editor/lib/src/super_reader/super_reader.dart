import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_debug_paint.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_interaction.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/default_editor/document_scrollable.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_layout.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_per_component.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_shylesheet.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_user_selection.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/unknown_component.dart';

import 'read_only_document_android_touch_interactor.dart';
import 'read_only_document_ios_touch_interactor.dart';
import 'read_only_document_keyboard_interactor.dart';
import 'read_only_document_mouse_interactor.dart';
import 'reader_context.dart';

class SuperReader extends StatefulWidget {
  SuperReader({
    Key? key,
    this.focusNode,
    required this.document,
    this.documentLayoutKey,
    this.selection,
    this.scrollController,
    Stylesheet? stylesheet,
    this.customStylePhases = const [],
    this.documentOverlayBuilders = const [],
    List<ComponentBuilder>? componentBuilders,
    List<ReadOnlyDocumentKeyboardAction>? keyboardActions,
    SelectionStyles? selectionStyle,
    this.gestureMode,
    this.androidHandleColor,
    this.androidToolbarBuilder,
    this.iOSHandleColor,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.autofocus = false,
    this.debugPaint = const DebugPaintConfig(),
  })  : stylesheet = stylesheet ?? readOnlyDefaultStylesheet,
        selectionStyles = selectionStyle ?? readOnlyDefaultSelectionStyle,
        keyboardActions = keyboardActions ?? readOnlyDefaultKeyboardActions,
        componentBuilders = componentBuilders != null
            ? [...componentBuilders, const UnknownComponentBuilder()]
            : [...readOnlyDefaultComponentBuilders, const UnknownComponentBuilder()],
        super(key: key);

  final FocusNode? focusNode;

  /// The [Document] displayed in this [SuperReader], in read-only mode.
  final Document document;

  /// [GlobalKey] that's bound to the [DocumentLayout] within
  /// this [SuperReader].
  ///
  /// This key can be used to lookup visual components in the document
  /// layout within this [SuperReader].
  final GlobalKey? documentLayoutKey;

  final ValueNotifier<DocumentSelection?>? selection;

  /// The [ScrollController] that governs this [SuperReader]'s scroll
  /// offset.
  ///
  /// [scrollController] is not used if this [SuperReader] has an ancestor
  /// [Scrollable].
  final ScrollController? scrollController;

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
  /// types that aren't supported by [SuperReader]. For example, [SuperReader]
  /// doesn't include support for tables within documents, but you could
  /// implement a `TableNode` for that purpose. You may then want to make your
  /// table styleable. To accomplish this, you add a custom style phase that
  /// knows how to interpret and apply table styles for your visual table component.
  final List<SingleColumnLayoutStylePhase> customStylePhases;

  /// Layers that are displayed on top of the document layout, aligned
  /// with the location and size of the document layout.
  final List<ReadOnlyDocumentLayerBuilder> documentOverlayBuilders;

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
  final List<ReadOnlyDocumentKeyboardAction> keyboardActions;

  /// The [SuperReader] gesture mode, e.g., mouse or touch.
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

  /// Whether or not the [SuperReader] should autofocus.
  final bool autofocus;

  /// Paints some extra visual ornamentation to help with
  /// debugging.
  final DebugPaintConfig debugPaint;

  @override
  State<SuperReader> createState() => SuperReaderState();
}

class SuperReaderState extends State<SuperReader> {
  late DocumentEditor _editor;
  @visibleForTesting
  Document get document => _editor.document;

  late final ValueNotifier<DocumentSelection?> _selection;
  @visibleForTesting
  DocumentSelection? get selection => _selection.value;

  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;
  SingleColumnLayoutPresenter? _docLayoutPresenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  late AutoScrollController _autoScrollController;

  late ReaderContext _readerContext;

  @visibleForTesting
  FocusNode get focusNode => _focusNode;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editor = _ReadOnlyDocumentEditor(document: widget.document);
    _selection = widget.selection ?? ValueNotifier<DocumentSelection?>(null);

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    _autoScrollController = AutoScrollController();

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _readerContext = ReaderContext(
      document: widget.document,
      getDocumentLayout: () => _docLayoutKey.currentState as DocumentLayout,
      selection: _selection,
      scrollController: _autoScrollController,
    );

    _createLayoutPresenter();
  }

  @override
  void didUpdateWidget(SuperReader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.document != oldWidget.document) {
      _editor = _ReadOnlyDocumentEditor(document: widget.document);
    }
    if (widget.selection != oldWidget.selection) {
      _selection = widget.selection ?? ValueNotifier<DocumentSelection?>(null);
    }
  }

  void _createLayoutPresenter() {
    if (_docLayoutPresenter != null) {
      _docLayoutPresenter!.dispose();
    }

    _docStylesheetStyler = SingleColumnStylesheetStyler(stylesheet: widget.stylesheet);

    _docLayoutPerComponentBlockStyler = SingleColumnLayoutCustomComponentStyler();

    _docLayoutSelectionStyler = SingleColumnLayoutSelectionStyler(
      document: _editor.document,
      selection: _selection,
      selectionStyles: widget.selectionStyles,
    );

    _docLayoutPresenter = SingleColumnLayoutPresenter(
      document: _editor.document,
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
        documentLayout: SingleColumnDocumentLayout(
          key: _docLayoutKey,
          presenter: _docLayoutPresenter!,
          componentBuilders: widget.componentBuilders,
          showDebugPaint: widget.debugPaint.layout,
        ),
      ),
    );
  }

  Widget _buildInputSystem({
    required Widget child,
  }) {
    // In a read-only document, we don't expect the software keyboard
    // to ever be open. Therefore, we only respond to key presses, such
    // as arrow keys.
    return ReadOnlyDocumentKeyboardInteractor(
      focusNode: _focusNode,
      readerContext: _readerContext,
      keyboardActions: widget.keyboardActions,
      autofocus: widget.autofocus,
      child: child,
    );
  }

  /// Builds the widget tree that handles user gesture interaction
  /// with the document, e.g., mouse input on desktop, or touch input
  /// on mobile.
  Widget _buildGestureSystem({
    required Widget documentLayout,
  }) {
    switch (_gestureMode) {
      case DocumentGestureMode.mouse:
        return _buildDesktopGestureSystem(documentLayout);
      case DocumentGestureMode.android:
        return ReadOnlyAndroidDocumentTouchInteractor(
          focusNode: _focusNode,
          document: _readerContext.document,
          documentKey: _docLayoutKey,
          getDocumentLayout: () => _readerContext.documentLayout,
          selection: _readerContext.selection,
          scrollController: widget.scrollController,
          handleColor: widget.androidHandleColor ?? Theme.of(context).primaryColor,
          popoverToolbarBuilder: widget.androidToolbarBuilder ?? (_) => const SizedBox(),
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
          showDebugPaint: widget.debugPaint.gestures,
          child: documentLayout,
        );
      case DocumentGestureMode.iOS:
        return ReadOnlyIOSDocumentTouchInteractor(
          focusNode: _focusNode,
          document: _readerContext.document,
          getDocumentLayout: () => _readerContext.documentLayout,
          selection: _readerContext.selection,
          scrollController: widget.scrollController,
          documentKey: _docLayoutKey,
          handleColor: widget.iOSHandleColor ?? Theme.of(context).primaryColor,
          popoverToolbarBuilder: widget.iOSToolbarBuilder ?? (_) => const SizedBox(),
          createOverlayControlsClipper: widget.createOverlayControlsClipper,
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
            // When SuperReader installs its own Viewport, we want the gesture
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
                child: ReadOnlyDocumentMouseInteractor(
                  focusNode: _focusNode,
                  readerContext: _readerContext,
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
                        child: overlayBuilder.build(context, _readerContext),
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

/// A [DocumentEditor] that doesn't edit the given [Document].
///
/// A [_ReadOnlyDocumentEditor] can be used to display a [SuperReader], while
/// forcibly preventing any changes to the underlying document.
class _ReadOnlyDocumentEditor implements DocumentEditor {
  const _ReadOnlyDocumentEditor({
    required this.document,
  });

  @override
  final Document document;

  @override
  void executeCommand(EditorCommand command) {
    if (kDebugMode) {
      throw Exception("Attempted to edit a read-only document: $command");
    }
  }
}

/// Builds widgets that are displayed at the same position and size as
/// the document layout within a [SuperReader].
abstract class ReadOnlyDocumentLayerBuilder {
  Widget build(BuildContext context, ReaderContext documentContext);
}

/// Creates visual components for the standard [SuperReader].
///
/// These builders are in priority order. The first builder
/// to return a non-null component is used.
final readOnlyDefaultComponentBuilders = <ComponentBuilder>[
  const BlockquoteComponentBuilder(),
  const ParagraphComponentBuilder(),
  const ListItemComponentBuilder(),
  const ImageComponentBuilder(),
  const HorizontalRuleComponentBuilder(),
];

/// Stylesheet applied to all [SuperReader]s by default.
final readOnlyDefaultStylesheet = Stylesheet(
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
  inlineTextStyler: readOnlyDefaultInlineTextStyler,
);

TextStyle readOnlyDefaultInlineTextStyler(Set<Attribution> attributions, TextStyle existingStyle) {
  return existingStyle.merge(readOnlyDefaultStyleBuilder(attributions));
}

/// Creates [TextStyles] for the standard [SuperReader].
TextStyle readOnlyDefaultStyleBuilder(Set<Attribution> attributions) {
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
const readOnlyDefaultSelectionStyle = SelectionStyles(
  selectionColor: Color(0xFFACCEF7),
);
