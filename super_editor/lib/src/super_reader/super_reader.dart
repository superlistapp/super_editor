import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_debug_paint.dart';
import 'package:super_editor/src/core/document_interaction.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/styles.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/blockquote.dart';
import 'package:super_editor/src/default_editor/document_scrollable.dart';
import 'package:super_editor/src/default_editor/horizontal_rule.dart';
import 'package:super_editor/src/default_editor/image.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_per_component.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_shylesheet.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_styler_user_selection.dart';
import 'package:super_editor/src/default_editor/list_items.dart';
import 'package:super_editor/src/default_editor/paragraph.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/unknown_component.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/document_gestures_interaction_overrides.dart';
import 'package:super_editor/src/infrastructure/documents/document_scaffold.dart';
import 'package:super_editor/src/infrastructure/documents/document_scroller.dart';
import 'package:super_editor/src/infrastructure/links.dart';
import 'package:super_editor/src/infrastructure/selection_leader_document_layer.dart';

import '../infrastructure/platforms/mobile_documents.dart';
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
    this.contentTapDelegateFactory = superReaderLaunchLinkTapHandlerFactory,
    this.androidHandleColor,
    this.androidToolbarBuilder,
    this.iOSHandleColor,
    this.iOSToolbarBuilder,
    this.createOverlayControlsClipper,
    this.autofocus = false,
    this.overlayController,
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

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

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
  /// These actions are only used when in [TextInputSource.keyboard]
  /// mode.
  final List<ReadOnlyDocumentKeyboardAction> keyboardActions;

  /// The [SuperReader] gesture mode, e.g., mouse or touch.
  final DocumentGestureMode? gestureMode;

  /// Factory that creates a [ContentTapDelegate], which is given an
  /// opportunity to respond to taps on content before the editor, itself.
  ///
  /// A [ContentTapDelegate] might be used, for example, to launch a URL
  /// when a user taps on a link.
  final SuperReaderContentTapDelegateFactory? contentTapDelegateFactory;

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
  @visibleForTesting
  Document get document => widget.document;

  late final ValueNotifier<DocumentSelection?> _selection;
  @visibleForTesting
  DocumentSelection? get selection => _selection.value;

  // GlobalKey used to access the [DocumentLayoutState] to figure
  // out where in the document the user taps or drags.
  late GlobalKey _docLayoutKey;
  final _documentLayoutLink = LayerLink();
  SingleColumnLayoutPresenter? _docLayoutPresenter;
  late SingleColumnStylesheetStyler _docStylesheetStyler;
  late SingleColumnLayoutCustomComponentStyler _docLayoutPerComponentBlockStyler;
  late SingleColumnLayoutSelectionStyler _docLayoutSelectionStyler;

  ContentTapDelegate? _contentTapDelegate;

  late DocumentScroller _scroller;
  late ScrollController _scrollController;
  late AutoScrollController _autoScrollController;

  late SuperReaderContext _readerContext;

  @visibleForTesting
  FocusNode get focusNode => _focusNode;
  late FocusNode _focusNode;

  // Leader links that connect leader widgets near the user's selection
  // to carets, handles, and other things that want to follow the selection.
  final _selectionLinks = SelectionLayerLinks();

  @override
  void initState() {
    super.initState();
    _selection = widget.selection ?? ValueNotifier<DocumentSelection?>(null);

    _focusNode = (widget.focusNode ?? FocusNode())..addListener(_onFocusChange);

    _scroller = DocumentScroller();
    _scrollController = widget.scrollController ?? ScrollController();
    _autoScrollController = AutoScrollController();

    _docLayoutKey = widget.documentLayoutKey ?? GlobalKey();

    _createReaderContext();

    _createLayoutPresenter();
  }

  @override
  void didUpdateWidget(SuperReader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selection != oldWidget.selection) {
      _selection = widget.selection ?? ValueNotifier<DocumentSelection?>(null);
    }

    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController = widget.scrollController ?? ScrollController();
    }

    if (widget.document != oldWidget.document ||
        widget.selection != oldWidget.selection ||
        widget.scrollController != oldWidget.scrollController) {
      _createReaderContext();
    }

    if (widget.stylesheet != oldWidget.stylesheet) {
      _createLayoutPresenter();
    }
  }

  @override
  void dispose() {
    _contentTapDelegate?.dispose();

    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      // We are using our own private FocusNode. Dispose it.
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _createReaderContext() {
    _readerContext = SuperReaderContext(
      document: widget.document,
      getDocumentLayout: () => _docLayoutKey.currentState as DocumentLayout,
      selection: _selection,
      scroller: _scroller,
    );

    _contentTapDelegate?.dispose();
    _contentTapDelegate = widget.contentTapDelegateFactory?.call(_readerContext);
  }

  void _createLayoutPresenter() {
    if (_docLayoutPresenter != null) {
      _docLayoutPresenter!.dispose();
    }

    _docStylesheetStyler = SingleColumnStylesheetStyler(
      stylesheet: widget.stylesheet,
    );

    _docLayoutPerComponentBlockStyler = SingleColumnLayoutCustomComponentStyler();

    _docLayoutSelectionStyler = SingleColumnLayoutSelectionStyler(
      document: widget.document,
      selection: _selection,
      selectionStyles: widget.selectionStyles,
    );

    _docLayoutPresenter = SingleColumnLayoutPresenter(
      document: widget.document,
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
    return ReadOnlyDocumentKeyboardInteractor(
      // In a read-only document, we don't expect the software keyboard
      // to ever be open. Therefore, we only respond to key presses, such
      // as arrow keys.
      focusNode: _focusNode,
      readerContext: _readerContext,
      keyboardActions: widget.keyboardActions,
      autofocus: widget.autofocus,
      child: DocumentScaffold(
        documentLayoutLink: _documentLayoutLink,
        documentLayoutKey: _docLayoutKey,
        gestureBuilder: _buildGestureInteractor,
        scrollController: _scrollController,
        autoScrollController: _autoScrollController,
        scroller: _scroller,
        presenter: _docLayoutPresenter!,
        componentBuilders: widget.componentBuilders,
        underlays: [
          // Layer that positions and sizes leader widgets at the bounds
          // of the users selection so that carets, handles, toolbars, and
          // other things can follow the selection.
          (context) => _SelectionLeadersDocumentLayerBuilder(
                links: _selectionLinks,
              ).build(context, _readerContext),
        ],
        overlays: [
          for (final overlayBuilder in widget.documentOverlayBuilders) //
            (context) => overlayBuilder.build(context, _readerContext),
        ],
        debugPaint: widget.debugPaint,
      ),
    );
  }

  Widget _buildGestureInteractor(BuildContext context) {
    switch (_gestureMode) {
      case DocumentGestureMode.mouse:
        return _buildDesktopGestureSystem();
      case DocumentGestureMode.android:
        return _buildAndroidGestureSystem();
      case DocumentGestureMode.iOS:
        return _buildIOSGestureSystem();
    }
  }

  Widget _buildDesktopGestureSystem() {
    return ReadOnlyDocumentMouseInteractor(
      focusNode: _focusNode,
      readerContext: _readerContext,
      contentTapHandler: _contentTapDelegate,
      autoScroller: _autoScrollController,
      showDebugPaint: widget.debugPaint.gestures,
      child: const SizedBox(),
    );
  }

  Widget _buildAndroidGestureSystem() {
    return ReadOnlyAndroidDocumentTouchInteractor(
      focusNode: _focusNode,
      document: _readerContext.document,
      documentKey: _docLayoutKey,
      getDocumentLayout: () => _readerContext.documentLayout,
      selection: _readerContext.selection,
      selectionLinks: _selectionLinks,
      contentTapHandler: _contentTapDelegate,
      scrollController: _scrollController,
      handleColor: widget.androidHandleColor ?? Theme.of(context).primaryColor,
      popoverToolbarBuilder: widget.androidToolbarBuilder ?? (_) => const SizedBox(),
      createOverlayControlsClipper: widget.createOverlayControlsClipper,
      showDebugPaint: widget.debugPaint.gestures,
      overlayController: widget.overlayController,
    );
  }

  Widget _buildIOSGestureSystem() {
    return ReadOnlyIOSDocumentTouchInteractor(
      focusNode: _focusNode,
      document: _readerContext.document,
      getDocumentLayout: () => _readerContext.documentLayout,
      selection: _readerContext.selection,
      selectionLinks: _selectionLinks,
      contentTapHandler: _contentTapDelegate,
      scrollController: _scrollController,
      documentKey: _docLayoutKey,
      handleColor: widget.iOSHandleColor ?? Theme.of(context).primaryColor,
      popoverToolbarBuilder: widget.iOSToolbarBuilder ?? (_) => const SizedBox(),
      createOverlayControlsClipper: widget.createOverlayControlsClipper,
      showDebugPaint: widget.debugPaint.gestures,
      overlayController: widget.overlayController,
    );
  }
}

/// A [ReadOnlyDocumentLayerBuilder] that builds a [SelectionLeadersDocumentLayer], which positions
/// leader widgets at the base and extent of the user's selection, so that other widgets
/// can position themselves relative to the user's selection.
class _SelectionLeadersDocumentLayerBuilder implements ReadOnlyDocumentLayerBuilder {
  const _SelectionLeadersDocumentLayerBuilder({
    required this.links,
    // ignore: unused_element
    this.showDebugLeaderBounds = false,
  });

  /// Collections of [LayerLink]s, which are given to leader widgets that are
  /// positioned at the selection bounds, and around the full selection.
  final SelectionLayerLinks links;

  /// Whether to paint colorful bounds around the leader widgets, for debugging purposes.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, SuperReaderContext readerContext) {
    return SelectionLeadersDocumentLayer(
      document: readerContext.document,
      selection: readerContext.selection,
      documentLayoutResolver: () => readerContext.documentLayout,
      links: links,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// Builds widgets that are displayed at the same position and size as
/// the document layout within a [SuperReader].
abstract class ReadOnlyDocumentLayerBuilder {
  ContentLayerWidget build(BuildContext context, SuperReaderContext documentContext);
}

typedef SuperReaderContentTapDelegateFactory = ContentTapDelegate Function(SuperReaderContext editContext);

SuperReaderLaunchLinkTapHandler superReaderLaunchLinkTapHandlerFactory(SuperReaderContext readerContext) =>
    SuperReaderLaunchLinkTapHandler(readerContext.document);

/// A [ContentTapDelegate] that opens links when the user taps text with
/// a [LinkAttribution].
class SuperReaderLaunchLinkTapHandler extends ContentTapDelegate {
  SuperReaderLaunchLinkTapHandler(this.document);

  final Document document;

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    final link = _getLinkAtPosition(hoverPosition);
    return link != null ? SystemMouseCursors.click : null;
  }

  @override
  TapHandlingInstruction onTap(DocumentPosition tapPosition) {
    final link = _getLinkAtPosition(tapPosition);
    if (link != null) {
      // The user tapped on a link. Launch it.
      UrlLauncher.instance.launchUrl(link);
      return TapHandlingInstruction.halt;
    } else {
      // The user didn't tap on a link.
      return TapHandlingInstruction.continueHandling;
    }
  }

  Uri? _getLinkAtPosition(DocumentPosition position) {
    final nodePosition = position.nodePosition;
    if (nodePosition is! TextNodePosition) {
      return null;
    }

    final textNode = document.getNodeById(position.nodeId);
    if (textNode is! TextNode) {
      readerGesturesLog
          .shout("Received a report of a tap on a TextNodePosition, but the node with that ID is a: $textNode");
      return null;
    }

    final tappedAttributions = textNode.text.getAllAttributionsAt(nodePosition.offset);
    for (final tappedAttribution in tappedAttributions) {
      if (tappedAttribution is LinkAttribution) {
        return tappedAttribution.url;
      }
    }

    return null;
  }
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
