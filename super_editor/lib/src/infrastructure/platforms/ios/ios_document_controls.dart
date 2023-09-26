import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/follow_the_leader.dart';
import 'package:super_editor/src/infrastructure/documents/selection_leader_document_layer.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';

/// An application overlay that displays an iOS-style toolbar.
class IosEditingToolbarOverlay extends StatefulWidget {
  const IosEditingToolbarOverlay({
    Key? key,
    required this.shouldShowToolbar,
    required this.selectionLinks,
    required this.popoverToolbarBuilder,
    this.createOverlayControlsClipper,
    this.showDebugPaint = false,
  }) : super(key: key);

  final ValueListenable<bool> shouldShowToolbar;

  final SelectionLayerLinks selectionLinks;

  /// Creates a clipper that applies to overlay controls, preventing
  /// the overlay controls from appearing outside the given clipping
  /// region.
  ///
  /// If no clipper factory method is provided, then the overlay controls
  /// will be allowed to appear anywhere in the overlay in which they sit
  /// (probably the entire screen).
  final CustomClipper<Rect> Function(BuildContext overlayContext)? createOverlayControlsClipper;

  /// Builder that constructs the popover toolbar that's displayed above
  /// selected text.
  ///
  /// Typically, this bar includes actions like "copy", "cut", "paste", etc.
  final WidgetBuilder popoverToolbarBuilder;

  /// Disables all gesture interaction for these editing controls,
  /// allowing gestures to pass through these controls to whatever
  /// content currently sits beneath them.
  ///
  /// While this is `true`, the user can't tap or drag on selection
  /// handles or other controls.
  // final bool disableGestureHandling;

  final bool showDebugPaint;

  @override
  State createState() => _IosEditingToolbarOverlayState();
}

class _IosEditingToolbarOverlayState extends State<IosEditingToolbarOverlay> with SingleTickerProviderStateMixin {
  final _boundsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.shouldShowToolbar,
      builder: (context, _) {
        return Padding(
          // Remove the keyboard from the space that we occupy so that
          // clipping calculations apply to the expected visual borders,
          // instead of applying underneath the keyboard.
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ClipRect(
            clipper: widget.createOverlayControlsClipper?.call(context),
            child: SizedBox(
              // ^ SizedBox tries to be as large as possible, because
              // a Stack will collapse into nothing unless something
              // expands it.
              key: _boundsKey,
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Build the editing toolbar
                  if (widget.shouldShowToolbar.value) //
                    _buildToolbar(),
                  if (widget.showDebugPaint) //
                    _buildDebugPaint(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return FollowerFadeOutBeyondBoundary(
      link: widget.selectionLinks.expandedSelectionBoundsLink,
      boundary: WidgetFollowerBoundary(
        boundaryKey: _boundsKey,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
      child: Follower.withAligner(
        link: widget.selectionLinks.expandedSelectionBoundsLink,
        aligner: CupertinoPopoverToolbarAligner(_boundsKey),
        boundary: WidgetFollowerBoundary(
          boundaryKey: _boundsKey,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
        child: widget.popoverToolbarBuilder(context),
      ),
    );
  }

  Widget _buildDebugPaint() {
    return IgnorePointer(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.yellow.withOpacity(0.2),
      ),
    );
  }
}

/// Controls the display of drag handles, a magnifier, and a
/// floating toolbar, assuming iOS-style behavior for the
/// handles.
class IosDocumentGestureEditingController extends GestureEditingController {
  IosDocumentGestureEditingController({
    required LayerLink documentLayoutLink,
    required super.selectionLinks,
    required super.magnifierFocalPointLink,
    required super.overlayController,
  }) : _documentLayoutLink = documentLayoutLink;

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

  final _magnifierLink = LayerLink();

  @override
  void showMagnifier() {
    _newMagnifierLink = _magnifierLink;
    super.showMagnifier();
  }

  @override
  void hideMagnifier() {
    _newMagnifierLink = null;
    super.hideMagnifier();
  }

  LayerLink? get newMagnifierLink => _newMagnifierLink;
  LayerLink? _newMagnifierLink;
  set newMagnifierLink(LayerLink? link) {
    if (_newMagnifierLink == link) {
      return;
    }

    _newMagnifierLink = link;
    notifyListeners();
  }
}

class FloatingCursorController {
  /// Report that the user has activated the floating cursor.
  void onStart() {
    for (final listener in _listeners) {
      listener.onStart();
    }
  }

  Offset? get offset => _offset;
  Offset? _offset;

  /// Report that the user has moved the floating cursor.
  void onMove(Offset? newOffset) {
    if (newOffset == _offset) {
      return;
    }
    _offset = newOffset;

    for (final listener in _listeners) {
      listener.onMove(newOffset);
    }
  }

  /// Report that the user has deactivated the floating cursor.
  void onStop() {
    for (final listener in _listeners) {
      listener.onStop();
    }
  }

  final _listeners = <FloatingCursorListener>{};

  void addListener(FloatingCursorListener listener) {
    _listeners.add(listener);
  }

  void removeListener(FloatingCursorListener listener) {
    _listeners.remove(listener);
  }
}

class FloatingCursorListener {
  FloatingCursorListener({
    VoidCallback? onStart,
    void Function(Offset?)? onMove,
    VoidCallback? onStop,
  })  : _onStart = onStart,
        _onMove = onMove,
        _onStop = onStop;

  final VoidCallback? _onStart;
  final void Function(Offset?)? _onMove;
  final VoidCallback? _onStop;

  void onStart() => _onStart?.call();

  void onMove(Offset? newOffset) => _onMove?.call(newOffset);

  void onStop() => _onStop?.call();
}
