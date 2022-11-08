import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_text_layout/super_text_layout.dart';

import 'magnifier.dart';

class IosDocumentTouchEditingControls extends StatefulWidget {
  const IosDocumentTouchEditingControls({
    Key? key,
    required this.editingController,
    required this.floatingCursorController,
    required this.documentLayout,
    required this.document,
    required this.selection,
    required this.handleColor,
    this.onDoubleTapOnCaret,
    this.onTripleTapOnCaret,
    this.onFloatingCursorStart,
    this.onFloatingCursorMoved,
    this.onFloatingCursorStop,
    this.magnifierFocalPointOffset,
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
    this.disableGestureHandling = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final IosDocumentGestureEditingController editingController;

  final Document document;

  final ValueNotifier<DocumentSelection?> selection;

  final FloatingCursorController floatingCursorController;

  final DocumentLayout documentLayout;

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// Color the iOS-style text selection drag handles.
  final Color handleColor;

  /// Callback invoked on iOS when the user double taps on the caret.
  final VoidCallback? onDoubleTapOnCaret;

  /// Callback invoked on iOS when the user triple taps on the caret.
  final VoidCallback? onTripleTapOnCaret;

  /// Callback invoked when the floating cursor becomes visible.
  final VoidCallback? onFloatingCursorStart;

  /// Callback invoked whenever the iOS floating cursor moves to a new
  /// position.
  final void Function(Offset)? onFloatingCursorMoved;

  /// Callback invoked when the floating cursor disappears.
  final VoidCallback? onFloatingCursorStop;

  /// Offset where the magnifier should focus.
  ///
  /// The magnifier is displayed whenever this offset is non-null, otherwise
  /// the magnifier is not shown.
  final Offset? magnifierFocalPointOffset;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final Widget Function(BuildContext) popoverToolbarBuilder;

  /// Disables all gesture interaction for these editing controls,
  /// allowing gestures to pass through these controls to whatever
  /// content currently sits beneath them.
  ///
  /// While this is `true`, the user can't tap or drag on selection
  /// handles or other controls.
  final bool disableGestureHandling;

  final bool showDebugPaint;

  @override
  State createState() => _IosDocumentTouchEditingControlsState();
}

class _IosDocumentTouchEditingControlsState extends State<IosDocumentTouchEditingControls>
    with SingleTickerProviderStateMixin {
  // These global keys are assigned to each draggable handle to
  // prevent a strange dragging issue.
  //
  // Without these keys, if the user drags into the auto-scroll area
  // for a period of time, we never receive a
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

  late BlinkController _caretBlinkController;
  Offset? _prevCaretOffset;

  static const _defaultFloatingCursorHeight = 20.0;
  final _isShowingFloatingCursor = ValueNotifier<bool>(false);
  final _floatingCursorKey = GlobalKey();
  Offset? _initialFloatingCursorOffset;
  final _floatingCursorOffset = ValueNotifier<Offset?>(null);
  double _floatingCursorHeight = _defaultFloatingCursorHeight;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = BlinkController(tickerProvider: this);
    _prevCaretOffset = widget.editingController.caretTop;
    widget.editingController.addListener(_onEditingControllerChange);
    widget.floatingCursorController.addListener(_onFloatingCursorChange);
  }

  @override
  void didUpdateWidget(IosDocumentTouchEditingControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editingController != oldWidget.editingController) {
      oldWidget.editingController.removeListener(_onEditingControllerChange);
      widget.editingController.addListener(_onEditingControllerChange);
    }
    if (widget.floatingCursorController != oldWidget.floatingCursorController) {
      oldWidget.floatingCursorController.removeListener(_onFloatingCursorChange);
      widget.floatingCursorController.addListener(_onFloatingCursorChange);
    }
  }

