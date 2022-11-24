import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';

/// Controls the display of drag handles, a magnifier, and a
/// floating toolbar, assuming Android-style behavior for the
/// handles.
class AndroidDocumentGestureEditingController extends ChangeNotifier {
  AndroidDocumentGestureEditingController({
    required LayerLink documentLayoutLink,
    required LayerLink magnifierFocalPointLink,
    required MagnifierAndToolbarController toolbarController,
  })  : _documentLayoutLink = documentLayoutLink,
        _toolbarController = toolbarController,
        _magnifierFocalPointLink = magnifierFocalPointLink,
        super() {
    _toolbarController.addListener(_toolbarChanged);
  }

  @override
  void dispose() {
    _collapsedHandleAutoHideTimer?.cancel();
    _toolbarController.removeListener(_toolbarChanged);
    super.dispose();
  }

  /// Layer link that's aligned to the top-left corner of the document layout.
  ///
  /// Some of the offsets reported by this controller are based on the
  /// document layout coordinate space. Therefore, to honor those offsets on
  /// the screen, this `LayerLink` should be used to align the controls with
  /// the document layout before applying the offset that sits within the
  /// document layout.
  LayerLink get documentLayoutLink => _documentLayoutLink;
  final LayerLink _documentLayoutLink;

  /// A `LayerLink` whose top-left corner sits at the location where the
  /// magnifier should magnify.
  LayerLink get magnifierFocalPointLink => _magnifierFocalPointLink;
  final LayerLink _magnifierFocalPointLink;

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

  final Duration _collapsedHandleAutoHideDuration = const Duration(seconds: 4);
  Timer? _collapsedHandleAutoHideTimer;

  /// Whether the collapsed handle should be faded out for the purpose of
  /// auto-hiding while the user is inactive.
  bool get isCollapsedHandleAutoHidden => _isCollapsedHandleAutoHidden;
  bool _isCollapsedHandleAutoHidden = false;

  /// Controls the magnifier and the toolbar.
  MagnifierAndToolbarController get toolbarController => _toolbarController;
  late MagnifierAndToolbarController _toolbarController;
  set toolbarController(MagnifierAndToolbarController value) {
    if (_toolbarController != value) {
      _toolbarController.removeListener(_toolbarChanged);
      _toolbarController = value;
      _toolbarController.addListener(_toolbarChanged);
    }
  }

  /// Whether the toolbar currently has a designated display position.
  ///
  /// The toolbar should not be displayed if this is `false`, even if
  /// [shouldDisplayToolbar] is `true`.
  bool get isToolbarPositioned => _toolbarController.isToolbarPositioned;

  /// Whether the toolbar should be displayed.
  bool get shouldDisplayToolbar => _toolbarController.shouldDisplayToolbar;

  /// Whether the magnifier should be displayed.
  bool get shouldDisplayMagnifier => _toolbarController.shouldDisplayMagnifier;

  /// The point about which the floating toolbar should focus, when the toolbar
  /// appears above the selected content.
  ///
  /// It's the clients responsibility to determine whether there's room for the
  /// toolbar above this point. If not, use [toolbarBottomAnchor].
  Offset? get toolbarTopAnchor => _toolbarController.toolbarTopAnchor;

  /// The point about which the floating toolbar should focus, when the toolbar
  /// appears below the selected content.
  ///
  /// It's the clients responsibility to determine whether there's room for the
  /// toolbar below this point. If not, use [toolbarTopAnchor].
  Offset? get toolbarBottomAnchor => _toolbarController.toolbarBottomAnchor;

  /// Starts a countdown that, if reached, fades out the collapsed drag handle.
  void startCollapsedHandleAutoHideCountdown() {
    _collapsedHandleAutoHideTimer?.cancel();
    _collapsedHandleAutoHideTimer = Timer(_collapsedHandleAutoHideDuration, _hideCollapsedHandle);
  }

  /// Cancels a countdown that started with [startCollapsedHandleAutoHideCountdown].
  void cancelCollapsedHandleAutoHideCountdown() {
    _collapsedHandleAutoHideTimer?.cancel();
  }

  void _hideCollapsedHandle() {
    if (!_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = true;
      notifyListeners();
    }
  }

  /// Brings back a faded-out collapsed drag handle.
  void unHideCollapsedHandle() {
    if (_isCollapsedHandleAutoHidden) {
      _isCollapsedHandleAutoHidden = false;
      notifyListeners();
    }
  }

  /// Shows the toolbar, and hides the magnifier.
  void showToolbar() {
    _toolbarController.showToolbar();
  }

  /// Hides the toolbar.
  void hideToolbar() {
    _toolbarController.hideToolbar();
  }

  /// Shows the magnify, and hides the toolbar.
  void showMagnifier() {
    _toolbarController.showMagnifier();
  }

  /// Hides the magnifier.
  void hideMagnifier() {
    _toolbarController.hideMagnifier();
  }

  /// Toggles the toolbar from visible to not visible, or vis-a-versa.
  void toggleToolbar() {
    _toolbarController.toggleToolbar();
  }

  /// Sets the toolbar's position to the given [topAnchor] and [bottomAnchor].
  ///
  /// Setting the position will not cause the toolbar to be displayed on it's own.
  /// To display the toolbar, call [showToolbar], too.
  void positionToolbar({
    required Offset topAnchor,
    required Offset bottomAnchor,
  }) {
    _toolbarController.positionToolbar(
      topAnchor: topAnchor,
      bottomAnchor: bottomAnchor,
    );
  }

  void _toolbarChanged() {
    notifyListeners();
  }
}
