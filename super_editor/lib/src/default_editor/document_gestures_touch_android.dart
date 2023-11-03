import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/default_editor/text_tools.dart';
import 'package:super_editor/src/document_operations/selection_operations.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/blinking_caret.dart';
import 'package:super_editor/src/infrastructure/content_layers.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/flutter/overlay_with_groups.dart';
import 'package:super_editor/src/infrastructure/multi_tap_gesture.dart';
import 'package:super_editor/src/infrastructure/platforms/android/android_document_controls.dart';
import 'package:super_editor/src/infrastructure/platforms/android/long_press_selection.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/platforms/android/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/android/toolbar.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/signal_notifier.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';
import 'package:super_editor/src/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_editor/src/super_textfield/metrics.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../infrastructure/document_gestures.dart';
import '../infrastructure/document_gestures_interaction_overrides.dart';
import 'selection_upstream_downstream.dart';

/// An [InheritedWidget] that provides shared access to a [SuperEditorAndroidControlsController],
/// which coordinates the state of Android controls like the caret, handles, magnifier, etc.
///
/// This widget and its associated controller exist so that [SuperEditor] has maximum freedom
/// in terms of where to implement Android gestures vs carets vs the magnifier vs the toolbar.
/// Each of these responsibilities have some unique differences, which make them difficult or
/// impossible to implement within a single widget. By sharing a controller, a group of independent
/// widgets can work together to cover those various responsibilities.
///
/// Centralizing a controller in an [InheritedWidget] also allows [SuperEditor] to share that
/// control with application code outside of [SuperEditor], by placing a [SuperEditorAndroidControlsScope]
/// above the [SuperEditor] in the widget tree. For this reason, [SuperEditor] should access
/// the [SuperEditorAndroidControlsScope] through [rootOf].
class SuperEditorAndroidControlsScope extends InheritedWidget {
  /// Finds the highest [SuperEditorAndroidControlsScope] in the widget tree, above the given
  /// [context], and returns its associated [SuperEditorAndroidControlsController].
  static SuperEditorAndroidControlsController rootOf(BuildContext context) {
    final data = maybeRootOf(context);

    if (data == null) {
      throw Exception(
          "Tried to depend upon the root SuperEditorAndroidControlsScope but no such ancestor widget exists.");
    }

    return data;
  }

  static SuperEditorAndroidControlsController? maybeRootOf(BuildContext context) {
    InheritedElement? root;

    context.visitAncestorElements((element) {
      if (element is! InheritedElement || element.widget is! SuperEditorAndroidControlsScope) {
        // Keep visiting.
        return true;
      }

      root = element;

      // Keep visiting, to ensure we get the root scope.
      return true;
    });

    if (root == null) {
      return null;
    }

    // Create build dependency on the Android controls context.
    context.dependOnInheritedElement(root!);

    // Return the current Android controls data.
    return (root!.widget as SuperEditorAndroidControlsScope).controller;
  }

  /// Finds the nearest [SuperEditorAndroidControlsScope] in the widget tree, above the given
  /// [context], and returns its associated [SuperEditorAndroidControlsController].
  static SuperEditorAndroidControlsController nearestOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperEditorAndroidControlsScope>()!.controller;

  static SuperEditorAndroidControlsController? maybeNearestOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperEditorAndroidControlsScope>()?.controller;

  const SuperEditorAndroidControlsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SuperEditorAndroidControlsController controller;

  @override
  bool updateShouldNotify(SuperEditorAndroidControlsScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// A controller, which coordinates the state of various Android editor controls, including
/// the caret, handles, magnifier, and toolbar.
class SuperEditorAndroidControlsController {
  SuperEditorAndroidControlsController({
    // TODO: how do we resolve implied conflict between handleColor and custom handle builders?
    this.controlsColor,
    LeaderLink? collapsedHandleFocalPoint,
    this.collapsedHandleBuilder,
    LeaderLink? upstreamHandleFocalPoint,
    LeaderLink? downstreamHandleFocalPoint,
    this.expandedHandlesBuilder,
    this.magnifierBuilder,
    this.toolbarBuilder,
    this.createOverlayControlsClipper,
  })  : collapsedHandleFocalPoint = collapsedHandleFocalPoint ?? LeaderLink(),
        upstreamHandleFocalPoint = upstreamHandleFocalPoint ?? LeaderLink(),
        downstreamHandleFocalPoint = downstreamHandleFocalPoint ?? LeaderLink();

  void dispose() {
    _shouldCaretBlink.dispose();
    _shouldShowMagnifier.dispose();
    _shouldShowToolbar.dispose();
  }

  /// Whether the caret should blink right now.
  ValueListenable<bool> get shouldCaretBlink => _shouldCaretBlink;
  final _shouldCaretBlink = ValueNotifier<bool>(false);

  /// Tells the caret to blink by setting [shouldCaretBlink] to `true`.
  void blinkCaret() {
    print("START BLINKING CARET!");
    _shouldCaretBlink.value = true;
  }

  /// Tells the caret to stop blinking by setting [shouldCaretBlink] to `false`.
  void doNotBlinkCaret() {
    print("STOP BLINKING CARET!");
    _shouldCaretBlink.value = false;
  }

  /// Color of the caret and text selection drag handles on Android.
  final Color? controlsColor;

  final LeaderLink collapsedHandleFocalPoint;

  /// Whether the collapsed drag handle should be displayed right now.
  ///
  /// This value is enforced to be opposite of [shouldShowExpandedHandles].
  ValueListenable<bool> get shouldShowCollapsedHandle => _shouldShowCollapsedHandle;
  final _shouldShowCollapsedHandle = ValueNotifier<bool>(false);

  /// Shows the collapsed drag handle by setting [shouldShowCollapsedHandle] to `true`, and also
  /// hides the expanded handle by setting [shouldShowExpandedHandles] to `false`.
  void showCollapsedHandle() {
    _shouldShowCollapsedHandle.value = true;
    _shouldShowExpandedHandles.value = false;
  }

  /// Hides the collapsed drag handle by setting [shouldShowCollapsedHandle] to `false`.
  void hideCollapsedHandle() => _shouldShowCollapsedHandle.value = false;

  /// Toggles [shouldShowCollapsedHandle], and if necessary, hides the expanded handles.
  void toggleCollapsedHandle() {
    if (shouldShowCollapsedHandle.value) {
      hideCollapsedHandle();
    } else {
      showCollapsedHandle();
    }
  }

  /// (Optional) Builder to create the visual representation of all drag handles: collapsed,
  /// upstream, downstream.
  ///
  /// If [collapsedHandleBuilder] is `null`, a default Android handle is displayed.
  final DocumentCollapsedHandleBuilder? collapsedHandleBuilder;

  final LeaderLink upstreamHandleFocalPoint;
  final LeaderLink downstreamHandleFocalPoint;

  /// Whether the expanded drag handles should be displayed right now.
  ///
  /// This value is enforced to be opposite of [shouldShowCollapsedHandle].
  ValueListenable<bool> get shouldShowExpandedHandles => _shouldShowExpandedHandles;
  final _shouldShowExpandedHandles = ValueNotifier<bool>(false);

  /// Shows the expanded drag handles by setting [shouldShowExpandedHandles] to `true`, and also
  /// hides the collapsed handle by setting [shouldShowCollapsedHandle] to `false`.
  void showExpandedHandles() {
    _shouldShowExpandedHandles.value = true;
    _shouldShowCollapsedHandle.value = false;
  }

  /// Hides the expanded drag handles by setting [shouldShowExpandedHandles] to `false`.
  void hideExpandedHandles() => _shouldShowExpandedHandles.value = false;

  /// Toggles [shouldShowExpandedHandles], and if necessary, hides the collapsed handle.
  void toggleExpandedHandles() {
    if (shouldShowExpandedHandles.value) {
      hideCollapsedHandle();
    } else {
      showCollapsedHandle();
    }
  }

  /// (Optional) Builder to create the visual representation of the expanded drag handles.
  ///
  /// If [expandedHandlesBuilder] is `null`, default Android handles are displayed.
  final DocumentExpandedHandlesBuilder? expandedHandlesBuilder;

  /// Whether the Android magnifier should be displayed right now.
  ValueListenable<bool> get shouldShowMagnifier => _shouldShowMagnifier;
  final _shouldShowMagnifier = ValueNotifier<bool>(false);

  /// Shows the magnifier by setting [shouldShowMagnifier] to `true`.
  void showMagnifier() => _shouldShowMagnifier.value = true;

  /// Hides the magnifier by setting [shouldShowMagnifier] to `false`.
  void hideMagnifier() => _shouldShowMagnifier.value = false;

  /// Toggles [shouldShowMagnifier].
  void toggleMagnifier() => _shouldShowMagnifier.value = !_shouldShowMagnifier.value;

  /// Link to a location where a magnifier should be focused.
  final magnifierFocalPoint = LeaderLink();

  /// (Optional) Builder to create the visual representation of the magnifier.
  ///
  /// If [magnifierBuilder] is `null`, a default Android magnifier is displayed.
  final DocumentMagnifierBuilder? magnifierBuilder;

  /// Whether the Android floating toolbar should be displayed right now.
  ValueListenable<bool> get shouldShowToolbar => _shouldShowToolbar;
  final _shouldShowToolbar = ValueNotifier<bool>(false);

  /// Shows the toolbar by setting [shouldShowToolbar] to `true`.
  void showToolbar() => _shouldShowToolbar.value = true;

  /// Hides the toolbar by setting [shouldShowToolbar] to `false`.
  void hideToolbar() => _shouldShowToolbar.value = false;

  /// Toggles [shouldShowToolbar].
  void toggleToolbar() => _shouldShowToolbar.value = !_shouldShowToolbar.value;

  /// Link to a location where a toolbar should be focused.
  ///
  /// This link probably points to a rectangle, such as a bounding rectangle
  /// around the user's selection. Therefore, the toolbar builder shouldn't
  /// assume that this focal point is a single pixel.
  final toolbarFocalPoint = LeaderLink();

  /// (Optional) Builder to create the visual representation of the floating
  /// toolbar.
  ///
  /// If [toolbarBuilder] is `null`, a default Android toolbar is displayed.
  final DocumentFloatingToolbarBuilder? toolbarBuilder;

  /// Creates a clipper that restricts where the toolbar and magnifier can
  /// appear in the overlay.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;
}

/// A [SuperEditorDocumentLayerBuilder] that builds an [AndroidToolbarFocalPointDocumentLayer], which
/// positions a [Leader] widget around the document selection, as a focal point for an Android
/// floating toolbar.
class SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder implements SuperEditorLayerBuilder {
  const SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder({
    // ignore: unused_element
    this.showDebugLeaderBounds = false,
  });

  /// Whether to paint colorful bounds around the leader widget.
  final bool showDebugLeaderBounds;

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editorContext) {
    return AndroidToolbarFocalPointDocumentLayer(
      document: editorContext.document,
      selection: editorContext.composer.selectionNotifier,
      toolbarFocalPointLink: SuperEditorAndroidControlsScope.rootOf(context).toolbarFocalPoint,
      showDebugLeaderBounds: showDebugLeaderBounds,
    );
  }
}

/// A [SuperEditorLayerBuilder], which builds an [AndroidHandlesDocumentLayer],
/// which displays Android-style caret and handles.
class SuperEditorAndroidHandlesDocumentLayerBuilder implements SuperEditorLayerBuilder {
  const SuperEditorAndroidHandlesDocumentLayerBuilder({
    this.handleColor,
  });