  @override
  void dispose() {
    widget.floatingCursorController.removeListener(_onFloatingCursorChange);
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

  void _onFloatingCursorChange() {
    if (widget.floatingCursorController.offset == null) {
      if (_floatingCursorOffset.value != null) {
        _isShowingFloatingCursor.value = false;

        _caretBlinkController.startBlinking();

        _initialFloatingCursorOffset = null;
        _floatingCursorOffset.value = null;
        _floatingCursorHeight = _defaultFloatingCursorHeight;

        widget.onFloatingCursorStop?.call();
      }

      return;
    }

    if (widget.selection.value == null) {
      // The floating cursor doesn't mean anything when nothing is selected.
      return;
    }

    if (!widget.selection.value!.isCollapsed) {
      // The selection is expanded. First we need to collapse it, then
      // we can start showing the floating cursor.
      widget.selection.value = widget.selection.value!.collapseDownstream(widget.document);
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _onFloatingCursorChange();
      });
    }

    if (_floatingCursorOffset.value == null) {
      // The floating cursor just started.
      widget.onFloatingCursorStart?.call();
    }

    _caretBlinkController.stopBlinking();
    widget.editingController.hideToolbar();
    widget.editingController.hideMagnifier();

    _initialFloatingCursorOffset ??=
        widget.editingController.caretTop! + const Offset(-1, 0) + Offset(0, widget.editingController.caretHeight! / 2);
    _floatingCursorOffset.value = _initialFloatingCursorOffset! + widget.floatingCursorController.offset!;

    final nearestDocPosition = widget.documentLayout.getDocumentPositionNearestToOffset(_floatingCursorOffset.value!)!;
    if (nearestDocPosition.nodePosition is TextNodePosition) {
      final nearestComponent = widget.documentLayout.getComponentByNodeId(nearestDocPosition.nodeId)!;
      _floatingCursorHeight = nearestComponent.getRectForPosition(nearestDocPosition.nodePosition).height;
    } else {
      final nearestComponent = widget.documentLayout.getComponentByNodeId(nearestDocPosition.nodeId)!;
      _floatingCursorHeight = (nearestComponent.context.findRenderObject() as RenderBox).size.height;
    }

