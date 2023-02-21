import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/platforms/mobile_documents.dart';

/// Controls the display of drag handles, a magnifier, and a
/// floating toolbar, assuming Android-style behavior for the
/// handles.
class AndroidDocumentGestureEditingController extends GestureEditingController {
  AndroidDocumentGestureEditingController({
    required LayerLink documentLayoutLink,
    required LayerLink magnifierFocalPointLink,
    required MagnifierAndToolbarController overlayController,
  })  : _documentLayoutLink = documentLayoutLink,
        super(
          magnifierFocalPointLink: magnifierFocalPointLink,
          overlayController: overlayController,
        );

  @override
  void dispose() {
    _collapsedHandleAutoHideTimer?.cancel();
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

  /// The height of the caret, or `null` if no caret should be displayed.
  double? get caretHeight => _caretHeight;
  set caretHeight(double? value) {
    if (value != _caretHeight) {
      _caretHeight = value;
      notifyListeners();
    }
  }

  double? _caretHeight;

  final Duration _collapsedHandleAutoHideDuration = const Duration(seconds: 4);
  Timer? _collapsedHandleAutoHideTimer;

  /// Whether the collapsed handle should be faded out for the purpose of
  /// auto-hiding while the user is inactive.
  bool get isCollapsedHandleAutoHidden => _isCollapsedHandleAutoHidden;
  bool _isCollapsedHandleAutoHidden = false;

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
}