  final Color? handleColor;

  @override
  ContentLayerWidget build(BuildContext context, SuperEditorContext editContext) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ContentLayerProxyWidget(child: SizedBox());
    }

    return AndroidHandlesDocumentLayer(
      document: editContext.document,
      documentLayout: editContext.documentLayout,
      selection: editContext.composer.selectionNotifier,
      changeSelection: (newSelection, changeType, reason) {
        editContext.editor.execute([
          ChangeSelectionRequest(newSelection, changeType, reason),
        ]);
      },
      handleColor: handleColor ??
          SuperEditorAndroidControlsScope.maybeRootOf(context)?.controlsColor ??
          Theme.of(context).primaryColor,
      shouldCaretBlink: SuperEditorAndroidControlsScope.rootOf(context).shouldCaretBlink,
    );
  }
}

/// Document gesture interactor that's designed for Android touch input, e.g.,
/// drag to scroll, and handles to control selection.
class AndroidDocumentTouchInteractor extends StatefulWidget {
  const AndroidDocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.editor,
    required this.document,
    required this.documentKey,
    required this.documentLayoutLink,
    required this.getDocumentLayout,
    required this.selection,
    required this.selectionLinks,
    required this.scrollController,
    this.contentTapHandler,
    this.dragAutoScrollBoundary = const AxisOffset.symmetric(54),
    required this.handleColor,
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
    this.showDebugPaint = false,
    this.overlayController,
    this.child,
  }) : super(key: key);

  final FocusNode focusNode;

  final Editor editor;
  final Document document;
  final GlobalKey documentKey;
  final LayerLink documentLayoutLink;
  final DocumentLayout Function() getDocumentLayout;
  final ValueListenable<DocumentSelection?> selection;

  final SelectionLayerLinks selectionLinks;

  /// Optional handler that responds to taps on content, e.g., opening
  /// a link when the user taps on text with a link attribution.
  final ContentTapDelegate? contentTapHandler;

  final ScrollController scrollController;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController? overlayController;

  /// The closest that the user's selection drag gesture can get to the
  /// document boundary before auto-scrolling.
  ///
  /// The default value is `54.0` pixels for both the leading and trailing
  /// edges.
  final AxisOffset dragAutoScrollBoundary;

  /// The color of the Android-style drag handles.
  final Color handleColor;

  final WidgetBuilder popoverToolbarBuilder;

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  final bool showDebugPaint;

  final Widget? child;

  @override
  State createState() => _AndroidDocumentTouchInteractorState();
}