    widget.onFloatingCursorMoved?.call(_floatingCursorOffset.value!);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.editingController,
        builder: (context) {
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
                    // Build caret or drag handles
                    ..._buildHandles(),
                    // Build the floating cursor
                    _buildFloatingCursor(),
                    // Build the editing toolbar
                    if (widget.editingController.shouldDisplayToolbar && widget.editingController.isToolbarPositioned)
                      _buildToolbar(),
                    // Build the focal point for the magnifier
                    if (widget.magnifierFocalPointOffset != null) _buildMagnifierFocalPoint(),
                    // Build the magnifier
                    if (widget.editingController.shouldDisplayMagnifier) _buildMagnifier(),
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
        });
  }

  List<Widget> _buildHandles() {
    if (!widget.editingController.shouldDisplayCollapsedHandle &&
        !widget.editingController.shouldDisplayExpandedHandles) {
      editorGesturesLog.finer('Not building overlay handles because they aren\'t desired');
      return [];
    }

    if (widget.editingController.shouldDisplayCollapsedHandle) {
      return [
        _buildCollapsedHandle(),
      ];
    } else {
      return _buildExpandedHandles();
    }
  }

  Widget _buildCollapsedHandle() {
    return _buildHandleOld(
      handleKey: _collapsedHandleKey,
      handleType: HandleType.collapsed,
      debugColor: Colors.blue,
    );
  }

  List<Widget> _buildExpandedHandles() {
    return [
      // Left-bounding handle touch target
      _buildHandleOld(
        handleKey: _upstreamHandleKey,
        handleType: HandleType.upstream,
        debugColor: Colors.green,
      ),
      // right-bounding handle touch target
      _buildHandleOld(
        handleKey: _downstreamHandleKey,
        handleType: HandleType.downstream,
        debugColor: Colors.red,
      ),
    ];
  }

  Widget _buildHandleOld({
    required Key handleKey,
    required HandleType handleType,
    required Color debugColor,
  }) {
    const ballDiameter = 8.0;

    late Widget handle;
    late Offset handleOffset;
    switch (handleType) {
      case HandleType.collapsed:
        handleOffset = widget.editingController.caretTop! + const Offset(-1, 0);
        handle = ValueListenableBuilder<bool>(
          valueListenable: _isShowingFloatingCursor,
          builder: (context, isShowingFloatingCursor, child) {
            return IOSCollapsedHandle(
              controller: _caretBlinkController,
              color: isShowingFloatingCursor ? Colors.grey : widget.handleColor,
              caretHeight: widget.editingController.caretHeight!,
            );
          },
        );
        break;
      case HandleType.upstream:
        handleOffset = widget.editingController.upstreamHandleOffset! -
            Offset(0, widget.editingController.upstreamCaretHeight!) +
            const Offset(-ballDiameter / 2, -3 * ballDiameter / 4);
        handle = IOSSelectionHandle.upstream(
          color: widget.handleColor,
          handleType: handleType,
          caretHeight: widget.editingController.upstreamCaretHeight!,
          ballRadius: ballDiameter / 2,
        );
        break;
      case HandleType.downstream:
        handleOffset = widget.editingController.downstreamHandleOffset! -
            Offset(0, widget.editingController.downstreamCaretHeight!) +
            const Offset(-ballDiameter / 2, -3 * ballDiameter / 4);
        handle = IOSSelectionHandle.upstream(
          color: widget.handleColor,
          handleType: handleType,
          caretHeight: widget.editingController.downstreamCaretHeight!,
          ballRadius: ballDiameter / 2,
        );
        break;
    }

    return _buildHandle(
      handleKey: handleKey,
      handleOffset: handleOffset,
      handle: handle,
      debugColor: debugColor,
    );
  }

  Widget _buildHandle({
    required Key handleKey,
    required Offset handleOffset,
    required Widget handle,
    required Color debugColor,
  }) {
    return CompositedTransformFollower(
      key: handleKey,
      link: widget.editingController.documentLayoutLink,
      offset: handleOffset + const Offset(-5, 0),
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          color: widget.showDebugPaint ? Colors.green : Colors.transparent,
          child: handle,
        ),
      ),
    );
  }

  Widget _buildFloatingCursor() {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _floatingCursorOffset,
      builder: (context, floatingCursorOffset, child) {
        if (floatingCursorOffset == null) {
          return const SizedBox();
        }

        return _buildHandle(
          handleKey: _floatingCursorKey,
          handleOffset: floatingCursorOffset - Offset(0, _floatingCursorHeight / 2),
          handle: Container(
            width: 2,
            height: _floatingCursorHeight,
            color: Colors.red.withOpacity(0.75),
          ),
          debugColor: Colors.blue,
        );
      },
    );
  }

  Widget _buildMagnifierFocalPoint() {
    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.
    return Positioned(
      left: widget.magnifierFocalPointOffset!.dx,
      top: widget.magnifierFocalPointOffset!.dy,
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
      child: IOSFollowingMagnifier.roundedRectangle(
        layerLink: widget.editingController.magnifierFocalPointLink,
        offsetFromFocalPoint: const Offset(0, -72),
      ),
    );
  }

  Widget _buildToolbar() {
    // TODO: figure out why this approach works. Why isn't the text field's
    //       RenderBox offset stale when the keyboard opens or closes? Shouldn't
    //       we end up with the previous offset because no rebuild happens?
    //
    //       Dis-proven theory: CompositedTransformFollower's link causes a rebuild of its
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
        desiredTopAnchorInTextField: widget.editingController.toolbarTopAnchor!,
        desiredBottomAnchorInTextField: widget.editingController.toolbarBottomAnchor!,
      ),
      child: IgnorePointer(
        ignoring: !widget.editingController.shouldDisplayToolbar,
        child: AnimatedOpacity(
          opacity: widget.editingController.shouldDisplayToolbar ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Builder(builder: (context) {
            return widget.popoverToolbarBuilder(context);
          }),
        ),
      ),
    );
  }
}

/// Controls the display of drag handles, a magnifier, and a
/// floating toolbar, assuming iOS-style behavior for the
/// handles.
class IosDocumentGestureEditingController extends MagnifierAndToolbarController {
  IosDocumentGestureEditingController({
    required LayerLink documentLayoutLink,
    required LayerLink magnifierFocalPointLink,
  })  : _documentLayoutLink = documentLayoutLink,
        super(magnifierFocalPointLink: magnifierFocalPointLink);

