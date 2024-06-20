import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';
import 'package:super_editor/src/infrastructure/multi_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/selection_handles.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';
import 'package:super_editor/src/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/platforms/ios/magnifier.dart';
import 'package:super_editor/src/super_textfield/super_textfield.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../metrics.dart';

final _log = iosTextFieldLog;

/// Overlay editing controls for an iOS-style text field.
///
/// [IOSEditingControls] is intended to be displayed in the app's
/// [Overlay] so that its controls appear on top of everything else
/// in the app.
///
/// The given [IOSEditingOverlayController] controls the presentation
/// of [IOSEditingControls]. Use the controller to show/hide the
/// iOS-style toolbar, magnifier, and expanded selection handles.
class IOSEditingControls extends StatefulWidget {
  const IOSEditingControls({
    Key? key,
    required this.editingController,
    required this.textScrollController,
    required this.textFieldKey,
    required this.textContentKey,
    required this.textFieldLayerLink,
    required this.textContentLayerLink,
    this.tapRegionGroupId,
    required this.handleColor,
    required this.popoverToolbarBuilder,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// Controller that determines whether the toolbar,
  /// magnifier, and/or selection handles are visible in
  /// this [IOSEditingControls].
  final IOSEditingOverlayController editingController;

  /// Controller that auto-scrolls text based on handle
  /// location.
  final TextScrollController textScrollController;

  /// [LayerLink] that is anchored to the text field's boundary.
  final LayerLink textFieldLayerLink;

  /// [GlobalKey] that references the overall text field, i.e.,
  /// the viewport that contains text that's (possibly) larger
  /// than the visible area.
  final GlobalKey textFieldKey;

  /// [LayerLink] that is anchored to the (possibly scrolling) content
  /// within the text field.
  final LayerLink textContentLayerLink;

  /// [GlobalKey] that references the widget that contains the field's
  /// text.
  final GlobalKey<ProseTextState> textContentKey;

  /// A group ID for [TapRegion]s that surround each overlay widget, e.g.,
  /// drag handles.
  final String? tapRegionGroupId;

  /// The color of the selection handles.
  final Color handleColor;

  /// Whether to paint debug guides.
  final bool showDebugPaint;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final Widget Function(BuildContext, IOSEditingOverlayController) popoverToolbarBuilder;

  @override
  State createState() => _IOSEditingControlsState();
}

class _IOSEditingControlsState extends State<IOSEditingControls>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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
  final _upstreamHandleKey = GlobalKey();
  final _downstreamHandleKey = GlobalKey();

  bool _isDraggingBase = false;
  bool _isDraggingExtent = false;
  Offset? _globalDragOffset;
  Offset? _localDragOffset;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    widget.editingController.textController.addListener(_rebuildOnNextFrame);
  }