class _AndroidDocumentTouchInteractorState extends State<AndroidDocumentTouchInteractor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  SuperEditorAndroidControlsController? _controlsController;

  bool _isScrolling = false;

  /// Shows, hides, and positions a floating toolbar and magnifier.
  late MagnifierAndToolbarController _overlayController;
  // The ScrollPosition attached to the _ancestorScrollable, if there's an ancestor
  // Scrollable.
  ScrollPosition? _ancestorScrollPosition;
  // The actual ScrollPosition that's used for the document layout, either
  // the Scrollable installed by this interactor, or an ancestor Scrollable.
  ScrollPosition? _activeScrollPosition;

  // Overlay controller that displays editing controls, e.g., drag handles,
  // magnifier, and toolbar.
  final _overlayPortalController =
      GroupedOverlayPortalController(displayPriority: OverlayGroupPriority.editingControls);
  final _overlayPortalRebuildSignal = SignalNotifier();
  late AndroidDocumentGestureEditingController _editingController;
  final _magnifierFocalPointLink = LayerLink();

  late DragHandleAutoScroller _handleAutoScrolling;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
  SelectionHandleType? _selectionType;

  Timer? _tapDownLongPressTimer;
  Offset? _globalTapDownOffset;
  bool get _isLongPressInProgress => _longPressStrategy != null;
  AndroidDocumentLongPressSelectionStrategy? _longPressStrategy;
  final _longPressMagnifierGlobalOffset = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();

    _handleAutoScrolling = DragHandleAutoScroller(
      vsync: this,
      dragAutoScrollBoundary: widget.dragAutoScrollBoundary,
      getScrollPosition: () => scrollPosition,
      getViewportBox: () => viewportBox,
    );

    widget.focusNode.addListener(_onFocusChange);

    _configureScrollController();

    // On the next frame, after our ScrollController is attached to the Scrollable,
    // add a listener for scroll changes.
    //
    // During Hot Reload, the gesture mode could be changed.
    // If that's the case, initState is called while the Overlay is being
    // built. This could crash the app. Because of that, we show the editing
    // controls overlay in the next frame.
    onNextFrame((_) {
      if (widget.focusNode.hasFocus) {
        _showEditingControlsOverlay();
      }
      _updateScrollPositionListener();
    });

    _overlayController = widget.overlayController ?? MagnifierAndToolbarController();

    _editingController = AndroidDocumentGestureEditingController(
      selectionLinks: widget.selectionLinks,
      magnifierFocalPointLink: _magnifierFocalPointLink,
      overlayController: _overlayController,
    );

    widget.document.addListener(_onDocumentChange);
    widget.selection.addListener(_onSelectionChange);

    // If we already have a selection, we need to display the caret.
    if (widget.selection.value != null) {
      _onSelectionChange();
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsController = SuperEditorAndroidControlsScope.rootOf(context);

    _ancestorScrollPosition = _findAncestorScrollable(context)?.position;

    // On the next frame, check if our active scroll position changed to a
    // different instance. If it did, move our listener to the new one.
    //
    // This is posted to the next frame because the first time this method
    // runs, we haven't attached to our own ScrollController yet, so
    // this.scrollPosition might be null.
    onNextFrame((_) => _updateScrollPositionListener());
  }

  @override
  void didUpdateWidget(AndroidDocumentTouchInteractor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (widget.document != oldWidget.document) {
      oldWidget.document.removeListener(_onDocumentChange);
      widget.document.addListener(_onDocumentChange);
    }

    if (widget.selection != oldWidget.selection) {
      oldWidget.selection.removeListener(_onSelectionChange);
      widget.selection.addListener(_onSelectionChange);

      // Selection has changed, we need to update the caret.
      if (widget.selection.value != oldWidget.selection.value) {
        _onSelectionChange();
      }
    }

    if (widget.scrollController != oldWidget.scrollController) {
      _teardownScrollController();
      _configureScrollController();
    }

    if (widget.overlayController != oldWidget.overlayController) {
      _overlayController = widget.overlayController ?? MagnifierAndToolbarController();
      _editingController.overlayController = _overlayController;
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    if (widget.focusNode.hasFocus) {
      // On Hot Reload we need to remove any visible overlay controls and then
      // bring them back a frame later to avoid having the controls attempt
      // to access the layout of the text. The text layout is not immediately
      // available upon Hot Reload. Accessing it results in an exception.
      // TODO: this was copied from Super Textfield, see if the timing
      //       problem exists for documents, too.
      _removeEditingOverlayControls();

      onNextFrame((_) => _showEditingControlsOverlay());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _activeScrollPosition?.removeListener(_onScrollChange);

    // We dispose the EditingController on the next frame because
    // the ListenableBuilder that uses it throws an error if we
    // dispose of it here.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _editingController.dispose();
    });

    widget.document.removeListener(_onDocumentChange);
    widget.selection.removeListener(_onSelectionChange);

    _teardownScrollController();

    widget.focusNode.removeListener(_onFocusChange);

    _handleAutoScrolling.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance. Reflow the layout. Use a post-frame callback
    // to give the rest of the UI a chance to reflow, first.
    onNextFrame((_) {
      _ensureSelectionExtentIsVisible();
      _updateHandlesAfterSelectionOrLayoutChange();

      setState(() {
        // reflow document layout
      });
    });
  }

  void _configureScrollController() {
    // I added this listener directly to our ScrollController because the listener we added
    // to the ScrollPosition wasn't triggering once the user makes an initial selection. I'm
    // not sure why that happened. It's as if the ScrollPosition was replaced, but I don't
    // know why the ScrollPosition would be replaced. In the meantime, adding this listener
    // keeps the toolbar positioning logic working.
    // TODO: rely solely on a ScrollPosition listener, not a ScrollController listener.
    widget.scrollController.addListener(_onScrollChange);

    onNextFrame((_) => scrollPosition.isScrollingNotifier.addListener(_onScrollActivityChange));
  }

  void _teardownScrollController() {
    widget.scrollController.removeListener(_onScrollActivityChange);

    if (widget.scrollController.hasClients) {
      scrollPosition.isScrollingNotifier.removeListener(_onScrollActivityChange);
    }
  }

  void _onScrollActivityChange() {
    final isScrolling = scrollPosition.isScrollingNotifier.value;

    if (isScrolling) {
      _isScrolling = true;

      // The user started to scroll.
      // Cancel the timer to stop trying to detect a long press.
      _tapDownLongPressTimer?.cancel();
      _tapDownLongPressTimer = null;
    } else {
      onNextFrame((_) {
        // Set our scrolling flag to false on the next frame, so that our tap handlers
        // have an opportunity to see that the scrollable was scrolling when the user
        // tapped down.
        //
        // See the "on tap down" handler for more info about why this flag is important.
        _isScrolling = false;
      });
    }
  }

  void _ensureSelectionExtentIsVisible() {
    editorGesturesLog.fine("Ensuring selection extent is visible");
    final collapsedHandleOffset = _editingController.collapsedHandleOffset;
    final extentHandleOffset = _editingController.downstreamHandleOffset;
    if (collapsedHandleOffset == null && extentHandleOffset == null) {
      // There's no selection. We don't need to take any action.
      return;
    }

    // Determines the offset of the editor in the viewport coordinate
    final editorBox = widget.documentKey.currentContext!.findRenderObject() as RenderBox;
    final editorInViewportOffset = viewportBox.localToGlobal(Offset.zero) - editorBox.localToGlobal(Offset.zero);

    // Determines the offset of the handle in the viewport coordinate
    late Offset handleInViewportOffset;

    if (collapsedHandleOffset != null) {
      editorGesturesLog.fine("The selection is collapsed");
      handleInViewportOffset = collapsedHandleOffset - editorInViewportOffset;
    } else {
      editorGesturesLog.fine("The selection is expanded");
      handleInViewportOffset = extentHandleOffset! - editorInViewportOffset;
    }
    _handleAutoScrolling.ensureOffsetIsVisible(handleInViewportOffset);
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      // TODO: the text field only showed the editing controls if the text input
      //       client wasn't attached yet. Do we need a similar check here?
      _showEditingControlsOverlay();
    } else {
      _removeEditingOverlayControls();
    }
  }

  void _onDocumentChange(_) {
    _editingController.hideToolbar();

    onNextFrame((_) {
      // The user may have changed the type of node, e.g., paragraph to
      // blockquote, which impacts the caret size and position. Reposition
      // the caret on the next frame.
      _updateHandlesAfterSelectionOrLayoutChange();

      _ensureSelectionExtentIsVisible();
    });
  }

  void _onSelectionChange() {
    // The selection change might correspond to new content that's not
    // laid out yet. Wait until the next frame to update visuals.
    onNextFrame((_) => _updateHandlesAfterSelectionOrLayoutChange());
  }

  void _updateHandlesAfterSelectionOrLayoutChange() {
    final newSelection = widget.selection.value;

    if (newSelection == null) {
      _editingController
        ..removeCaret()
        ..hideToolbar()
        ..collapsedHandleOffset = null
        ..upstreamHandleOffset = null
        ..downstreamHandleOffset = null
        ..collapsedHandleOffset = null
        ..cancelCollapsedHandleAutoHideCountdown();

      _controlsController!
        ..doNotBlinkCaret()
        ..hideCollapsedHandle()
        ..hideExpandedHandles()
        ..hideMagnifier()
        ..hideToolbar();
    } else if (newSelection.isCollapsed) {
      _positionCaret();
      _positionCollapsedHandle();

      _controlsController!
        // ..blinkCaret() // I commented this out because it causes blinking while we drag the caret handle
        ..hideExpandedHandles();
    } else {
      // The selection is expanded
      _positionExpandedHandles();

      _controlsController!
        ..doNotBlinkCaret()
        ..hideCollapsedHandle()
        ..showExpandedHandles();
    }
  }

  void _updateScrollPositionListener() {
    final newScrollPosition = scrollPosition;
    if (newScrollPosition != _activeScrollPosition) {
      _activeScrollPosition?.removeListener(_onScrollChange);
      newScrollPosition.addListener(_onScrollChange);
      _activeScrollPosition = newScrollPosition;
    }
  }

  void _onScrollChange() {
    _positionToolbar();
  }

  /// Returns the layout for the current document, which answers questions
  /// about the locations and sizes of visual components within the layout.
  DocumentLayout get _docLayout => widget.getDocumentLayout();

  /// Returns the `ScrollPosition` that controls the scroll offset of
  /// this widget.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `ScrollPosition` belongs to that ancestor `Scrollable`, and this
  /// widget doesn't include a `ScrollView`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and the `ScrollView`'s position
  /// is returned.
  ScrollPosition get scrollPosition => _ancestorScrollPosition ?? widget.scrollController.position;

  /// Returns the `RenderBox` for the scrolling viewport.
  ///
  /// If this widget has an ancestor `Scrollable`, then the returned
  /// `RenderBox` belongs to that ancestor `Scrollable`.
  ///
  /// If this widget doesn't have an ancestor `Scrollable`, then this
  /// widget includes a `ScrollView` and this `State`'s render object
  /// is the viewport `RenderBox`.
  RenderBox get viewportBox =>
      (_findAncestorScrollable(context)?.context.findRenderObject() ?? context.findRenderObject()) as RenderBox;

  Offset _getDocumentOffsetFromGlobalOffset(Offset globalOffset) {
    return _docLayout.getDocumentOffsetFromAncestorOffset(globalOffset);
  }

  /// Maps the given [interactorOffset] within the interactor's coordinate space
  /// to the same screen position in the viewport's coordinate space.
  ///
  /// When this interactor includes it's own `ScrollView`, the [interactorOffset]
  /// is the same as the viewport offset.
  ///
  /// When this interactor defers to an ancestor `Scrollable`, then the
  /// [interactorOffset] is transformed into the ancestor coordinate space.
  Offset _interactorOffsetInViewport(Offset interactorOffset) {
    // Viewport might be our box, or an ancestor box if we're inside someone
    // else's Scrollable.
    final interactorBox = context.findRenderObject() as RenderBox;
    return viewportBox.globalToLocal(
      interactorBox.localToGlobal(interactorOffset),
    );
  }

  bool _wasScrollingOnTapDown = false;
  void _onTapDown(TapDownDetails details) {
    // When the user scrolls and releases, the scrolling continues with momentum.
    // If the user then taps down again, the momentum stops. When this happens, we
    // still receive tap callbacks. But we don't want to take any further action,
    // like moving the caret, when the user taps to stop scroll momentum. We have
    // to carefully watch the scrolling activity to recognize when this happens.
    // We can't check whether we're scrolling in "on tap up" because by then the
    // scrolling has already stopped. So we log whether we're scrolling "on tap down"
    // and then check this flag in "on tap up".
    _wasScrollingOnTapDown = _isScrolling;

    final position = scrollPosition;
    if (position is ScrollPositionWithSingleContext) {
      position.goIdle();
    }

    _globalTapDownOffset = details.globalPosition;
    _tapDownLongPressTimer?.cancel();
    if (!disableLongPressSelectionForSuperlist) {
      _tapDownLongPressTimer = Timer(kLongPressTimeout, _onLongPressDown);
    }
  }

  // Runs when a tap down has lasted long enough to signify a long-press.
  void _onLongPressDown() {
    _longPressStrategy = AndroidDocumentLongPressSelectionStrategy(
      document: widget.document,
      documentLayout: _docLayout,
      select: _updateLongPressSelection,
    );

    final didLongPressSelectionStart = _longPressStrategy!.onLongPressStart(
      tapDownDocumentOffset: _getDocumentOffsetFromGlobalOffset(_globalTapDownOffset!),
    );
    if (!didLongPressSelectionStart) {
      _longPressStrategy = null;
      return;
    }

    // A long-press selection is in progress. Initially show the toolbar, but nothing else.
    _editingController
      ..disallowHandles()
      ..hideMagnifier()
      ..showToolbar();
    _controlsController!
      ..hideCollapsedHandle()
      ..hideExpandedHandles()
      ..hideMagnifier()
      ..showToolbar();
    _positionToolbar();
    _overlayPortalRebuildSignal.notifyListeners();

    widget.focusNode.requestFocus();
  }

  void _onTapUp(TapUpDetails details) {
    // Stop waiting for a long-press to start.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();

    // Cancel any on-going long-press.
    if (_isLongPressInProgress) {
      _longPressStrategy = null;
      _longPressMagnifierGlobalOffset.value = null;

      // We hide the selection handles when long-press dragging, despite having
      // an expanded selection. Allow the handles to come back.
      _editingController.allowHandles();
      _overlayPortalRebuildSignal.notifyListeners();

      return;
    }

    if (_wasScrollingOnTapDown) {
      // The scrollable was scrolling when the user touched down. We expect that the
      // touch down stopped the scrolling momentum. We don't want to take any further
      // action on this touch event. The user will tap again to change the selection.
      return;
    }

    editorGesturesLog.info("Tap down on document");
    final docOffset = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (widget.contentTapHandler != null && docPosition != null) {
      final result = widget.contentTapHandler!.onTap(docPosition);
      if (result == TapHandlingInstruction.halt) {
        // The custom tap handler doesn't want us to react at all
        // to the tap.
        return;
      }
    }

    if (docPosition != null) {
      final selection = widget.selection.value;
      final didTapOnExistingSelection = selection != null && selection.isCollapsed && selection.extent == docPosition;

      if (didTapOnExistingSelection) {
        // Toggle the toolbar display when the user taps on the collapsed caret,
        // or on top of an existing selection.
        _editingController.toggleToolbar();
        _controlsController!.toggleToolbar();
      } else {
        // The user tapped somewhere else in the document. Hide the toolbar.
        _editingController.hideToolbar();
        _controlsController!.hideToolbar();
      }

      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        // The user tapped a non-selectable component.
        // Place the document selection at the nearest selectable node
        // to the tapped component.
        moveSelectionToNearestSelectableNode(
          editor: widget.editor,
          document: widget.document,
          documentLayoutResolver: widget.getDocumentLayout,
          currentSelection: widget.selection.value,
          startingNode: widget.document.getNodeById(docPosition.nodeId)!,
        );
      } else {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }

      _positionToolbar();
    } else {
      _clearSelection();

      _editingController.hideToolbar();
      _controlsController!.hideToolbar();
    }

    widget.focusNode.requestFocus();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Double tap down on document");
    final docOffset = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null && widget.contentTapHandler != null) {
      final result = widget.contentTapHandler!.onDoubleTap(docPosition);
      if (result == TapHandlingInstruction.halt) {
        // The custom tap handler doesn't want us to react at all
        // to the tap.
        return;
      }
    }

    if (docPosition != null) {
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        // The user tapped a non-selectable component, so we can't select a word.
        // The editor will remain focused and selection will remain in the nearest
        // selectable component, as set in _onTapUp.
        return;
      }

      bool didSelectContent = _selectWordAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );

      if (!didSelectContent) {
        didSelectContent = _selectBlockAt(docPosition);
      }

      if (!didSelectContent) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
      }

      if (!widget.selection.value!.isCollapsed) {
        _editingController.showToolbar();
        _controlsController!.showToolbar();
        _positionToolbar();
      } else {
        // The selection is collapsed. The collapsed handle should disappear
        // after some inactivity. Start the countdown (or restart an in-progress
        // countdown).
        _editingController
          ..unHideCollapsedHandle()
          ..startCollapsedHandleAutoHideCountdown();
        _controlsController!
          ..showCollapsedHandle()
          ..hideCollapsedHandle();
      }
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  bool _selectBlockAt(DocumentPosition position) {
    if (position.nodePosition is! UpstreamDownstreamNodePosition) {
      return false;
    }

    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: position.nodeId,
            nodePosition: const UpstreamDownstreamNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: position.nodeId,
            nodePosition: const UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);

    return true;
  }

  void _onTripleTapDown(TapDownDetails details) {
    editorGesturesLog.info("Triple tap down on document");
    final docOffset = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    editorGesturesLog.fine(" - document offset: $docOffset");
    final docPosition = _docLayout.getDocumentPositionNearestToOffset(docOffset);
    editorGesturesLog.fine(" - tapped document position: $docPosition");

    if (docPosition != null && widget.contentTapHandler != null) {
      final result = widget.contentTapHandler!.onTripleTap(docPosition);
      if (result == TapHandlingInstruction.halt) {
        // The custom tap handler doesn't want us to react at all
        // to the tap.
        return;
      }
    }

    if (docPosition != null) {
      // The user tapped a non-selectable component, so we can't select a paragraph.
      // The editor will remain focused and selection will remain in the nearest
      // selectable component, as set in _onTapUp.
      final tappedComponent = _docLayout.getComponentByNodeId(docPosition.nodeId)!;
      if (!tappedComponent.isVisualSelectionSupported()) {
        return;
      }

      final didSelectParagraph = _selectParagraphAt(
        docPosition: docPosition,
        docLayout: _docLayout,
      );
      if (!didSelectParagraph) {
        // Place the document selection at the location where the
        // user tapped.
        _selectPosition(docPosition);
        _positionToolbar();
      }
    } else {
      _clearSelection();
    }

    widget.focusNode.requestFocus();
  }

  void _onPanStart(DragStartDetails details) {
    // Stop waiting for a long-press to start, if a long press isn't already in-progress.
    _globalTapDownOffset = null;
    _tapDownLongPressTimer?.cancel();

    if (!_isLongPressInProgress) {
      // We only care about starting a pan if we're long-press dragging.
      return;
    }

    _globalStartDragOffset = details.globalPosition;
    _dragStartInDoc = _getDocumentOffsetFromGlobalOffset(details.globalPosition);
    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = scrollPosition.pixels;
    _startDragPositionOffset = _dragStartInDoc!;

    _longPressStrategy!.onLongPressDragStart(details);

    // Tell the overlay where to put the magnifier.
    _longPressMagnifierGlobalOffset.value = details.globalPosition;

    _handleAutoScrolling.startAutoScrollHandleMonitoring();

    scrollPosition.addListener(_updateDragSelection);

    _editingController
      ..hideToolbar()
      ..showMagnifier();
    _controlsController!
      ..hideToolbar()
      ..showMagnifier();
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isLongPressInProgress) {
      _globalDragOffset = details.globalPosition;

      final fingerDragDelta = _globalDragOffset! - _globalStartDragOffset!;
      final scrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
      final fingerDocumentOffset = _docLayout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
      final fingerDocumentPosition = _docLayout.getDocumentPositionNearestToOffset(
        _startDragPositionOffset! + fingerDragDelta - Offset(0, scrollDelta),
      );
      _longPressStrategy!.onLongPressDragUpdate(fingerDocumentOffset, fingerDocumentPosition);
      return;
    }

    // The user is trying to scroll the document. Change the scroll offset.
    scrollPosition.jumpTo(scrollPosition.pixels - details.delta.dy);
  }

  void _updateLongPressSelection(DocumentSelection newSelection) {
    if (newSelection != widget.selection.value) {
      _select(newSelection);
      HapticFeedback.lightImpact();
    }

    // Note: this needs to happen even when the selection doesn't change, in case
    // some controls, like a magnifier, need to follower the user's finger.
    _updateOverlayControlsOnLongPressDrag();
  }

  void _updateOverlayControlsOnLongPressDrag() {
    final extentDocumentOffset = _docLayout.getRectForPosition(widget.selection.value!.extent)!.center;
    final extentGlobalOffset = _docLayout.getAncestorOffsetFromDocumentOffset(extentDocumentOffset);
    final extentInteractorOffset = (context.findRenderObject() as RenderBox).globalToLocal(extentGlobalOffset);
    final extentViewportOffset = _interactorOffsetInViewport(extentInteractorOffset);
    _handleAutoScrolling.updateAutoScrollHandleMonitoring(dragEndInViewport: extentViewportOffset);

    _longPressMagnifierGlobalOffset.value = extentGlobalOffset;
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isLongPressInProgress) {
      _onLongPressEnd();
      return;
    }

    final pos = scrollPosition;
    if (pos is ScrollPositionWithSingleContext) {
      pos.goBallistic(-details.velocity.pixelsPerSecond.dy);
      pos.context.setIgnorePointer(false);
    }
  }

  void _onPanCancel() {
    if (_isLongPressInProgress) {
      _onLongPressEnd();
      return;
    }
  }

  void _onLongPressEnd() {
    _longPressStrategy!.onLongPressEnd();

    // Cancel any on-going long-press.
    _longPressStrategy = null;
    _longPressMagnifierGlobalOffset.value = null;

    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    scrollPosition.removeListener(_updateDragSelection);

    _editingController
      ..allowHandles()
      ..hideMagnifier();
    _controlsController!
      // TODO: allow handles
      ..hideMagnifier();
    if (!widget.selection.value!.isCollapsed) {
      _editingController.showToolbar();
      _controlsController!.showToolbar();
      _positionToolbar();
    }
    _overlayPortalRebuildSignal.notifyListeners();
  }

  void _showEditingControlsOverlay() {
    // _overlayPortalController.show();
  }

  void _removeEditingOverlayControls() {
    _overlayPortalController.hide();
  }

  void _onHandleDragStart(HandleType handleType, Offset globalOffset) {
    final selectionAffinity = widget.document.getAffinityForSelection(widget.selection.value!);
    switch (handleType) {
      case HandleType.collapsed:
        _selectionType = SelectionHandleType.collapsed;
        break;
      case HandleType.upstream:
        _selectionType =
            selectionAffinity == TextAffinity.downstream ? SelectionHandleType.base : SelectionHandleType.extent;
        break;
      case HandleType.downstream:
        _selectionType =
            selectionAffinity == TextAffinity.downstream ? SelectionHandleType.extent : SelectionHandleType.base;
        break;
    }

    _globalStartDragOffset = globalOffset;
    _dragStartInDoc = _getDocumentOffsetFromGlobalOffset(globalOffset);

    _startDragPositionOffset = _docLayout
        .getRectForPosition(
          _selectionType == SelectionHandleType.base ? widget.selection.value!.base : widget.selection.value!.extent,
        )!
        .center;

    // We need to record the scroll offset at the beginning of
    // a drag for the case that this interactor is embedded
    // within an ancestor Scrollable. We need to use this value
    // to calculate a scroll delta on every scroll frame to
    // account for the fact that this interactor is moving within
    // the ancestor scrollable, despite the fact that the user's
    // finger/mouse position hasn't changed.
    _dragStartScrollOffset = scrollPosition.pixels;

    _handleAutoScrolling.startAutoScrollHandleMonitoring();

    if (_selectionType == SelectionHandleType.collapsed) {
      // Don't let the handle fade out while dragging it.
      _editingController.cancelCollapsedHandleAutoHideCountdown();
    }

    scrollPosition.addListener(_updateDragSelection);
  }

  void _onHandleDragUpdate(Offset globalOffset) {
    _globalDragOffset = globalOffset;
    final interactorBox = context.findRenderObject() as RenderBox;
    _dragEndInInteractor = interactorBox.globalToLocal(globalOffset);
    final dragEndInViewport = _interactorOffsetInViewport(_dragEndInInteractor!);

    _updateSelectionForNewDragHandleLocation();

    _handleAutoScrolling.updateAutoScrollHandleMonitoring(
      dragEndInViewport: dragEndInViewport,
    );

    // TODO: find a way to only invoke this when needed, instead of every move of the handle
    _editingController.showMagnifier();
    _controlsController!.showMagnifier();
  }

  void _updateSelectionForNewDragHandleLocation() {
    final docDragDelta = _globalDragOffset! - _globalStartDragOffset!;
    final dragScrollDelta = _dragStartScrollOffset! - scrollPosition.pixels;
    final docDragPosition = _docLayout
        .getDocumentPositionNearestToOffset(_startDragPositionOffset! + docDragDelta - Offset(0, dragScrollDelta));

    if (docDragPosition == null) {
      return;
    }

    if (_selectionType == SelectionHandleType.collapsed) {
      widget.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: docDragPosition,
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
    } else if (_selectionType == SelectionHandleType.base) {
      widget.editor.execute([
        ChangeSelectionRequest(
          widget.selection.value!.copyWith(
            base: docDragPosition,
          ),
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
    } else if (_selectionType == SelectionHandleType.extent) {
      widget.editor.execute([
        ChangeSelectionRequest(
          widget.selection.value!.copyWith(
            extent: docDragPosition,
          ),
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
    }
  }

  void _onHandleDragEnd() {
    _handleAutoScrolling.stopAutoScrollHandleMonitoring();
    scrollPosition.removeListener(_updateDragSelection);

    _editingController.hideMagnifier();
    _controlsController!.hideMagnifier();

    _dragStartScrollOffset = null;
    _dragStartInDoc = null;
    _dragEndInInteractor = null;

    if (widget.selection.value!.isCollapsed) {
      // The selection is collapsed. The collapsed handle should disappear
      // after some inactivity. Start the countdown (or restart an in-progress
      // countdown).
      _editingController
        ..unHideCollapsedHandle()
        ..startCollapsedHandleAutoHideCountdown();
      _controlsController!
        // TODO: unHideCollapsedHandle
        // TODO: start auto-hide countdown
        ..hideCollapsedHandle();
    } else {
      _editingController.showToolbar();
      _controlsController!.showToolbar();
      _positionToolbar();
    }
  }

  void _updateDragSelection() {
    if (_dragStartInDoc == null) {
      return;
    }

    if (_selectionType == null) {
      // The user is probably doing a long-press drag. Nothing for us to do here.
      return;
    }

    // We have to re-calculate the drag end in the doc (instead of
    // caching the value during the pan update) because the position
    // in the document is impacted by auto-scrolling behavior.
    // final scrollDeltaWhileDragging = _dragStartScrollOffset! - scrollPosition.pixels;
    final dragEndInDoc = _getDocumentOffsetFromGlobalOffset(_globalDragOffset!);

    final dragPosition = _docLayout.getDocumentPositionNearestToOffset(dragEndInDoc);
    editorGesturesLog.info("Selecting new position during drag: $dragPosition");

    if (dragPosition == null) {
      return;
    }

    late DocumentPosition basePosition;
    late DocumentPosition extentPosition;
    switch (_selectionType!) {
      case SelectionHandleType.collapsed:
        basePosition = dragPosition;
        extentPosition = dragPosition;
        break;
      case SelectionHandleType.base:
        basePosition = dragPosition;
        extentPosition = widget.selection.value!.extent;
        break;
      case SelectionHandleType.extent:
        basePosition = widget.selection.value!.base;
        extentPosition = dragPosition;
        break;
    }

    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: basePosition,
          extent: extentPosition,
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
    editorGesturesLog.fine("Selected region: ${widget.selection.value}");
  }

  void _positionCollapsedHandle() {
    final selection = widget.selection.value;
    if (selection == null) {
      editorGesturesLog.shout("Tried to update collapsed handle offset but there is no document selection");
      return;
    }
    if (!selection.isCollapsed) {
      editorGesturesLog.shout("Tried to update collapsed handle offset but the selection is expanded");
      return;
    }

    // Calculate the new (x,y) offset for the collapsed handle.
    final extentRect = _docLayout.getRectForPosition(selection.extent);
    late Offset handleOffset = extentRect!.bottomLeft;

    _editingController
      ..collapsedHandleOffset = handleOffset
      ..unHideCollapsedHandle()
      ..startCollapsedHandleAutoHideCountdown();
    _controlsController!
      // TODO: unHideCollapsedHandle
      // TODO: start collapsed handle countdown
      ..showCollapsedHandle();
  }

  void _positionExpandedHandles() {
    final selection = widget.selection.value;
    if (selection == null) {
      editorGesturesLog.shout("Tried to update expanded handle offsets but there is no document selection");
      return;
    }
    if (selection.isCollapsed) {
      editorGesturesLog.shout("Tried to update expanded handle offsets but the selection is collapsed");
      return;
    }

    // Calculate the new (x,y) offsets for the upstream and downstream handles.
    final baseHandleOffset = _docLayout.getRectForPosition(selection.base)!.bottomLeft;
    final extentHandleOffset = _docLayout.getRectForPosition(selection.extent)!.bottomRight;
    final affinity = widget.document.getAffinityBetween(base: selection.base, extent: selection.extent);
    late Offset upstreamHandleOffset = affinity == TextAffinity.downstream ? baseHandleOffset : extentHandleOffset;
    late Offset downstreamHandleOffset = affinity == TextAffinity.downstream ? extentHandleOffset : baseHandleOffset;

    _editingController
      ..removeCaret()
      ..collapsedHandleOffset = null
      ..upstreamHandleOffset = upstreamHandleOffset
      ..downstreamHandleOffset = downstreamHandleOffset
      ..cancelCollapsedHandleAutoHideCountdown();

    _controlsController!
      // TODO: hide caret
      ..hideCollapsedHandle()
      ..hideExpandedHandles();
  }

  void _positionCaret() {
    final extentRect = _docLayout.getRectForPosition(widget.selection.value!.extent)!;

    _editingController.updateCaret(
      top: extentRect.topLeft,
      height: extentRect.height,
    );
  }

  void _positionToolbar() {
    if (!_editingController.shouldDisplayToolbar) {
      return;
    }

    late Rect selectionRect;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    final selection = widget.selection.value!;
    if (selection.isCollapsed) {
      final extentRectInDoc = _docLayout.getRectForPosition(selection.extent)!;
      selectionRect = Rect.fromPoints(
        _docLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.topLeft),
        _docLayout.getGlobalOffsetFromDocumentOffset(extentRectInDoc.bottomRight),
      );
    } else {
      final baseRectInDoc = _docLayout.getRectForPosition(selection.base)!;
      final extentRectInDoc = _docLayout.getRectForPosition(selection.extent)!;
      final selectionRectInDoc = Rect.fromPoints(
        Offset(
          min(baseRectInDoc.left, extentRectInDoc.left),
          min(baseRectInDoc.top, extentRectInDoc.top),
        ),
        Offset(
          max(baseRectInDoc.right, extentRectInDoc.right),
          max(baseRectInDoc.bottom, extentRectInDoc.bottom),
        ),
      );
      selectionRect = Rect.fromPoints(
        _docLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.topLeft),
        _docLayout.getGlobalOffsetFromDocumentOffset(selectionRectInDoc.bottomRight),
      );
    }

    // TODO: fix the horizontal placement
    //       The logic to position the toolbar horizontally is wrong.
    //       The toolbar should appear horizontally centered between the
    //       left-most and right-most edge of the selection. However, the
    //       left-most and right-most edge of the selection may not match
    //       the handle locations. Consider the situation where multiple
    //       lines/blocks of content are selected, but both handles sit near
    //       the left side of the screen. This logic will position the
    //       toolbar near the left side of the content, when the toolbar should
    //       instead be centered across the full width of the document.
    toolbarTopAnchor = selectionRect.topCenter - const Offset(0, gapBetweenToolbarAndContent);
    toolbarBottomAnchor = selectionRect.bottomCenter + const Offset(0, gapBetweenToolbarAndContent);

    _editingController.positionToolbar(
      topAnchor: toolbarTopAnchor,
      bottomAnchor: toolbarBottomAnchor,
    );
  }

  bool _selectWordAt({
    required DocumentPosition docPosition,
    required DocumentLayout docLayout,
  }) {
    final newSelection = getWordSelection(docPosition: docPosition, docLayout: docLayout);
    if (newSelection != null) {
      widget.editor.execute([
        ChangeSelectionRequest(
          newSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      return true;
    } else {
      return false;
    }
  }

  bool _selectParagraphAt({
    required DocumentPosition docPosition,
    required DocumentLayout docLayout,
  }) {
    final newSelection = getParagraphSelection(docPosition: docPosition, docLayout: docLayout);
    if (newSelection != null) {
      widget.editor.execute([
        ChangeSelectionRequest(
          newSelection,
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      return true;
    } else {
      return false;
    }
  }

  void _selectPosition(DocumentPosition position) {
    editorGesturesLog.fine("Setting document selection to $position");
    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: position,
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  void _select(DocumentSelection newSelection) {
    widget.editor.execute([
      ChangeSelectionRequest(
        newSelection,
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  void _clearSelection() {
    editorGesturesLog.fine("Clearing document selection");
    widget.editor.execute([
      const ClearSelectionRequest(),
    ]);
  }

  ScrollableState? _findAncestorScrollable(BuildContext context) {
    final ancestorScrollable = Scrollable.maybeOf(context);
    if (ancestorScrollable == null) {
      return null;
    }

    final direction = ancestorScrollable.axisDirection;
    // If the direction is horizontal, then we are inside a widget like a TabBar
    // or a horizontal ListView, so we can't use the ancestor scrollable
    if (direction == AxisDirection.left || direction == AxisDirection.right) {
      return null;
    }

    return ancestorScrollable;
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;
    return OverlayPortal(
      controller: _overlayPortalController,
      overlayChildBuilder: _buildControlsOverlay,
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          TapSequenceGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapSequenceGestureRecognizer>(
            () => TapSequenceGestureRecognizer(),
            (TapSequenceGestureRecognizer recognizer) {
              recognizer
                ..onTapDown = _onTapDown
                ..onTapUp = _onTapUp
                ..onDoubleTapDown = _onDoubleTapDown
                ..onTripleTapDown = _onTripleTapDown
                ..gestureSettings = gestureSettings;
            },
          ),
          PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
            () => PanGestureRecognizer(),
            (PanGestureRecognizer recognizer) {
              recognizer
                ..onStart = _onPanStart
                ..onUpdate = _onPanUpdate
                ..onEnd = _onPanEnd
                ..onCancel = _onPanCancel
                ..gestureSettings = gestureSettings;
            },
          ),
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context) {
    return ListenableBuilder(
        listenable: _overlayPortalRebuildSignal,
        builder: (context, child) {
          return AndroidDocumentTouchEditingControls(
            editingController: _editingController,
            documentKey: widget.documentKey,
            documentLayout: _docLayout,
            createOverlayControlsClipper: widget.createOverlayControlsClipper,
            handleColor: widget.handleColor,
            onHandleDragStart: _onHandleDragStart,
            onHandleDragUpdate: _onHandleDragUpdate,
            onHandleDragEnd: _onHandleDragEnd,
            popoverToolbarBuilder: widget.popoverToolbarBuilder,
            longPressMagnifierGlobalOffset: _longPressMagnifierGlobalOffset,
            showDebugPaint: false,
          );
        });
  }
}

/// Adds and removes an Android-style editor controls overlay, as dictated by an ancestor
/// [SuperEditorAndroidControlsScope].
class SuperEditorAndroidControlsOverlayManager extends StatefulWidget {
  const SuperEditorAndroidControlsOverlayManager({
    super.key,
    required this.getDocumentLayout,
    required this.autoScroller,
    required this.selection,
    required this.setSelection,
    this.child,
  });

  final DocumentLayoutResolver getDocumentLayout;
  final DragHandleAutoScroller autoScroller;
  final ValueListenable<DocumentSelection?> selection;
  final void Function(DocumentSelection?) setSelection;

  final Widget? child;

  @override
  State<SuperEditorAndroidControlsOverlayManager> createState() => SuperEditorAndroidControlsOverlayManagerState();
}

@visibleForTesting
class SuperEditorAndroidControlsOverlayManagerState extends State<SuperEditorAndroidControlsOverlayManager> {
  final _overlayController = OverlayPortalController();

  SuperEditorAndroidControlsController? _controlsController;
  late FollowerAligner _toolbarAligner;

  HandleType? _dragHandleType;
  final _dragHandleSelectionGlobalFocalPoint = ValueNotifier<Offset?>(null);
  final _magnifierFocalPoint = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();
    _overlayController.show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _controlsController = SuperEditorAndroidControlsScope.rootOf(context);
    // TODO: Create an Android toolbar aligner, or rename the Cupertino aligner to be generic.
    _toolbarAligner = CupertinoPopoverToolbarAligner();
  }

  void _onHandlePanStart(DragStartDetails details, HandleType handleType) {
    final selection = widget.selection.value;
    if (selection == null) {
      throw Exception("Tried to drag a collapsed Android handle when there's no selection.");
    }
    if (handleType == HandleType.collapsed && !selection.isCollapsed) {
      throw Exception("Tried to drag a collapsed Android handle but the selection is expanded.");
    }
    if (handleType != HandleType.collapsed && selection.isCollapsed) {
      throw Exception("Tried to drag an expanded Android handle but the selection is collapsed.");
    }

    _dragHandleType = handleType;

    // Find the global offset for the center of the caret as the selection focal point.
    final selectionBound = handleType == HandleType.upstream ? selection.base : selection.extent;
    final documentLayout = widget.getDocumentLayout();
    // FIXME: this logic makes sense for selecting characters, but what about images? Does it make sense to set the focal point at the center of the image?
    final centerOfContentAtOffset = documentLayout.getAncestorOffsetFromDocumentOffset(
      documentLayout.getRectForPosition(selectionBound)!.center,
    );
    _dragHandleSelectionGlobalFocalPoint.value = centerOfContentAtOffset;

    final myBox = context.findRenderObject() as RenderBox;
    _magnifierFocalPoint.value = myBox.globalToLocal(centerOfContentAtOffset);

    // Don't blink the caret while dragging the handle.
    _controlsController!
      ..doNotBlinkCaret()
      ..showMagnifier()
      ..hideToolbar();
  }

  void _onHandlePanUpdate(DragUpdateDetails details) {
    if (_dragHandleSelectionGlobalFocalPoint.value == null) {
      throw Exception(
          "Tried to pan an Android drag handle but the focal point is null. The focal point is set when the drag begins. This shouldn't be possible.");
    }

    // Move the selection focal point by the given delta.
    _dragHandleSelectionGlobalFocalPoint.value = _dragHandleSelectionGlobalFocalPoint.value! + details.delta;

    // Move the selection to the document position that's nearest the focal point.
    final documentLayout = widget.getDocumentLayout();
    final nearestPosition = documentLayout.getDocumentPositionNearestToOffset(
      documentLayout.getDocumentOffsetFromAncestorOffset(_dragHandleSelectionGlobalFocalPoint.value!),
    )!;

    // Move the magnifier focal point to match the drag x-offset, but always remain focused on the vertical
    // center of the line.
    final myBox = context.findRenderObject() as RenderBox;
    final centerOfContentAtNearestPosition = documentLayout.getAncestorOffsetFromDocumentOffset(
      documentLayout.getRectForPosition(nearestPosition)!.center,
    );
    _magnifierFocalPoint.value = myBox.globalToLocal(
      Offset(
        _magnifierFocalPoint.value!.dx + details.delta.dx,
        centerOfContentAtNearestPosition.dy,
      ),
    );

    switch (_dragHandleType!) {
      case HandleType.collapsed:
        widget.setSelection(DocumentSelection.collapsed(position: nearestPosition));
      case HandleType.upstream:
        widget.setSelection(DocumentSelection(
          base: nearestPosition,
          extent: widget.selection.value!.extent,
        ));
      case HandleType.downstream:
        widget.setSelection(DocumentSelection(
          base: widget.selection.value!.base,
          extent: nearestPosition,
        ));
    }
  }

  void _onHandlePanEnd(DragEndDetails details) {
    _onHandleDragEnd();
  }

  void _onHandlePanCancel() {
    _onHandleDragEnd();
  }

  void _onHandleDragEnd() {
    _dragHandleType = null;
    _dragHandleSelectionGlobalFocalPoint.value = null;
    _magnifierFocalPoint.value = null;

    // Start blinking the caret again, and hide the magnifier.
    _controlsController!
      ..blinkCaret()
      ..hideMagnifier();

    // If the selection is expanded, show the toolbar.
    if (widget.selection.value?.isCollapsed == false) {
      _controlsController!.showToolbar();
    }
  }

  // TODO: register this method to be notified whenever the document changes its global offset
  void _onDocumentMove() {
    // If the user isn't dragging a handle, return.

    // Find the new document position that's nearest to the focal point after the movement and update the selection.
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildOverlay,
      child: widget.child ?? const SizedBox(),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        _buildMagnifierFocalPoint(),
        _buildDebugSelectionFocalPoint(),
        _buildMagnifier(),
        // Handles and toolbar are built after the magnifier so that they don't appear in the magnifier.
        _buildCollapsedHandle(),
        ..._buildExpandedHandles(),
        _buildToolbar(),
      ],
    );
  }

  Widget _buildCollapsedHandle() {
    return ValueListenableBuilder(
      valueListenable: _controlsController!.shouldShowCollapsedHandle,
      builder: (context, shouldShow, child) {
        if (!shouldShow) {
          return const SizedBox();
        }

        // Note: If we pass this widget as the `child` property, it causes repeated starts and stops
        // of the pan gesture. By building it here, pan events work as expected.
        return Follower.withOffset(
          link: _controlsController!.collapsedHandleFocalPoint,
          leaderAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          child: GestureDetector(
            onTapDown: (_) {
              // Register tap down to win gesture arena ASAP.
            },
            onPanStart: (details) => _onHandlePanStart(details, HandleType.collapsed),
            onPanUpdate: _onHandlePanUpdate,
            onPanEnd: _onHandlePanEnd,
            onPanCancel: _onHandlePanCancel,
            dragStartBehavior: DragStartBehavior.down,
            child: AndroidSelectionHandle(
              handleType: HandleType.collapsed,
              color: _controlsController!.controlsColor ?? Theme.of(context).primaryColor,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildExpandedHandles() {
    return [
      ValueListenableBuilder(
        valueListenable: _controlsController!.shouldShowExpandedHandles,
        builder: (context, shouldShow, child) {
          if (!shouldShow) {
            return const SizedBox();
          }

          return Follower.withOffset(
            link: _controlsController!.upstreamHandleFocalPoint,
            leaderAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topRight,
            child: GestureDetector(
              onTapDown: (_) {
                // Register tap down to win gesture arena ASAP.
              },
              onPanStart: (details) => _onHandlePanStart(details, HandleType.upstream),
              onPanUpdate: _onHandlePanUpdate,
              onPanEnd: _onHandlePanEnd,
              onPanCancel: _onHandlePanCancel,
              dragStartBehavior: DragStartBehavior.down,
              child: AndroidSelectionHandle(
                handleType: HandleType.upstream,
                color: _controlsController!.controlsColor ?? Theme.of(context).primaryColor,
              ),
            ),
          );
        },
      ),
      ValueListenableBuilder(
        valueListenable: _controlsController!.shouldShowExpandedHandles,
        builder: (context, shouldShow, child) {
          if (!shouldShow) {
            return const SizedBox();
          }

          return Follower.withOffset(
            link: _controlsController!.downstreamHandleFocalPoint,
            leaderAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topLeft,
            child: GestureDetector(
              onTapDown: (_) {
                // Register tap down to win gesture arena ASAP.
              },
              onPanStart: (details) => _onHandlePanStart(details, HandleType.downstream),
              onPanUpdate: _onHandlePanUpdate,
              onPanEnd: _onHandlePanEnd,
              onPanCancel: _onHandlePanCancel,
              dragStartBehavior: DragStartBehavior.down,
              child: AndroidSelectionHandle(
                handleType: HandleType.downstream,
                color: _controlsController!.controlsColor ?? Theme.of(context).primaryColor,
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildToolbar() {
    return ValueListenableBuilder(
      valueListenable: _controlsController!.shouldShowToolbar,
      builder: (context, shouldShow, child) {
        return shouldShow ? child! : const SizedBox();
      },
      child: Follower.withAligner(
        link: _controlsController!.toolbarFocalPoint,
        aligner: _toolbarAligner,
        // TODO: use controller builder
        // child: _controlsController!.toolbarBuilder(),
        child: AndroidTextEditingFloatingToolbar(
          // TODO: implement actions
          onCopyPressed: () {},
          onCutPressed: () {},
          onPastePressed: () {},
          onSelectAllPressed: () {},
        ),
      ),
    );
  }

  Widget _buildMagnifierFocalPoint() {
    return ValueListenableBuilder(
      valueListenable: _magnifierFocalPoint,
      builder: (context, focalPoint, child) {
        if (focalPoint == null) {
          return const SizedBox();
        }

        return Positioned(
          left: focalPoint.dx,
          top: focalPoint.dy,
          width: 1,
          height: 1,
          child: Leader(
            link: _controlsController!.magnifierFocalPoint,
            child: ColoredBox(
              color: Colors.pinkAccent,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMagnifier() {
    return ValueListenableBuilder(
      valueListenable: _controlsController!.shouldShowMagnifier,
      builder: (context, shouldShow, child) {
        if (shouldShow) {
          print("SHOWING MAGNIFIER - focal point: ${_controlsController!.magnifierFocalPoint}");
        }
        return shouldShow ? child! : const SizedBox();
      },
      child: Follower.withOffset(
        link: _controlsController!.magnifierFocalPoint,
        offset: const Offset(0, -150),
        leaderAnchor: Alignment.center,
        followerAnchor: Alignment.topLeft,
        // TODO: use controller builder
        // child: _controlsController!.magnifierBuilder(),
        // Theoretically, we should be able to use a leaderAnchor and followerAnchor of "center"
        // and avoid the following FractionalTranslation. However, when centering the follower,
        // we don't get the expect focal point within the magnified area. It's off-center. I'm not
        // sure why that happens, but using a followerAnchor of "topLeft" and then pulling back
        // by 50% solve the problem.
        child: const FractionalTranslation(
          translation: Offset(-0.5, -0.5),
          child: AndroidMagnifyingGlass(
            magnificationScale: 1.5,
            // In theory, the offsetFromFocalPoint should either be `-150` to match the actual
            // offset, or it should be `-150 / magnificationLevel`. Neither of those align the
            // focal point correctly. The following offset was found empirically to give the
            // desired results, no matter how high the magnification.
            offsetFromFocalPoint: Offset(0, -58),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugSelectionFocalPoint() {
    return ValueListenableBuilder(
      valueListenable: _dragHandleSelectionGlobalFocalPoint,
      builder: (context, focalPoint, child) {
        if (focalPoint == null) {
          return const SizedBox();
        }

        return Positioned(
          left: focalPoint.dx,
          top: focalPoint.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Container(
              width: 5,
              height: 5,
              color: Colors.red,
            ),
          ),
        );
      },
    );
  }
}

class AndroidDocumentTouchEditingControls extends StatefulWidget {
  const AndroidDocumentTouchEditingControls({
    Key? key,
    required this.editingController,
    required this.documentKey,
    required this.documentLayout,
    required this.handleColor,
    this.onHandleDragStart,
    this.onHandleDragUpdate,
    this.onHandleDragEnd,
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
    required this.longPressMagnifierGlobalOffset,
    this.showDebugPaint = false,
  }) : super(key: key);

  final AndroidDocumentGestureEditingController editingController;

  final GlobalKey documentKey;

  final DocumentLayout documentLayout;

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// The color of the Android-style drag handles.
  final Color handleColor;

  final void Function(HandleType handleType, Offset globalOffset)? onHandleDragStart;

  final void Function(Offset globalOffset)? onHandleDragUpdate;

  final void Function()? onHandleDragEnd;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final WidgetBuilder popoverToolbarBuilder;

  final ValueNotifier<Offset?> longPressMagnifierGlobalOffset;

  final bool showDebugPaint;

  @override
  State createState() => _AndroidDocumentTouchEditingControlsState();
}

class _AndroidDocumentTouchEditingControlsState extends State<AndroidDocumentTouchEditingControls>
    with SingleTickerProviderStateMixin {
  // These global keys are assigned to each draggable handle to
  // prevent a strange dragging issue.
  //
  // Without these keys, if the user drags into the auto-scroll area
  // of the text field for a period of time, we never receive a
  // "pan end" or "pan cancel" callback. I have no idea why this is
  // the case. These handles sit in an Overlay, so it's not as if they
  // suffered some conflict within a ScrollView. I tried many adjustments
  // to recover the end/cancel callbacks. Finally, I tried adding these
  // global keys based on a hunch that perhaps the gesture detector was
  // somehow getting switched out, or assigned to a different widget, and
  // that was somehow disrupting the callback series. For now, these keys
  // seem to solve the problem.
  final _collapsedHandleKey = GlobalKey();
  final _upstreamHandleKey = GlobalKey();
  final _downstreamHandleKey = GlobalKey();

  bool _isDraggingExpandedHandle = false;
  bool _isDraggingHandle = false;
  Offset? _localDragOffset;

  late BlinkController _caretBlinkController;
  Offset? _prevCaretOffset;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = BlinkController(tickerProvider: this);
    _prevCaretOffset = widget.editingController.caretTop;
    widget.editingController.addListener(_onEditingControllerChange);

    if (widget.editingController.shouldDisplayCollapsedHandle) {
      widget.editingController.startCollapsedHandleAutoHideCountdown();
    }
  }

  @override
  void didUpdateWidget(AndroidDocumentTouchEditingControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editingController != oldWidget.editingController) {
      oldWidget.editingController.removeListener(_onEditingControllerChange);
      widget.editingController.addListener(_onEditingControllerChange);
    }
  }

  @override
  void dispose() {
    widget.editingController.removeListener(_onEditingControllerChange);
    _caretBlinkController.dispose();
    super.dispose();
  }

  void _onEditingControllerChange() {
    if (_prevCaretOffset != widget.editingController.caretTop) {
      if (widget.editingController.caretTop == null) {
        _caretBlinkController.stopBlinking();
      } else {
        _caretBlinkController.jumpToOpaque();
      }

      _prevCaretOffset = widget.editingController.caretTop;
    }
  }

  void _onCollapsedPanStart(DragStartDetails details) {
    editorGesturesLog.fine('_onCollapsedPanStart');

    setState(() {
      _isDraggingExpandedHandle = false;
      _isDraggingHandle = true;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });

    widget.onHandleDragStart?.call(HandleType.collapsed, details.globalPosition);
  }

  void _onUpstreamHandlePanStart(DragStartDetails details) {
    _onExpandedHandleDragStart(details);
    widget.onHandleDragStart?.call(HandleType.upstream, details.globalPosition);
  }

  void _onDownstreamHandlePanStart(DragStartDetails details) {
    _onExpandedHandleDragStart(details);
    widget.onHandleDragStart?.call(HandleType.downstream, details.globalPosition);
  }

  void _onExpandedHandleDragStart(DragStartDetails details) {
    setState(() {
      _isDraggingExpandedHandle = true;
      _isDraggingHandle = true;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    editorGesturesLog.fine('_onPanUpdate');

    widget.onHandleDragUpdate?.call(details.globalPosition);

    setState(() {
      _localDragOffset = _localDragOffset! + details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    editorGesturesLog.fine('_onPanEnd');
    _onHandleDragEnd();
  }

  void _onPanCancel() {
    editorGesturesLog.fine('_onPanCancel');
    _onHandleDragEnd();
  }

  void _onHandleDragEnd() {
    editorGesturesLog.fine('_onHandleDragEnd()');

    // TODO: ensure that extent is visible

    setState(() {
      _isDraggingExpandedHandle = false;
      _isDraggingHandle = false;
      _localDragOffset = null;
    });

    widget.onHandleDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.editingController,
      builder: (context, _) {
        return Padding(
          // Remove the keyboard from the space that we occupy so that
          // clipping calculations apply to the expected visual borders,
          // instead of applying underneath the keyboard.
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRect(
            clipper: widget.createOverlayControlsClipper?.call(context),
            child: SizedBox(
              // ^ SizedBox tries to be as large as possible, because
              // a Stack will collapse into nothing unless something
              // expands it.
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Build the caret
                  _buildCaret(),
                  // Build the drag handles (if desired).
                  // We don't show handles on web because the browser already displays the native handles.
                  if (!isWeb) //
                    ..._buildHandles(),
                  // Build the focal point for the magnifier
                  if (_isDraggingHandle || widget.longPressMagnifierGlobalOffset.value != null)
                    _buildMagnifierFocalPoint(),
                  // Build the magnifier (this needs to be done before building
                  // the handles so that the magnifier doesn't show the handles.
                  // We don't show magnifier on web because the browser already displays the native magnifier.
                  if (!isWeb && widget.editingController.shouldDisplayMagnifier) _buildMagnifier(),
                  // Build the editing toolbar.
                  // We don't show toolbar on web because the browser already displays the native toolbar.
                  if (!isWeb &&
                      widget.editingController.shouldDisplayToolbar &&
                      widget.editingController.isToolbarPositioned)
                    _buildToolbar(context),
                  // Build a UI that's useful for debugging, if desired.
                  if (widget.showDebugPaint)
                    IgnorePointer(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.yellow.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaret() {
    if (!widget.editingController.hasCaret) {
      return const SizedBox();
    }

    return Follower.withOffset(
      link: widget.editingController.selectionLinks.caretLink,
      leaderAnchor: Alignment.topCenter,
      followerAnchor: Alignment.topCenter,
      showWhenUnlinked: false,
      child: IgnorePointer(
        child: BlinkingCaret(
          controller: _caretBlinkController,
          caretOffset: const Offset(0, 0),
          caretHeight: widget.editingController.caretHeight!,
          width: 2,
          color: widget.showDebugPaint ? Colors.green : widget.handleColor,
          borderRadius: BorderRadius.zero,
          isTextEmpty: false,
          showCaret: true,
        ),
      ),
    );
  }

  List<Widget> _buildHandles() {
    if (!widget.editingController.shouldDisplayCollapsedHandle &&
        !widget.editingController.shouldDisplayExpandedHandles) {
      editorGesturesLog.finer('Not building overlay handles because there is no selection');
      // There is no selection. Draw nothing.
      return [];
    }

    if (widget.editingController.shouldDisplayCollapsedHandle && !_isDraggingExpandedHandle) {
      // Note: we don't build the collapsed handle if we're currently dragging
      //       the base or extent because, if we did, then when the user drags
      //       crosses the base and extent, we'd suddenly jump from an expanded
      //       selection to a collapsed selection.
      return [
        _buildCollapsedHandle(),
      ];
    } else {
      return _buildExpandedHandles();
    }
  }

  Widget _buildCollapsedHandle() {
    return _buildHandle(
      handleKey: _collapsedHandleKey,
      handleLink: widget.editingController.selectionLinks.caretLink,
      leaderAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.topCenter,
      handleOffset: const Offset(-0.5, 5), // Chosen experimentally
      handleType: HandleType.collapsed,
      debugColor: Colors.green,
      onPanStart: _onCollapsedPanStart,
    );
  }

  List<Widget> _buildExpandedHandles() {
    return [
      // upstream-bounding (left side of a RTL line of text) handle touch target
      _buildHandle(
        handleKey: _upstreamHandleKey,
        handleLink: widget.editingController.selectionLinks.upstreamLink,
        leaderAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topRight,
        handleOffset: const Offset(0, 2), // Chosen experimentally
        handleType: HandleType.upstream,
        debugColor: Colors.green,
        onPanStart: _onUpstreamHandlePanStart,
      ),
      // downstream-bounding (right side of a RTL line of text) handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        handleLink: widget.editingController.selectionLinks.downstreamLink,
        leaderAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topLeft,
        handleOffset: const Offset(-1, 2), // Chosen experimentally
        handleType: HandleType.downstream,
        debugColor: Colors.red,
        onPanStart: _onDownstreamHandlePanStart,
      ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required LeaderLink handleLink,
    required Alignment leaderAnchor,
    required Alignment followerAnchor,
    Offset? handleOffset,
    Offset handleFractionalTranslation = Offset.zero,
    required HandleType handleType,
    required Color debugColor,
    required void Function(DragStartDetails) onPanStart,
  }) {
    return Follower.withOffset(
      key: handleKey,
      link: handleLink,
      leaderAnchor: leaderAnchor,
      followerAnchor: followerAnchor,
      offset: handleOffset ?? Offset.zero,
      showWhenUnlinked: false,
      child: FractionalTranslation(
        translation: handleFractionalTranslation,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: Container(
            color: widget.showDebugPaint ? Colors.green : Colors.transparent,
            child: AnimatedOpacity(
              opacity: handleType == HandleType.collapsed && widget.editingController.isCollapsedHandleAutoHidden
                  ? 0.0
                  : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AndroidSelectionHandle(
                handleType: handleType,
                color: widget.handleColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMagnifierFocalPoint() {
    late Offset magnifierOffset;
    if (widget.longPressMagnifierGlobalOffset.value != null) {
      // The user is long-pressing, the magnifier should go at the selection
      // extent.
      magnifierOffset = widget.longPressMagnifierGlobalOffset.value!;
    } else {
      // The user is dragging a handle. The magnifier should go wherever the user
      // places his finger.
      //
      // Also, pull the magnifier up a little bit because the Android drag handles
      // sit below the content they refer to.
      magnifierOffset = _localDragOffset! - const Offset(0, 20);
    }

    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.
    return Positioned(
      left: magnifierOffset.dx,
      // TODO: select focal position based on type of content
      top: magnifierOffset.dy,
      child: CompositedTransformTarget(
        link: widget.editingController.magnifierFocalPointLink,
        child: const SizedBox(width: 1, height: 1),
      ),
    );
  }

  Widget _buildMagnifier() {
    // Display a magnifier that tracks a focal point.
    //
    // When the user is dragging an overlay handle, we place a LayerLink
    // target. This magnifier follows that target.
    return Center(
      child: AndroidFollowingMagnifier(
        layerLink: widget.editingController.magnifierFocalPointLink,
        offsetFromFocalPoint: const Offset(0, -72),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    // TODO: figure out why this approach works. Why isn't the text field's
    //       RenderBox offset stale when the keyboard opens or closes? Shouldn't
    //       we end up with the previous offset because no rebuild happens?
    //
    //       Disproven theory: CompositedTransformFollower's link causes a rebuild of its
    //       subtree whenever the linked transform changes.
    //
    //       Theory:
    //         - Keyboard only effects vertical offsets, so global x offset
    //           was never at risk
    //         - The global y offset isn't used in the calculation at all
    //         - If this same approach were used in a situation where the
    //           distance between the left edge of the available space and the
    //           text field changed, I think it would fail.
    return CustomSingleChildLayout(
      delegate: ToolbarPositionDelegate(
        // TODO: handle situation where document isn't full screen
        textFieldGlobalOffset: Offset.zero,
        desiredTopAnchorInTextField: widget.editingController.toolbarTopAnchor!, //toolbarTopAnchor,
        desiredBottomAnchorInTextField: widget.editingController.toolbarBottomAnchor!, //toolbarBottomAnchor,
        screenPadding: widget.editingController.screenPadding,
      ),
      child: IgnorePointer(
        ignoring: !widget.editingController.shouldDisplayToolbar,
        child: AnimatedOpacity(
          opacity: widget.editingController.shouldDisplayToolbar ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Builder(builder: widget.popoverToolbarBuilder),
        ),
      ),
    );
  }
}

class HandleStartDragEvent {
  const HandleStartDragEvent({
    required this.selectionType,
    required this.globalHandleDragStartOffset,
    required this.globalHandleDocPositionRect,
  });

  /// The type of selection that the user started to drag, e.g., collapsed, base, extent.
  final SelectionHandleType selectionType;

  /// The global offset where the user started dragging.
  ///
  /// This offset sits somewhere within the handle that the
  /// user is dragging.
  final Offset globalHandleDragStartOffset;

  /// The global rectangle that contains the content next to
  /// the caret where the handle sits.
  ///
  /// This rectangle encapsulate a character, or an image, etc.
  final Rect globalHandleDocPositionRect;
}

class HandleUpdateDragEvent {
  const HandleUpdateDragEvent({
    required this.selectionType,
    required this.globalHandleDragOffset,
  });

  /// The type of selection that the user started to drag, e.g., collapsed, base, extent.
  final SelectionHandleType selectionType;

  /// The current global offset of the user's pointer during
  /// a handle drag event.
  final Offset globalHandleDragOffset;
}

enum SelectionHandleType {
  collapsed,
  base,
  extent,
}