  /// Layer link that's aligned to the top-left corner of the document layout.
  ///
  /// Some of the offsets reported by this controller are based on the
  /// document layout coordinate space. Therefore, to honor those offsets on
  /// the screen, this `LayerLink` should be used to align the controls with
  /// the document layout before applying the offset that sits within the
  /// document layout.
  LayerLink get documentLayoutLink => _documentLayoutLink;
  final LayerLink _documentLayoutLink;

  /// Whether or not a caret should be displayed.
  bool get hasCaret => caretTop != null;

  /// The offset of the top of the caret, or `null` if no caret should
  /// be displayed.
  ///
  /// When the caret is drawn, the caret will have a thickness. That width
  /// should be placed either on the left or right of this offset, based on
  /// whether the [caretAffinity] is upstream or downstream, respectively.
  Offset? get caretTop => _caretTop;
  Offset? _caretTop;

  /// The height of the caret, or `null` if no caret should be displayed.
  double? get caretHeight => _caretHeight;
  double? _caretHeight;

  /// Updates the caret's size and position.
  ///
  /// The [top] offset is in the document layout's coordinate space.
  void updateCaret({
    Offset? top,
    double? height,
  }) {
    bool changed = false;
    if (top != null) {
      _caretTop = top;
      changed = true;
    }
    if (height != null) {
      _caretHeight = height;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Removes the caret from the display.
  void removeCaret() {
    if (!hasCaret) {
      return;
    }

    _caretTop = null;
    _caretHeight = null;
    notifyListeners();
  }

  /// Whether a collapsed handle should be displayed.
  bool get shouldDisplayCollapsedHandle => _collapsedHandleOffset != null;

  /// The offset of the collapsed handle focal point, within the coordinate space
  /// of the document layout, or `null` if no collapsed handle should be displayed.
  Offset? get collapsedHandleOffset => _collapsedHandleOffset;
  Offset? _collapsedHandleOffset;
  set collapsedHandleOffset(Offset? offset) {
    if (offset != _collapsedHandleOffset) {
      _collapsedHandleOffset = offset;
      notifyListeners();
    }
  }

  /// Whether the expanded handles (base + extent) should be displayed.
  bool get shouldDisplayExpandedHandles => _upstreamHandleOffset != null && _downstreamHandleOffset != null;

  double? get upstreamCaretHeight => _upstreamCaretHeight;
  double? _upstreamCaretHeight;
  set upstreamCaretHeight(double? height) {
    if (height != _upstreamCaretHeight) {
      _upstreamCaretHeight = height;
      notifyListeners();
    }
  }

  /// The offset of the upstream handle focal point, within the coordinate space
  /// of the document layout, or `null` if no upstream handle should be displayed.
  Offset? get upstreamHandleOffset => _upstreamHandleOffset;
  Offset? _upstreamHandleOffset;
  set upstreamHandleOffset(Offset? offset) {
    if (offset != _upstreamHandleOffset) {
      _upstreamHandleOffset = offset;
      notifyListeners();
    }
  }

  double? get downstreamCaretHeight => _downstreamCaretHeight;
  double? _downstreamCaretHeight;
  set downstreamCaretHeight(double? height) {
    if (height != _downstreamCaretHeight) {
      _downstreamCaretHeight = height;
      notifyListeners();
    }
  }

  /// The offset of the downstream handle focal point, within the coordinate space
  /// of the document layout, or `null` if no downstream handle should be displayed.
  Offset? get downstreamHandleOffset => _downstreamHandleOffset;
  Offset? _downstreamHandleOffset;
  set downstreamHandleOffset(Offset? offset) {
    if (offset != _downstreamHandleOffset) {
      _downstreamHandleOffset = offset;
      notifyListeners();
    }
  }
}

class FloatingCursorController with ChangeNotifier {
  Offset? get offset => _offset;
  Offset? _offset;
  set offset(Offset? newOffset) {
    if (newOffset == _offset) {
      return;
    }
    _offset = newOffset;
    notifyListeners();
  }
}
