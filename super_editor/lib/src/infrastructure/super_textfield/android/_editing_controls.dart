import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/android/magnifier.dart';
import 'package:super_editor/src/infrastructure/super_textfield/android/android_textfield.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/attributed_text_editing_controller.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/text_scrollview.dart';
import 'package:super_editor/src/infrastructure/super_textfield/infrastructure/toolbar_position_delegate.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';
import 'package:super_text/super_selectable_text.dart';

final _log = androidTextFieldLog;

/// Overlay editing controls for an Android-style text field.
///
/// [AndroidEditingOverlayControls] is intended to be displayed in the app's
/// [Overlay] so that its controls appear on top of everything else
/// in the app.
///
/// The given [AndroidEditingOverlayController] controls the presentation
/// of [AndroidEditingOverlayControls]. Use the controller to show/hide the
/// Android-style toolbar, magnifier, and expanded selection handles.
class AndroidEditingOverlayControls extends StatefulWidget {
  const AndroidEditingOverlayControls({
    Key? key,
    required this.editingController,
    required this.textScrollController,
    required this.textFieldKey,
    required this.textContentKey,
    required this.textFieldLayerLink,
    required this.textContentLayerLink,
    required this.handleColor,
    required this.popoverToolbarBuilder,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// Controller that determines whether the toolbar,
  /// magnifier, and/or selection handles are visible in
  /// this [AndroidEditingOverlayControls].
  final AndroidEditingOverlayController editingController;

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

  /// [GlobalKey] that references the [SuperSelectableTextState] within
  /// the text field.
  final GlobalKey<SuperSelectableTextState> textContentKey;

  /// The color of the selection handles.
  final Color handleColor;

  /// Whether to paint debug guides.
  final bool showDebugPaint;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final Widget Function(BuildContext, AndroidEditingOverlayController) popoverToolbarBuilder;

  @override
  _AndroidEditingOverlayControlsState createState() => _AndroidEditingOverlayControlsState();
}

class _AndroidEditingOverlayControlsState extends State<AndroidEditingOverlayControls> with WidgetsBindingObserver {
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

  bool _isDraggingCollapsed = false;
  bool _isDraggingBase = false;
  bool _isDraggingExtent = false;
  Offset? _globalDragOffset;
  Offset? _localDragOffset;
  // The offset between where the user touched the drag handle and
  // the vertical middle of the line of text that contains the
  // text position. We need this small offset because on Android the
  // handle appears below the selected line of text, not within the
  // line of text.
  Offset? _touchHandleOffsetFromLineOfText;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    widget.editingController.textController.addListener(_rebuildOnNextFrame);
  }

  @override
  void didUpdateWidget(AndroidEditingOverlayControls oldWidget) {
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
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        setState(() {
          // no-op
        });
      }
    });
  }

  void _rebuildOnNextFrame() {
    // We request a rebuild at the end of this frame so that the editing
    // controls update their position to reflect changes to text styling,
    // e.g., text that gets wider because it was bolded.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onCollapsedPanStart(DragStartDetails details) {
    _log.fine('_onCollapsedPanStart');

    widget.editingController
      ..hideToolbar()
      ..cancelCollapsedHandleAutoHideCountdown();

    // TODO: de-dup the calculation of the mid-line focal point
    final globalOffsetInMiddleOfLine =
        _getGlobalOffsetOfMiddleOfLine(widget.editingController.textController.selection.extent);
    _touchHandleOffsetFromLineOfText = globalOffsetInMiddleOfLine - details.globalPosition;

    // TODO: de-dup the repeated calculations of the effective focal point: globalPosition + _touchHandleOffsetFromLineOfText
    widget.textScrollController.updateAutoScrollingForTouchOffset(
      userInteractionOffsetInViewport: (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(globalOffsetInMiddleOfLine),
    );
    widget.textScrollController.addListener(_updateSelectionForNewDragHandleLocation);

    setState(() {
      _isDraggingCollapsed = true;
      _isDraggingBase = false;
      _isDraggingExtent = false;
      _globalDragOffset = details.globalPosition;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onBasePanStart(DragStartDetails details) {
    _log.fine('_onBasePanStart');

    // TODO: de-dup the calculation of the mid-line focal point
    final globalOffsetInMiddleOfLine =
        _getGlobalOffsetOfMiddleOfLine(widget.editingController.textController.selection.base);
    _touchHandleOffsetFromLineOfText = globalOffsetInMiddleOfLine - details.globalPosition;
    _log.fine(' - global offset in middle of line: $globalOffsetInMiddleOfLine');

    widget.editingController
      ..hideToolbar()
      ..cancelCollapsedHandleAutoHideCountdown();
    _log.fine(' - hid the toolbar, cancelled countdown timer');

    // TODO: de-dup the repeated calculations of the effective focal point: globalPosition + _touchHandleOffsetFromLineOfText
    widget.textScrollController.updateAutoScrollingForTouchOffset(
      userInteractionOffsetInViewport: (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(details.globalPosition + _touchHandleOffsetFromLineOfText!),
    );
    widget.textScrollController.addListener(_updateSelectionForNewDragHandleLocation);
    _log.fine(' - updated auto scrolling for touch offset');

    setState(() {
      _isDraggingCollapsed = false;
      _isDraggingBase = true;
      _isDraggingExtent = false;
      _globalDragOffset = details.globalPosition;
      // We map global to local instead of using  details.localPosition because
      // this drag event started in a handle, not within this overall widget.
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
      _log.fine(' - done updating all local state for beginning drag');
    });
  }

  void _onExtentPanStart(DragStartDetails details) {
    _log.fine('_onExtentPanStart');

    // TODO: de-dup the calculation of the mid-line focal point
    final globalOffsetInMiddleOfLine =
        _getGlobalOffsetOfMiddleOfLine(widget.editingController.textController.selection.extent);
    _touchHandleOffsetFromLineOfText = globalOffsetInMiddleOfLine - details.globalPosition;

    widget.editingController
      ..hideToolbar()
      ..cancelCollapsedHandleAutoHideCountdown();

    // TODO: de-dup the repeated calculations of the effective focal point: globalPosition + _touchHandleOffsetFromLineOfText
    widget.textScrollController.updateAutoScrollingForTouchOffset(
      userInteractionOffsetInViewport: (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(details.globalPosition + _touchHandleOffsetFromLineOfText!),
    );
    widget.textScrollController.addListener(_updateSelectionForNewDragHandleLocation);

    setState(() {
      _isDraggingCollapsed = false;
      _isDraggingBase = false;
      _isDraggingExtent = true;
      _localDragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _log.fine('_onPanUpdate');

    // Must set global drag offset before _updateSelectionForNewDragHandleLocation()
    _globalDragOffset = details.globalPosition;
    _log.fine(' - global offset: $_globalDragOffset');
    _updateSelectionForNewDragHandleLocation();
    _log.fine(' - done updating selection for new drag handle location');

    // TODO: de-dup the repeated calculations of the effective focal point: globalPosition + _touchHandleOffsetFromLineOfText
    widget.textScrollController.updateAutoScrollingForTouchOffset(
      userInteractionOffsetInViewport: (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(details.globalPosition + _touchHandleOffsetFromLineOfText!),
    );
    _log.fine(' - updated auto scrolling for touch offset');

    setState(() {
      _localDragOffset = _localDragOffset! + details.delta;
      widget.editingController.showMagnifier(_localDragOffset!);
      _log.fine(' - done updating all local state for drag update');
    });
  }

  void _updateSelectionForNewDragHandleLocation() {
    final textBox = (widget.textContentKey.currentContext!.findRenderObject() as RenderBox);
    final textOffset = textBox.globalToLocal(_globalDragOffset! + _touchHandleOffsetFromLineOfText!);
    final textLayout = widget.textContentKey.currentState!;
    if (_isDraggingCollapsed) {
      widget.editingController.textController.selection = TextSelection.collapsed(
        offset: textLayout.getPositionNearestToOffset(textOffset).offset,
      );
    } else if (_isDraggingBase) {
      _log.fine('Dragging base. New offset: ${textLayout.getPositionNearestToOffset(textOffset).offset}');
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
      _isDraggingCollapsed = false;
      _isDraggingBase = false;
      _isDraggingExtent = false;
      widget.editingController.hideMagnifier();

      if (!widget.editingController.textController.selection.isCollapsed) {
        // We hid the toolbar while dragging a handle. If the selection is
        // expanded, show it again.
        widget.editingController.showToolbar();
      } else {
        // The collapsed handle should disappear after some inactivity.
        widget.editingController
          ..unHideCollapsedHandle()
          ..startCollapsedHandleAutoHideCountdown();
      }
    });
  }

  Offset _textPositionToViewportOffset(TextPosition position) {
    final textOffset = widget.textContentKey.currentState!.getOffsetAtPosition(position);
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
    return widget.textContentKey.currentState!.getOffsetAtPosition(position);
  }

  Offset _getGlobalOffsetOfMiddleOfLine(TextPosition position) {
    // TODO: can we de-dup this with similar calculations in _user_interaction?
    final textLayout = widget.textContentKey.currentState!;
    final extentOffsetInText = textLayout.getOffsetAtPosition(position);
    final extentLineHeight = textLayout.getCharacterBox(position).toRect().height;
    final extentGlobalOffset =
        (widget.textContentKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(extentOffsetInText);

    return extentGlobalOffset + Offset(0, extentLineHeight / 2);
  }

  Offset _getLocalOffsetOfMiddleOfLine(TextPosition position) {
    return (context.findRenderObject() as RenderBox).globalToLocal(_getGlobalOffsetOfMiddleOfLine(position));
  }

  @override
  Widget build(BuildContext context) {
    final textFieldRenderObject = context.findRenderObject();
    if (textFieldRenderObject == null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return const SizedBox();
    }

    return MultiListenableBuilder(
        listenables: {
          widget.editingController,
        },
        builder: (context) {
          return Stack(
            children: [
              // Build the focal point for the magnifier
              if (_isDraggingCollapsed || _isDraggingBase || _isDraggingExtent) _buildMagnifierFocalPoint(),
              // Build the magnifier (this needs to be done before building
              // the handles so that the magnifier doesn't show the handles
              if (widget.editingController.isMagnifierVisible) _buildMagnifier(),
              // Build the base and extent draggable handles
              ..._buildDraggableOverlayHandles(),
              // Build the editing toolbar
              _buildToolbar(),
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

    const toolbarGap = 24.0;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    if (widget.editingController.textController.selection.isCollapsed) {
      final extentOffsetInViewport =
          _textPositionToViewportOffset(widget.editingController.textController.selection.extent);
      final lineHeight = widget.textContentKey.currentState!
          .getLineHeightAtPosition(widget.editingController.textController.selection.extent);

      toolbarTopAnchor = extentOffsetInViewport - const Offset(0, toolbarGap);
      toolbarBottomAnchor = extentOffsetInViewport + Offset(0, lineHeight) + const Offset(0, toolbarGap);
    } else {
      final selectionBoxes =
          widget.textContentKey.currentState!.getBoxesForSelection(widget.editingController.textController.selection);
      Rect selectionBounds = selectionBoxes.first.toRect();
      for (int i = 1; i < selectionBoxes.length; ++i) {
        selectionBounds = selectionBounds.expandToInclude(selectionBoxes[i].toRect());
      }
      final selectionTopInText = selectionBounds.topCenter;
      final selectionTopInViewport = _textOffsetToViewportOffset(selectionTopInText);
      toolbarTopAnchor = selectionTopInViewport - const Offset(0, toolbarGap);

      final selectionBottomInText = selectionBounds.bottomCenter;
      final selectionBottomInViewport = _textOffsetToViewportOffset(selectionBottomInText);
      toolbarBottomAnchor = selectionBottomInViewport + const Offset(0, toolbarGap);
    }

    // The selection might start above the visible area in a scrollable
    // text field. In that case, we don't want the toolbar to sit more
    // than [toolbarGap] above the text field.
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      max(
        toolbarTopAnchor.dy,
        -toolbarGap,
      ),
    );

    // The selection might end below the visible area in a scrollable
    // text field. In that case, we don't want the toolbar to sit more
    // than [toolbarGap] below the text field.
    final viewportHeight = (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).size.height;
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      min(
        toolbarTopAnchor.dy,
        viewportHeight + toolbarGap,
      ),
    );

    final textFieldGlobalOffset =
        (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(Offset.zero);

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
          child: Builder(builder: (context) {
            return widget.popoverToolbarBuilder(context, widget.editingController);
          }),
        ),
      ),
    );
  }

  List<Widget> _buildDraggableOverlayHandles() {
    if (!widget.editingController.areHandlesVisible) {
      return [];
    }

    if (widget.editingController.textController.selection.extentOffset < 0) {
      _log.finer('Not building overlay handles because there is no selection');
      // There is no selection. Draw nothing.
      return [];
    }

    if (widget.editingController.textController.selection.isCollapsed && !_isDraggingBase && !_isDraggingExtent) {
      return [
        _buildCollapsedHandle(),
      ];
    } else {
      return _buildExpandedHandles();
    }
  }

  Widget _buildCollapsedHandle() {
    final extentTextPosition = widget.editingController.textController.selection.extent;
    _log.finer('Collapsed handle text position: $extentTextPosition');
    final extentHandleOffsetInText = _textPositionToTextOffset(extentTextPosition);
    _log.finer('Collapsed handle text offset: $extentHandleOffsetInText');
    double extentLineHeight = widget.textContentKey.currentState!.getCharacterBox(extentTextPosition).toRect().height;
    if (widget.editingController.textController.text.text.isEmpty) {
      extentLineHeight = widget.textContentKey.currentState!.getLineHeightAtPosition(extentTextPosition);
    }

    if (extentHandleOffsetInText == const Offset(0, 0) && extentTextPosition.offset != 0) {
      // The caret offset is (0, 0), but the caret text position isn't at the
      // beginning of the text. This means that there's a layout timing
      // issue and we should reschedule this calculation for the next frame.
      _scheduleRebuildBecauseTextIsNotLaidOutYet();
      return const SizedBox();
    }

    if (extentLineHeight == 0) {
      _log.finer('Not building collapsed handle because the text layout reported a zero line-height');
      // A line height of zero indicates that the text isn't laid out yet.
      // Schedule a rebuild to give the text a frame to layout.
      _scheduleRebuildBecauseTextIsNotLaidOutYet();
      return const SizedBox();
    }

    return _buildHandle(
      handleKey: _collapsedHandleKey,
      followerOffset: extentHandleOffsetInText + Offset(0, extentLineHeight),
      handleType: HandleType.collapsed,
      showHandle: true,
      debugColor: Colors.blue,
      onPanStart: _onCollapsedPanStart,
    );
  }

  List<Widget> _buildExpandedHandles() {
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
    final upstreamLineHeight =
        widget.textContentKey.currentState!.getCharacterBox(upstreamTextPosition).toRect().height;
    final upstreamHandleOffsetInText = _textPositionToTextOffset(upstreamTextPosition) + Offset(0, upstreamLineHeight);

    final downstreamTextPosition = selectionDirection == TextAffinity.downstream
        ? widget.editingController.textController.selection.extent
        : widget.editingController.textController.selection.base;
    final downstreamLineHeight =
        widget.textContentKey.currentState!.getCharacterBox(downstreamTextPosition).toRect().height;
    final downstreamHandleOffsetInText =
        _textPositionToTextOffset(downstreamTextPosition) + Offset(0, downstreamLineHeight);

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
        showHandle: showUpstreamHandle,
        handleType: HandleType.upstream,
        debugColor: Colors.green,
        onPanStart: selectionDirection == TextAffinity.downstream ? _onBasePanStart : _onExtentPanStart,
      ),
      // right-bounding handle touch target
      _buildHandle(
        handleKey: _downstreamHandleKey,
        followerOffset: downstreamHandleOffsetInText,
        showHandle: showDownstreamHandle,
        handleType: HandleType.downstream,
        debugColor: Colors.red,
        onPanStart: selectionDirection == TextAffinity.downstream ? _onExtentPanStart : _onBasePanStart,
      ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required Offset followerOffset,
    required bool showHandle,
    required HandleType handleType,
    required Color debugColor,
    required void Function(DragStartDetails) onPanStart,
  }) {
    late Offset fractionalTranslation;
    switch (handleType) {
      case HandleType.collapsed:
        fractionalTranslation = const Offset(-0.5, 0.0);
        break;
      case HandleType.upstream:
        fractionalTranslation = const Offset(-1.0, 0.0);
        break;
      case HandleType.downstream:
        fractionalTranslation = Offset.zero;
        break;
    }

    return CompositedTransformFollower(
      key: handleKey,
      link: widget.textContentLayerLink,
      offset: followerOffset,
      child: FractionalTranslation(
        translation: fractionalTranslation,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: Container(
            color: widget.showDebugPaint ? Colors.green : Colors.transparent,
            child: showHandle
                ? AnimatedOpacity(
                    opacity: handleType == HandleType.collapsed && widget.editingController.isCollapsedHandleAutoHidden
                        ? 0.0
                        : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: AndroidSelectionHandle(
                      handleType: handleType,
                      color: widget.handleColor,
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      ),
    );
  }

  Widget _buildMagnifierFocalPoint() {
    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.

    // On Android, the horizontal position of the magnifier follows
    // the exact position of the user's finger, but the vertical
    // position is always centered vertically in the line with the
    // selection. Therefore, we need to calculate that vertical position.
    final focalPointOffsetInMiddleOfLine = _getLocalOffsetOfMiddleOfLine(
      _isDraggingCollapsed || _isDraggingExtent
          ? widget.editingController.textController.selection.extent
          : widget.editingController.textController.selection.base,
    );

    return Positioned(
      left: _localDragOffset!.dx,
      top: focalPointOffsetInMiddleOfLine.dy,
      child: CompositedTransformTarget(
        link: widget.editingController.magnifierFocalPoint,
        child: const SizedBox(width: 1, height: 1),
      ),
    );
  }

  Widget _buildMagnifier() {
    // Display a magnifier that tracks a focal point.
    //
    // When the user is dragging an overlay handle, we also place
    // the LayerLink target.
    //
    // When some other interaction wants to show the magnifier, then
    // that other area of the widget tree is responsible for
    // positioning the LayerLink target.
    return Center(
      child: AndroidFollowingMagnifier(
        layerLink: widget.editingController.magnifierFocalPoint,
        offsetFromFocalPoint: const Offset(0, -72),
      ),
    );
  }

  void _scheduleRebuildBecauseTextIsNotLaidOutYet() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        setState(() {
          // no-op. Rebuild this widget in the hopes that the selectable
          // text has gone through a layout pass.
        });
      }
    });
  }
}

class AndroidEditingOverlayController with ChangeNotifier {
  AndroidEditingOverlayController({
    required this.textController,
    required LayerLink magnifierFocalPoint,
  }) : _magnifierFocalPoint = magnifierFocalPoint;

  @override
  void dispose() {
    _handleAutoHideTimer?.cancel();
    super.dispose();
  }

  bool _isToolbarVisible = false;
  bool get isToolbarVisible => _isToolbarVisible;

  /// The [AttributedTextEditingController] controlling the text
  /// and selection within the text field with which this
  /// [AndroidEditingOverlayController] is associated.
  ///
  /// The purpose of an [AndroidEditingOverlayController] is to control
  /// the presentation of UI controls related to text editing. These
  /// controls don't make sense without some underlying text and
  /// selection. Those properties and behaviors are represented by
  /// this [textController].
  final AttributedTextEditingController textController;

  void toggleToolbar() {
    if (isToolbarVisible) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  void showToolbar() {
    hideMagnifier();

    _isToolbarVisible = true;

    notifyListeners();
  }

  void hideToolbar() {
    _isToolbarVisible = false;
    notifyListeners();
  }

  final LayerLink _magnifierFocalPoint;
  LayerLink get magnifierFocalPoint => _magnifierFocalPoint;

  bool _isMagnifierVisible = false;
  bool get isMagnifierVisible => _isMagnifierVisible;

  void showMagnifier(Offset globalOffset) {
    hideToolbar();

    _isMagnifierVisible = true;

    notifyListeners();
  }

  void hideMagnifier() {
    _isMagnifierVisible = false;
    notifyListeners();
  }

  bool _areHandlesVisible = false;
  bool get areHandlesVisible => _areHandlesVisible;

  void showHandles() {
    if (!_areHandlesVisible) {
      _areHandlesVisible = true;
      notifyListeners();
    }
  }

  void hideHandles() {
    if (_areHandlesVisible) {
      _areHandlesVisible = false;
      cancelCollapsedHandleAutoHideCountdown();
      notifyListeners();
    }
  }

  // The collapsed handle is auto-hidden on Android after a period of inactivity.
  // We represent the auto-hidden status of the collapsed handle independently
  // from the general visibility of all handles. This way, the expanded handles
  // are not inadvertently hidden due to the collapsed handle being hidden. Also,
  // this allows for fading out of the collapsed handle, rather than the abrupt
  // disappearance of all handles.
  final Duration _handleAutoHideDuration = const Duration(seconds: 4);
  Timer? _handleAutoHideTimer;
  bool _isCollapsedHandleAutoHidden = false;
  bool get isCollapsedHandleAutoHidden => _isCollapsedHandleAutoHidden;

  void unHideCollapsedHandle() {
    if (_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = false;
      notifyListeners();
    }
  }

  void startCollapsedHandleAutoHideCountdown() {
    _handleAutoHideTimer?.cancel();
    _handleAutoHideTimer = Timer(_handleAutoHideDuration, _hideCollapsedHandle);
  }

  void cancelCollapsedHandleAutoHideCountdown() {
    _handleAutoHideTimer?.cancel();
  }

  void _hideCollapsedHandle() {
    if (!_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = true;
      notifyListeners();
    }
  }
}
