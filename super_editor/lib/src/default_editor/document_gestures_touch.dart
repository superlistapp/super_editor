import 'dart:async';
import 'dart:ui';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/document_gestures.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_android.dart';
import 'package:super_editor/src/default_editor/document_gestures_touch_ios.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/_scrolling.dart';
import 'package:super_editor/src/infrastructure/touch_controls.dart';

/// Governs touch gesture interaction with a document, such as dragging
/// to scroll a document, and dragging handles to expand a selection.
///
/// See also: super_editor's mouse gesture support.

/// Document gesture interactor that's designed for touch input, e.g.,
/// drag to scroll, and handles to control selection.
class DocumentTouchInteractor extends StatelessWidget {
  const DocumentTouchInteractor({
    Key? key,
    required this.focusNode,
    required this.editContext,
    this.scrollController,
    required this.documentKey,
    this.style = ControlsStyle.android,
    this.showDebugPaint = false,
    required this.child,
  }) : super(key: key);

  final FocusNode focusNode;
  final EditContext editContext;
  final ScrollController? scrollController;
  final GlobalKey documentKey;
  final ControlsStyle style;
  final bool showDebugPaint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ControlsStyle.android:
        return AndroidDocumentTouchInteractor(
          focusNode: focusNode,
          editContext: editContext,
          documentKey: documentKey,
          child: child,
        );
      case ControlsStyle.iOS:
        return IOSDocumentTouchInteractor(
          focusNode: focusNode,
          editContext: editContext,
          documentKey: documentKey,
          child: child,
        );
    }
  }
}

class EditingController with ChangeNotifier {
  EditingController({
    required Document document,
    required LayerLink magnifierFocalPoint,
  })  : _document = document,
        _magnifierFocalPoint = magnifierFocalPoint;

  @override
  void dispose() {
    _handleAutoHideTimer?.cancel();
    super.dispose();
  }

  final Document _document;
  Document get document => _document;

  // TODO:
  bool get areHandlesDesired => true;

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

  DocumentSelection? _selection;
  bool get hasSelection => _selection != null;
  DocumentSelection? get selection => _selection;
  set selection(newSelection) {
    if (newSelection == _selection) {
      return;
    }

    _selection = newSelection;

    notifyListeners();
  }

  final LayerLink _magnifierFocalPoint;
  LayerLink get magnifierFocalPoint => _magnifierFocalPoint;

  bool _isMagnifierVisible = false;
  bool get isMagnifierVisible => _isMagnifierVisible;

  void showMagnifier() {
    // hideToolbar();

    _isMagnifierVisible = true;

    notifyListeners();
  }

  void hideMagnifier() {
    _isMagnifierVisible = false;
    notifyListeners();
  }
}

enum ControlsStyle {
  android,
  iOS,
}

class DragHandleAutoScrolling {
  DragHandleAutoScrolling({
    required TickerProvider vsync,
    required AxisOffset dragAutoScrollBoundary,
    required ScrollPosition Function() getScrollPosition,
    required RenderBox Function() getViewportBox,
  })  : _autoScroller = AutoScroller(vsync: vsync),
        _dragAutoScrollBoundary = dragAutoScrollBoundary,
        _getScrollPosition = getScrollPosition,
        _getViewportBox = getViewportBox;

  void dispose() {
    _autoScroller.dispose();
  }

  final AutoScroller _autoScroller;
  final AxisOffset _dragAutoScrollBoundary;

  /// Implementers need to return the `ScrollPosition` that this auto-scroller
  /// controls.
  final ScrollPosition Function() _getScrollPosition;

  /// Implementers need to return the `RenderBox` associated with the viewport
  /// of the scrollable that this auto-scroller controls.
  ///
  /// The viewport is the visual area of a scrollable that the user sees and
  /// touches (as opposed to the content inside the viewport).
  final RenderBox Function() _getViewportBox;

  void startAutoScrollHandleMonitoring() {
    _autoScroller.scrollPosition = _getScrollPosition();
  }

  void updateAutoScrollHandleMonitoring({
    required Offset dragEndInViewport,
    required double viewportHeight,
  }) {
    if (dragEndInViewport.dy < _dragAutoScrollBoundary.leading) {
      editorGesturesLog.finest('Metrics say we should try to scroll up');

      final leadingScrollBoundary = _dragAutoScrollBoundary.leading;
      final gutterAmount = dragEndInViewport.dy.clamp(0.0, leadingScrollBoundary);
      final speedPercent = (1.0 - (gutterAmount / leadingScrollBoundary)).clamp(0.0, 1.0);

      _autoScroller.startScrollingUp(speedPercent);
    } else {
      _autoScroller.stopScrollingUp();
    }

    if (viewportHeight - dragEndInViewport.dy < _dragAutoScrollBoundary.trailing) {
      editorGesturesLog.finest('Metrics say we should try to scroll down');

      final trailingScrollBoundary = _dragAutoScrollBoundary.trailing;
      final gutterAmount = (_getViewportBox().size.height - dragEndInViewport.dy).clamp(0.0, trailingScrollBoundary);
      final speedPercent = 1.0 - (gutterAmount / trailingScrollBoundary);

      _autoScroller.startScrollingDown(speedPercent);
    } else {
      _autoScroller.stopScrollingDown();
    }
  }

  void stopAutoScrollHandleMonitoring() {
    _autoScroller.stopScrolling();
    _autoScroller.scrollPosition = null;
  }
}
