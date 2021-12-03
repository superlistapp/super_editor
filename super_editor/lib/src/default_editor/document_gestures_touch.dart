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
  }) : _document = document;

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
}

enum ControlsStyle {
  android,
  iOS,
}

mixin DragHandleAutoScrolling {
  final _maxDragSpeed = 2;
  late AxisOffset _dragAutoScrollBoundary;
  Offset? _globalStartDragOffset;
  Offset? _dragStartInDoc;
  Offset? _startDragPositionOffset;
  double? _dragStartScrollOffset;
  Offset? _globalDragOffset;
  Offset? _dragEndInInteractor;
  // TODO: HandleType is the wrong type here, we need collapsed/base/extent,
  //       not collapsed/upstream/downstream. Change the type once it's working.
  HandleType? _dragHandleType;
  bool _scrollUpOnTick = false;
  bool _scrollDownOnTick = false;
  late Ticker _ticker;

  void initAutoScroller(TickerProvider tickerProvider, AxisOffset dragAutoScrollBoundary) {
    _ticker = tickerProvider.createTicker(_onTick);
    _dragAutoScrollBoundary = dragAutoScrollBoundary;
  }

  void disposeAutoScroller() {
    _ticker.dispose();
  }

  /// Implementers need to return the `ScrollPosition` that this auto-scroller
  /// controls.
  ScrollPosition get scrollPosition;

  /// Implementers need to return the `RenderBox` associated with the viewport
  /// of the scrollable that this auto-scroller controls.
  ///
  /// The viewport is the visual area of a scrollable that the user sees and
  /// touches (as opposed to the content inside the viewport).
  RenderBox get viewportBox;

  /// Implementers need to return the `RenderBox` for the interaction area of
  /// the content.
  ///
  /// If the scrollable that you're controlling is the same size as your content
  /// then this `RenderBox` should be the same as the [viewportBox].
  ///
  /// If the scrollable that you're controlling is an ancestor widget, then this
  /// `RenderBox` should represent the bounds of your visible content. Those bounds
  /// may, or may not, be the same as the ancestor scrollable.
  RenderBox get interactorBox;

  /// The scroll offset may have changed, implementers should re-calculate the
  /// current content selection.
  void updateDragSelection();

  /// Maps the given [interactorOffset] within the interactor's coordinate space
  /// to the same screen position in the viewport's coordinate space.
  ///
  /// When this interactor includes it's own `ScrollView`, the [interactorOffset]
  /// is the same as the viewport offset.
  ///
  /// When this interactor defers to an ancestor `Scrollable`, then the
  /// [interactorOffset] is transformed into the ancestor coordinate space.
  Offset _interactorOffsetInViewport(Offset interactorOffset) {
    return viewportBox.globalToLocal(
      interactorBox.localToGlobal(interactorOffset),
    );
  }

  void onAutoScrollStartDragScrollOffsetChanged(double scrollOffset) {
    _dragStartScrollOffset = scrollOffset;
  }

  void onAutoScrollDragOffsetChange(Offset offsetInInteractor) {
    _dragEndInInteractor = offsetInInteractor;
  }

  void startScrollingUp() {
    if (_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Starting to auto-scroll up');
    _scrollUpOnTick = true;
    _ticker.start();
  }

  void stopScrollingUp() {
    if (!_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll up');
    _scrollUpOnTick = false;
    _ticker.stop();
  }

  void _scrollUp() {
    if (_dragEndInInteractor == null) {
      editorGesturesLog.warning("Tried to scroll up but couldn't because _dragEndInInteractor is null");
      assert(_dragEndInInteractor != null);
      return;
    }

    if (scrollPosition.pixels <= 0) {
      editorGesturesLog.finest("Tried to scroll up but the scroll position is already at the top");
      return;
    }

    editorGesturesLog.finest("Scrolling up on tick");
    final scrollDeltaWhileDragging = _dragStartScrollOffset! - scrollPosition.pixels;
    editorGesturesLog.finest("Scroll delta: $scrollDeltaWhileDragging");
    final dragEndInViewport =
        _interactorOffsetInViewport(_dragEndInInteractor!); // - Offset(0, scrollDeltaWhileDragging);
    editorGesturesLog.finest("Drag end in viewport: $dragEndInViewport");
    final leadingScrollBoundary = _dragAutoScrollBoundary.leading;
    final gutterAmount = dragEndInViewport.dy.clamp(0.0, leadingScrollBoundary);
    final speedPercent = (1.0 - (gutterAmount / leadingScrollBoundary)).clamp(0.0, 1.0);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent);

    scrollPosition.jumpTo(scrollPosition.pixels - scrollAmount!);

    // By changing the scroll offset, we may have changed the content
    // selected by the user's current finger/mouse position. Update the
    // document selection calculation.
    updateDragSelection();
  }

  void startScrollingDown() {
    if (_scrollDownOnTick) {
      return;
    }

    editorGesturesLog.finest('Starting to auto-scroll down');
    _scrollDownOnTick = true;
    _ticker.start();
  }

  void stopScrollingDown() {
    if (!_scrollDownOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll down');
    _scrollDownOnTick = false;
    _ticker.stop();
  }

  void _scrollDown() {
    if (_dragEndInInteractor == null) {
      editorGesturesLog.warning("Tried to scroll down but couldn't because _dragEndInViewport is null");
      assert(_dragEndInInteractor != null);
      return;
    }

    if (scrollPosition.pixels >= scrollPosition.maxScrollExtent) {
      editorGesturesLog.finest("Tried to scroll down but the scroll position is already beyond the max");
      return;
    }

    editorGesturesLog.finest("Scrolling down on tick");
    final dragEndInViewport =
        _interactorOffsetInViewport(_dragEndInInteractor!); // - Offset(0, scrollDeltaWhileDragging);
    final trailingScrollBoundary = _dragAutoScrollBoundary.trailing;
    final gutterAmount = (viewportBox.size.height - dragEndInViewport.dy).clamp(0.0, trailingScrollBoundary);
    final speedPercent = 1.0 - (gutterAmount / trailingScrollBoundary);
    final scrollAmount = lerpDouble(0, _maxDragSpeed, speedPercent);

    scrollPosition.jumpTo(scrollPosition.pixels + scrollAmount!);

    // By changing the scroll offset, we may have changed the content
    // selected by the user's current finger/mouse position. Update the
    // document selection calculation.
    updateDragSelection();
  }

  void _onTick(elapsedTime) {
    if (_scrollUpOnTick) {
      _scrollUp();
    }
    if (_scrollDownOnTick) {
      _scrollDown();
    }
  }
}