  @override
  void didUpdateWidget(IOSEditingControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.editingController != oldWidget.editingController) {
      oldWidget.editingController.textController.removeListener(_rebuildOnNextFrame);
      widget.editingController.textController.addListener(_rebuildOnNextFrame);
    }
  }

  @override
  void dispose() {
    widget.editingController.textController.removeListener(_rebuildOnNextFrame);

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The available screen dimensions may have changed, e.g., due to keyboard
    // appearance/disappearance. Reflow the layout. Use a post-frame callback
    // to give the rest of the UI a chance to reflow, first.
    scheduleBuildAfterBuild();
  }

  ProseTextLayout get _textLayout => widget.textContentKey.currentState!.textLayout;

  void _rebuildOnNextFrame() {
    // We request a rebuild at the end of this frame so that the editing
    // controls update their position to reflect changes to text styling,
    // e.g., text that gets wider because it was bolded.
    scheduleBuildAfterBuild();
  }

  void _onBasePanStart(DragStartDetails details) {
    _log.fine('_onBasePanStart');

    _onHandleDragStart(details);

    setState(() {
      _isDraggingBase = true;
      _isDraggingExtent = false;
      _globalDragOffset = details.globalPosition;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onExtentPanStart(DragStartDetails details) {
    _log.fine('_onExtentPanStart');

    _onHandleDragStart(details);

    setState(() {
      _isDraggingBase = false;
      _isDraggingExtent = true;
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onHandleDragStart(DragStartDetails details) {
    _log.fine('_onHandleDragStart()');

    widget.editingController.hideToolbar();

    widget.textScrollController.updateAutoScrollingForTouchOffset(
      userInteractionOffsetInViewport:
          (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(details.globalPosition),
    );
    widget.textScrollController.addListener(_updateSelectionForNewDragHandleLocation);

    if (widget.editingController.textController.selection.isCollapsed) {
      // The user is dragging the handle. Stop the caret from blinking while dragging.
      widget.editingController.stopCaretBlinking();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Must set global drag offset before _updateSelectionForNewDragHandleLocation()
    _globalDragOffset = details.globalPosition;
    _updateSelectionForNewDragHandleLocation();

    widget.textScrollController.updateAutoScrollingForTouchOffset(
      userInteractionOffsetInViewport:
          (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(details.globalPosition),
    );

    setState(() {
      _localDragOffset = _localDragOffset! + details.delta;
      widget.editingController.showMagnifier(_localDragOffset!);
    });
  }

  void _updateSelectionForNewDragHandleLocation() {
    final textBox = (widget.textContentKey.currentContext!.findRenderObject() as RenderBox);
    final textOffset = textBox.globalToLocal(_globalDragOffset!);
    final textLayout = _textLayout;
    if (_isDraggingBase) {
      widget.editingController.textController.selection = widget.editingController.textController.selection.copyWith(
        baseOffset: textLayout.getPositionNearestToOffset(textOffset).offset,
      );
    } else if (_isDraggingExtent) {
      widget.editingController.textController.selection = widget.editingController.textController.selection.copyWith(
        extentOffset: textLayout.getPositionNearestToOffset(textOffset).offset,
      );
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _log.fine('_onPanEnd');
    _onHandleDragEnd();
  }

  void _onPanCancel() {
    _log.fine('_onPanCancel');
    _onHandleDragEnd();
  }

  void _onHandleDragEnd() {
    _log.fine('_onHandleDragEnd()');
    widget.textScrollController.stopScrolling();
    widget.textScrollController.removeListener(_updateSelectionForNewDragHandleLocation);

    // TODO: ensure that extent is visible

    setState(() {
      _isDraggingBase = false;
      _isDraggingExtent = false;
      widget.editingController.hideMagnifier();

      if (!widget.editingController.textController.selection.isCollapsed) {
        widget.editingController.showToolbar();
      } else {
        // The user stopped dragging a handle and the selection is collapsed.
        // Start the caret blinking again.
        widget.editingController.startCaretBlinking();
      }
    });
  }

  Offset _textPositionToViewportOffset(TextPosition position) {
    final textOffset = _textLayout.getOffsetAtPosition(position);
    final globalOffset =
        (widget.textContentKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(textOffset);
    return (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(globalOffset);
  }

  Offset _textOffsetToViewportOffset(Offset textOffset) {
    final globalOffset =
        (widget.textContentKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(textOffset);
    return (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(globalOffset);
  }

  Offset _textPositionToTextOffset(TextPosition position) {
    return _textLayout.getOffsetAtPosition(position);
  }

  @override
  Widget build(BuildContext context) {
    final textFieldRenderObject = context.findRenderObject();
    if (textFieldRenderObject == null) {
      scheduleBuildAfterBuild();
      return const SizedBox();
    }

    return MultiListenableBuilder(
        listenables: {
          widget.editingController,
        },
        builder: (context) {
          return Stack(
            children: [
              // Build the base and extent draggable handles
              ..._buildDraggableOverlayHandles(),
              // Build the editing toolbar
              _buildToolbar(),
              // Build the magnifier
              _buildMagnifier(),
            ],
          );
        });
  }

  Widget _buildToolbar() {
    if (widget.editingController.textController.selection.extentOffset < 0) {
      return const SizedBox();
    }

    if (!widget.editingController.isToolbarVisible) {
      return const SizedBox();
    }

    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    if (widget.editingController.textController.selection.isCollapsed) {
      final extentOffsetInViewport =
          _textPositionToViewportOffset(widget.editingController.textController.selection.extent);
      final lineHeight = _textLayout.getLineHeightAtPosition(widget.editingController.textController.selection.extent);

      toolbarTopAnchor = extentOffsetInViewport - const Offset(0, gapBetweenToolbarAndContent);
      toolbarBottomAnchor =
          extentOffsetInViewport + Offset(0, lineHeight) + const Offset(0, gapBetweenToolbarAndContent);
    } else {
      final selectionBoxes = _textLayout.getBoxesForSelection(widget.editingController.textController.selection);
      Rect selectionBounds = selectionBoxes.first.toRect();
      for (int i = 1; i < selectionBoxes.length; ++i) {
        selectionBounds = selectionBounds.expandToInclude(selectionBoxes[i].toRect());
      }
      final selectionTopInText = selectionBounds.topCenter;
      final selectionTopInViewport = _textOffsetToViewportOffset(selectionTopInText);
      toolbarTopAnchor = selectionTopInViewport - const Offset(0, gapBetweenToolbarAndContent);

      final selectionBottomInText = selectionBounds.bottomCenter;
      final selectionBottomInViewport = _textOffsetToViewportOffset(selectionBottomInText);
      toolbarBottomAnchor = selectionBottomInViewport + const Offset(0, gapBetweenToolbarAndContent);
    }

    // The selection might start above the visible area in a scrollable
    // text field. In that case, we don't want the toolbar to sit more
    // than [gapBetweenToolbarAndContent] above the text field.
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      max(
        toolbarTopAnchor.dy,
        -gapBetweenToolbarAndContent,
      ),
    );

    // The selection might end below the visible area in a scrollable
    // text field. In that case, we don't want the toolbar to sit more
    // than [gapBetweenToolbarAndContent] below the text field.
    final viewportHeight = (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).size.height;
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      min(
        toolbarTopAnchor.dy,
        viewportHeight + gapBetweenToolbarAndContent,
      ),
    );

    final textFieldRenderBox = (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox);

    final textFieldGlobalOffset = textFieldRenderBox.localToGlobal(Offset.zero);

    widget.editingController.overlayController.positionToolbar(
      topAnchor: textFieldRenderBox.localToGlobal(toolbarTopAnchor),
      bottomAnchor: textFieldRenderBox.localToGlobal(toolbarBottomAnchor),
    );

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
        textFieldGlobalOffset: textFieldGlobalOffset,
        desiredTopAnchorInTextField: toolbarTopAnchor,
        desiredBottomAnchorInTextField: toolbarBottomAnchor,
      ),
      child: IgnorePointer(
        ignoring: !widget.editingController.isToolbarVisible,
        child: AnimatedOpacity(
          opacity: widget.editingController.isToolbarVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: TapRegion(
            groupId: widget.tapRegionGroupId,
            child: Builder(builder: (context) {
              return widget.popoverToolbarBuilder(context, widget.editingController);
            }),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDraggableOverlayHandles() {
    if (widget.editingController.textController.selection.extentOffset < 0) {
      _log.finer('Not building expanded handles because there is no selection');
      // There is no selection. Draw nothing.
      return [];
    }

    if (widget.editingController.textController.selection.isCollapsed && !_isDraggingBase && !_isDraggingExtent) {
      // iOS does not display a drag handle when the selection is collapsed.
      return [];
    }

    // The selection is expanded. Draw 2 drag handles.
    // TODO: handle the case with no text affinity and then query widget.selection!.affinity
    // TODO: handle RTL text orientation
    final selectionDirection = widget.editingController.textController.selection.extentOffset >=
            widget.editingController.textController.selection.baseOffset
        ? TextAffinity.downstream
        : TextAffinity.upstream;

    final upstreamTextPosition = selectionDirection == TextAffinity.downstream
        ? widget.editingController.textController.selection.base
        : widget.editingController.textController.selection.extent;

    final downstreamTextPosition = selectionDirection == TextAffinity.downstream
        ? widget.editingController.textController.selection.extent
        : widget.editingController.textController.selection.base;

    late final Offset upstreamHandleOffsetInText;
    late final double upstreamLineHeight;

    late final Offset downstreamHandleOffsetInText;
    late final double downstreamLineHeight;

    final selectionBoxes = _textLayout.getBoxesForSelection(widget.editingController.textController.selection);
    if (selectionBoxes.isEmpty) {
      // It's not documented if getBoxesForSelection is guaranteed to return a non-empty list. Therefore,
      // fallback to using character box to get the handle's offset and height.
      upstreamHandleOffsetInText = _textPositionToTextOffset(upstreamTextPosition);
      upstreamLineHeight =
          _textLayout.getCharacterBox(upstreamTextPosition)?.toRect().height ?? _textLayout.estimatedLineHeight;

      downstreamHandleOffsetInText = _textPositionToTextOffset(downstreamTextPosition);
      downstreamLineHeight =
          _textLayout.getCharacterBox(downstreamTextPosition)?.toRect().height ?? _textLayout.estimatedLineHeight;
    } else {
      final upstreamSelectionBox = selectionBoxes.first;
      final downstreamSelectionBox = selectionBoxes.last;

      upstreamHandleOffsetInText = Offset(upstreamSelectionBox.left, upstreamSelectionBox.top);
      upstreamLineHeight = upstreamSelectionBox.bottom - upstreamSelectionBox.top;

      downstreamHandleOffsetInText = Offset(downstreamSelectionBox.right, downstreamSelectionBox.top);
      downstreamLineHeight = downstreamSelectionBox.bottom - downstreamSelectionBox.top;
    }

    if (upstreamLineHeight == 0 || downstreamLineHeight == 0) {
      _log.finer('Not building expanded handles because the text layout reported a zero line-height');
      // A line height of zero indicates that the text isn't laid out yet.
      // Schedule a rebuild to give the text a frame to layout.
      _scheduleRebuildBecauseTextIsNotLaidOutYet();
      return [];
    }

    final showUpstreamHandle = widget.textScrollController.isTextPositionVisible(upstreamTextPosition);
    final showDownstreamHandle = widget.textScrollController.isTextPositionVisible(downstreamTextPosition);

    return [
      // Left-bounding handle touch target
      _buildHandle(
        handleKey: _upstreamHandleKey,
        followerOffset: upstreamHandleOffsetInText,
        lineHeight: upstreamLineHeight,
        showHandle: showUpstreamHandle,
        isUpstreamHandle: true,
        debugColor: Colors.green,
        onPanStart: selectionDirection == TextAffinity.downstream ? _onBasePanStart : _onExtentPanStart,
      ),
      // right-bounding handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        followerOffset: downstreamHandleOffsetInText,
        lineHeight: downstreamLineHeight,
        showHandle: showDownstreamHandle,
        isUpstreamHandle: false,
        debugColor: Colors.red,
        onPanStart: selectionDirection == TextAffinity.downstream ? _onExtentPanStart : _onBasePanStart,
      ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required Offset followerOffset,
    required double lineHeight,
    required bool showHandle,
    required bool isUpstreamHandle,
    required Color debugColor,
    required void Function(DragStartDetails) onPanStart,
  }) {
    final ballRadius = defaultIosHandleBallDiameter / 2;

    return CompositedTransformFollower(
      key: handleKey,
      link: widget.textContentLayerLink,
      offset: followerOffset,
      child: Transform.translate(
        offset: Offset(
          -12,
          -selectionHighlightBoxVerticalExpansion +
              (isUpstreamHandle
                  // For the upstream handle, the ball is displayed above the text, partially
                  // overlapping the selected area. Move the ball up so it's positioned above the selected area,
                  // and add half of the radius to make the ball overlap with the selected area.
                  ? -defaultIosHandleBallDiameter + (ballRadius / 2)
                  : 0),
        ),
        child: TapRegion(
          groupId: widget.tapRegionGroupId,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: Container(
              width: 24,
              color: widget.showDebugPaint ? Colors.green : Colors.transparent,
              child: showHandle
                  ? isUpstreamHandle
                      ? IOSSelectionHandle.upstream(
                          ballRadius: ballRadius,
                          color: widget.handleColor,
                          caretHeight: lineHeight,
                        )
                      : IOSSelectionHandle.downstream(
                          ballRadius: ballRadius,
                          color: widget.handleColor,
                          caretHeight: lineHeight,
                        )
                  : const SizedBox(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMagnifier() {
    // Display a magnifier that tracks a focal point.
    //
    // When the user is dragging an overlay handle, we also place
    // the LayerLink target where we want it.
    //
    // When some other interaction wants to show the magnifier, then
    // that other area of the widget tree is responsible for
    // positioning the LayerLink target.
    return ValueListenableBuilder(
      valueListenable: widget.editingController.shouldShowMagnifier,
      builder: (context, showMagnifier, child) {
        return IOSFollowingMagnifier.roundedRectangle(
          leaderLink: widget.editingController.magnifierFocalPoint,
          show: showMagnifier,
          // The bottom of the magnifier sits above the focal point.
          // Leave a few pixels between the bottom of the magnifier and the focal point. This
          // value was chosen empirically.
          offsetFromFocalPoint: const Offset(0, -20),
        );
      },
    );
  }

  void _scheduleRebuildBecauseTextIsNotLaidOutYet() {
    scheduleBuildAfterBuild();
  }
}

class IOSEditingOverlayController with ChangeNotifier {
  IOSEditingOverlayController({
    required this.textController,
    required this.caretBlinkController,
    required LeaderLink toolbarFocalPoint,
    required LeaderLink magnifierFocalPoint,
    required this.overlayController,
  })  : _toolbarFocalPoint = toolbarFocalPoint,
        _magnifierFocalPoint = magnifierFocalPoint {
    overlayController.addListener(_overlayControllerChanged);
  }

  @override
  void dispose() {
    overlayController.removeListener(_overlayControllerChanged);
    super.dispose();
  }

  bool get isToolbarVisible => overlayController.shouldDisplayToolbar;

  /// The [AttributedTextEditingController] controlling the text
  /// and selection within the text field with which this
  /// [IOSEditingOverlayController] is associated.
  ///
  /// The purpose of an [IOSEditingOverlayController] is to control
  /// the presentation of UI controls related to text editing. These
  /// controls don't make sense without some underlying text and
  /// selection. Those properties and behaviors are represented by
  /// this [textController].
  final AttributedTextEditingController textController;

  final BlinkController caretBlinkController;

  /// Starts the text field caret blinking.
  void startCaretBlinking() {
    caretBlinkController.startBlinking();
  }

  /// Stops the text field caret blinking.
  void stopCaretBlinking() {
    caretBlinkController.stopBlinking();
  }

  /// Shows, hides, and positions a floating toolbar and magnifier.
  final MagnifierAndToolbarController overlayController;

  LeaderLink get toolbarFocalPoint => _toolbarFocalPoint;
  final LeaderLink _toolbarFocalPoint;

  void toggleToolbar() {
    overlayController.toggleToolbar();
  }

  void showToolbar() {
    overlayController.showToolbar();
  }

  void hideToolbar() {
    overlayController.hideToolbar();
  }

  LeaderLink get magnifierFocalPoint => _magnifierFocalPoint;
  final LeaderLink _magnifierFocalPoint;

  bool get isMagnifierVisible => overlayController.shouldDisplayMagnifier;
  final ValueNotifier<bool> _shouldShowMagnifier = ValueNotifier<bool>(false);
  ValueListenable<bool> get shouldShowMagnifier => _shouldShowMagnifier;

  void showMagnifier(Offset globalOffset) {
    overlayController.showMagnifier();
  }

  void hideMagnifier() {
    overlayController.hideMagnifier();
  }

  bool _areSelectionHandlesVisible = false;
  bool get areSelectionHandlesVisible => _areSelectionHandlesVisible;

  void showSelectionHandles() {
    _areSelectionHandlesVisible = true;
    notifyListeners();
  }

  void hideSelectionHandles() {
    _areSelectionHandlesVisible = false;
    notifyListeners();
  }

  void _overlayControllerChanged() {
    _shouldShowMagnifier.value = overlayController.shouldDisplayMagnifier;
    notifyListeners();
  }
}
