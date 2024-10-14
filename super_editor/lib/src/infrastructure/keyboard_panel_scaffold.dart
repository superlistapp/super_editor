import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/default_editor/document_ime/document_input_ime.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';

/// Scaffold that displays the given [contentBuilder], while also (optionally) displaying
/// a toolbar docked to the top of the software keyboard, and/or a panel that appears
/// instead of the software keyboard.
///
/// A typical use case for the keyboard panel is a chat application switching between the
/// software keyboard and an emoji panel.
///
/// To correctly use this scaffold, you must place a [KeyboardScaffoldSafeArea] higher in
/// the widget tree to adjust the padding so that the content is above the keyboard panel
/// and software keyboard. The [KeyboardScaffoldSafeArea] can go anywhere higher in the tree,
/// so long as the [KeyboardScaffoldSafeArea] takes up the entire screen.
///
/// The widget returned by [toolbarBuilder] is positioned above the keyboard panel, when
/// visible, or above the software keyboard, when visible. If neither the keyboard panel nor
/// the software keyboard are visible, the widget is positioned at the bottom of the screen.
///
/// The widget returned by [keyboardPanelBuilder] is positioned at the bottom of the screen,
/// with its height constrained to be equal to the software keyboard height.
///
/// The widget returned by [contentBuilder] is positioned above the above-keyboard panel,
/// using all the remaining height.
///
/// Use the [controller] to show/hide the keyboard panel and software keyboard.
///
/// If there is a [Scaffold] in your widget tree, it must have `resizeToAvoidBottomInset`
/// set to `false`, otherwise we can't get the software keyboard height to size the keyboard
/// panel. If `resizeToAvoidBottomInset` is set to `true`, the panel won't be displayed.
class KeyboardPanelScaffold extends StatefulWidget {
  const KeyboardPanelScaffold({
    super.key,
    required this.controller,
    required this.isImeConnected,
    required this.toolbarBuilder,
    required this.keyboardPanelBuilder,
    required this.contentBuilder,
  });

  /// Controls the visibility of the keyboard toolbar, keyboard panel, and software keyboard.
  final KeyboardPanelController controller;

  /// A [ValueListenable] that should notify this [KeyboardPanelScaffold] when the IME connects
  /// and disconnects.
  ///
  /// This signal is used to automatically close any open panel when the IME disconnects.
  final ValueListenable<bool> isImeConnected;

  /// Builds the toolbar that's docked to the top of the software keyboard area.
  final Widget Function(BuildContext context, bool isKeyboardPanelVisible) toolbarBuilder;

  /// Builds the keyboard panel that's displayed in place of the software keyboard.
  final WidgetBuilder keyboardPanelBuilder;

  /// Builds the regular widget subtree beneath this widget.
  ///
  /// This is the content that this widget "wraps". Sometimes this content might be
  /// a whole screen of content, or other times this content might be a single widget
  /// like a text field or an editor.
  final Widget Function(BuildContext context, bool isKeyboardPanelVisible) contentBuilder;

  @override
  State<KeyboardPanelScaffold> createState() => _KeyboardPanelScaffoldState();
}

class _KeyboardPanelScaffoldState extends State<KeyboardPanelScaffold>
    with SingleTickerProviderStateMixin
    implements KeyboardPanelScaffoldDelegate {
  /// The maximum bottom insets that have been observed since the keyboard started expanding.
  ///
  /// This is reset when both the software keyboard and the keyboard panel are closed.
  double _maxBottomInsets = 0.0;

  /// The current height of the keyboard.
  ///
  /// This is used to size the keyboard panel and to position the top panel above the keyboard.
  ///
  /// This value respects the following rules:
  ///
  /// - When the software keyboard is collapsing and the user wants to show the keyboard panel,
  ///   this value is equal to the latest [_maxBottomInsets] observed while the keyboard was visible.
  ///
  /// - When the software keyboard is closed and the user closes the keyboard panel, this value
  ///   is animated from the latest [_maxBottomInsets] to zero.
  ///
  /// - Otherwise, it is equal to [_maxBottomInsets].
  final ValueNotifier<double> _keyboardHeight = ValueNotifier<double>(0.0);

  /// The latest view insets obtained from the enclosing `MediaQuery`.
  ///
  /// It's used to detect if the software keyboard is closed, open, collapsing or expanding.
  EdgeInsets _latestViewInsets = EdgeInsets.zero;

  /// Whether or not we believe that the keyboard is currently open (or opening).
  bool _isKeyboardOpen = false;

  /// Controls the exit animation of the keyboard panel when the software keyboard is closed.
  ///
  /// When we close the software keyboard, the `_keyboardPanelHeight` is adjusted automatically
  /// while the insets are collapsing. If the software keyboard is closed and we want to hide
  /// the keyboard panel, we need to animated it ourselves.
  late final AnimationController _panelExitAnimation;

  /// Shows/hides the [OverlayPortal] containing the keyboard panel and above-keyboard panel.
  final OverlayPortalController _overlayPortalController = OverlayPortalController();

  bool get _wantsToShowAboveKeyboardPanel =>
      widget.controller.toolbarVisibility == KeyboardToolbarVisibility.visible ||
      (widget.controller.toolbarVisibility == KeyboardToolbarVisibility.auto && _keyboardHeight.value > 0);

  final _toolbarKey = GlobalKey();

  SoftwareKeyboardController? _softwareKeyboardController;

  @override
  void initState() {
    super.initState();
    assert(() {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold != null && scaffold.widget.resizeToAvoidBottomInset != false) {
        throw FlutterError(
          'KeyboardPanelScaffold is placed inside a Scaffold with resizeToAvoidBottomInset set to true.\n'
          'This will produce incorrect results. Set resizeToAvoidBottomInset to false.',
        );
      }
      return true;
    }());

    _panelExitAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _panelExitAnimation.addListener(_updatePanelForExitAnimation);

    widget.controller.attach(this);

    widget.isImeConnected.addListener(_onImeConnectionChange);

    onNextFrame((ts) => _overlayPortalController.show());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _updateKeyboardHeightForCurrentViewInsets();
  }

  @override
  void didUpdateWidget(KeyboardPanelScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.detach();
      widget.controller.attach(this);
    }

    if (widget.isImeConnected != oldWidget.isImeConnected) {
      oldWidget.isImeConnected.removeListener(_onImeConnectionChange);
      widget.isImeConnected.addListener(_onImeConnectionChange);
    }
  }

  @override
  void dispose() {
    widget.isImeConnected.removeListener(_onImeConnectionChange);

    widget.controller.detach();

    _panelExitAnimation.removeListener(_updatePanelForExitAnimation);
    _panelExitAnimation.dispose();

    if (_overlayPortalController.isShowing) {
      // WARNING: We can only call `hide()` if `isShowing` is `true`. If we blindly
      // call `hide()` then we'll get a z-index error reported. Flutter should clean
      // that up internally, but until then (written Oct 14, 2024) we guard it here.
      _overlayPortalController.hide();
    }

    super.dispose();
  }

  @override
  void onAttached(SoftwareKeyboardController softwareKeyboardController) {
    _softwareKeyboardController = softwareKeyboardController;
  }

  @override
  void onDetached() {
    _softwareKeyboardController = null;
  }

  void _onImeConnectionChange() {
    final isImeConnected = widget.isImeConnected.value;
    if (isImeConnected) {
      return;
    }

    // The IME isn't connected. Ensure the panel is closed.
    widget.controller.closeKeyboardAndPanel();
  }

  /// Whether the toolbar should be displayed, anchored to the top of the keyboard area.
  @override
  KeyboardToolbarVisibility get toolbarVisibility => _toolbarVisibility;
  KeyboardToolbarVisibility _toolbarVisibility = KeyboardToolbarVisibility.auto;
  @override
  set toolbarVisibility(KeyboardToolbarVisibility value) {
    if (value == _toolbarVisibility) {
      return;
    }

    _toolbarVisibility = value;
    switch (value) {
      case KeyboardToolbarVisibility.visible:
        showToolbar();
      case KeyboardToolbarVisibility.hidden:
        hideToolbar();
      case KeyboardToolbarVisibility.auto:
        _wantsToShowSoftwareKeyboard || _wantsToShowKeyboardPanel //
            ? showToolbar()
            : hideToolbar();
    }
  }

  bool _isToolbarVisible = false;

  /// Shows the toolbar, if it's hidden, or hides the toolbar, if it's visible.
  @override
  void toggleToolbar() {
    if (_isToolbarVisible) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  /// Shows the toolbar that's mounted to the top of the keyboard area.
  @override
  void showToolbar() {
    _toolbarVisibility = KeyboardToolbarVisibility.visible;
    _isToolbarVisible = true;
  }

  /// Hides the toolbar that's mounted to the top of the keyboard area.
  @override
  void hideToolbar() {
    _toolbarVisibility = KeyboardToolbarVisibility.hidden;
    _isToolbarVisible = false;
  }

  /// Whether the software keyboard should be displayed, instead of the keyboard panel.
  bool get wantsToShowSoftwareKeyboard => _wantsToShowSoftwareKeyboard;
  bool _wantsToShowSoftwareKeyboard = false;

  /// Opens the keyboard panel if the keyboard is open, or opens the keyboard
  /// if the keyboard panel is open.
  @override
  void toggleSoftwareKeyboardWithPanel() {
    if (_wantsToShowKeyboardPanel) {
      showSoftwareKeyboard();
    } else {
      showKeyboardPanel();
    }
  }

  /// Shows the software keyboard, if it's hidden.
  @override
  void showSoftwareKeyboard() {
    _wantsToShowKeyboardPanel = false;
    _wantsToShowSoftwareKeyboard = true;
    _softwareKeyboardController!.open();
  }

  /// Hides (doesn't close) the software keyboard, if it's open.
  @override
  void hideSoftwareKeyboard() {
    _wantsToShowSoftwareKeyboard = false;
    _softwareKeyboardController!.hide();

    _maybeAnimatePanelClosed();
  }

  /// Whether a keyboard panel should be displayed instead of the software keyboard.
  bool get wantsToShowKeyboardPanel => _wantsToShowKeyboardPanel;
  bool _wantsToShowKeyboardPanel = false;

  /// Shows the keyboard panel, if it's closed, and hides (doesn't close) the
  /// software keyboard, if it's open.
  @override
  void showKeyboardPanel() {
    _wantsToShowKeyboardPanel = true;
    _wantsToShowSoftwareKeyboard = false;
    _softwareKeyboardController!.hide();
  }

  /// Hides the keyboard panel, if it's open.
  @override
  void hideKeyboardPanel() {
    _wantsToShowKeyboardPanel = false;
  }

  /// Closes the software keyboard if it's open, or closes the keyboard panel if
  /// it's open, and fully closes the keyboard (IME) connection.
  @override
  void closeKeyboardAndPanel() {
    _wantsToShowKeyboardPanel = false;
    _wantsToShowSoftwareKeyboard = false;
    _softwareKeyboardController!.close();

    _maybeAnimatePanelClosed();
  }

  void _maybeAnimatePanelClosed() {
    if (_wantsToShowKeyboardPanel || _wantsToShowSoftwareKeyboard || _latestViewInsets.bottom != 0.0) {
      return;
    }

    // The user wants to close both the software keyboard and the keyboard panel,
    // but the software keyboard is already closed. Animate the keyboard panel height
    // down to zero.
    _panelExitAnimation.reverse(from: 1.0);
  }

  // Updates our local cache of the current bottom window insets, which we assume reflects
  // the current software keyboard height.
  void _updateKeyboardHeightForCurrentViewInsets() {
    final newInsets = MediaQuery.of(context).viewInsets;
    final newBottomInset = newInsets.bottom;
    final isKeyboardCollapsing = newBottomInset < _latestViewInsets.bottom;

    final isClosing = newBottomInset < _latestViewInsets.bottom;
    if (_isKeyboardOpen && isClosing) {
      // The keyboard went from open to closed. Update our cached state.
      _isKeyboardOpen = false;
    } else if (!_isKeyboardOpen && !isClosing) {
      // The keyboard went from closed to open. If there's an open panel, close it.
      _isKeyboardOpen = true;
      widget.controller.hideKeyboardPanel();
    }

    _latestViewInsets = newInsets;

    if (newBottomInset > _maxBottomInsets) {
      // The keyboard is expanding.
      _maxBottomInsets = newBottomInset;
      _keyboardHeight.value = _maxBottomInsets;
      onNextFrame((ts) => _updateSafeArea());
      return;
    }

    if (isKeyboardCollapsing && !_wantsToShowKeyboardPanel) {
      // The keyboard is collapsing and we don't want the keyboard panel to be visible.
      // Follow the keyboard back down.
      _maxBottomInsets = newBottomInset;
      _keyboardHeight.value = _maxBottomInsets;
      onNextFrame((ts) => _updateSafeArea());
      return;
    }
  }

  /// Animates the panel height when the software keyboard is closed and the user wants
  /// to close the keyboard panel.
  void _updatePanelForExitAnimation() {
    setState(() {
      _keyboardHeight.value = _maxBottomInsets * Curves.easeInQuad.transform(_panelExitAnimation.value);
      onNextFrame((ts) => _updateSafeArea());
      if (_panelExitAnimation.status == AnimationStatus.dismissed) {
        // The panel has been fully collapsed. Reset the max known bottom insets.
        _maxBottomInsets = 0.0;
      }
    });
  }

  /// Update the bottom insets of the enclosing [KeyboardScaffoldSafeArea].
  void _updateSafeArea() {
    final keyboardSafeAreaData = KeyboardScaffoldSafeArea.maybeOf(context);
    if (keyboardSafeAreaData == null) {
      return;
    }

    final toolbarSize = (_toolbarKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    keyboardSafeAreaData.bottomInsets = _keyboardHeight.value + (toolbarSize?.height ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final wantsToShowKeyboardPanel = _wantsToShowKeyboardPanel ||
        // The keyboard panel should be kept visible while the software keyboard is expanding
        // and the keyboard panel was previously visible. Otherwise, there will be an empty
        // region between the top of the software keyboard and the bottom of the above-keyboard panel.
        (_wantsToShowSoftwareKeyboard && _latestViewInsets.bottom < _keyboardHeight.value);

    return OverlayPortal(
      controller: _overlayPortalController,
      overlayChildBuilder: (context) {
        return ValueListenableBuilder(
          valueListenable: _keyboardHeight,
          builder: (context, currentHeight, child) {
            if (!_wantsToShowAboveKeyboardPanel && !wantsToShowKeyboardPanel) {
              return const SizedBox.shrink();
            }

            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_wantsToShowAboveKeyboardPanel)
                    KeyedSubtree(
                      key: _toolbarKey,
                      child: widget.toolbarBuilder(
                        context,
                        _wantsToShowKeyboardPanel,
                      ),
                    ),
                  SizedBox(
                    height: _keyboardHeight.value,
                    child: wantsToShowKeyboardPanel ? widget.keyboardPanelBuilder(context) : null,
                  ),
                ],
              ),
            );
          },
        );
      },
      child: widget.contentBuilder(
        context,
        _wantsToShowKeyboardPanel,
      ),
    );
  }
}

/// Shows and hides the keyboard panel and software keyboard.
class KeyboardPanelController {
  KeyboardPanelController(
    this._softwareKeyboardController,
  );

  void dispose() {
    detach();
  }

  final SoftwareKeyboardController _softwareKeyboardController;

  KeyboardPanelScaffoldDelegate? _delegate;

  /// Whether this controller is currently attached to a delegate that
  /// knows how to show a toolbar, and open/close the software keyboard
  /// and keyboard panel.
  bool get hasDelegate => _delegate != null;

  /// Attaches this controller to a delegate that knows how to show a toolbar, open and
  /// close the software keyboard, and the keyboard panel.
  void attach(KeyboardPanelScaffoldDelegate delegate) {
    editorImeLog.finer("[KeyboardPanelController] - Attaching to delegate: $delegate");
    _delegate = delegate;
    _delegate!.onAttached(_softwareKeyboardController);
  }

  /// Detaches this controller from its delegate.
  ///
  /// This controller can't open or close the software keyboard, or keyboard panel, while
  /// detached from a delegate that knows how to make that happen.
  void detach() {
    editorImeLog.finer("[KeyboardPanelController] - Detaching from delegate: $_delegate");
    _delegate?.onDetached();
    _delegate = null;
  }

  /// Whether the toolbar should be displayed, anchored to the top of the keyboard area.
  KeyboardToolbarVisibility get toolbarVisibility => _delegate?.toolbarVisibility ?? KeyboardToolbarVisibility.hidden;
  set toolbarVisibility(KeyboardToolbarVisibility value) => _delegate?.toolbarVisibility = value;

  /// Shows the toolbar, if it's hidden, or hides the toolbar, if it's visible.
  void toggleToolbar() => _delegate?.toggleToolbar();

  /// Shows the toolbar that's mounted to the top of the keyboard area.
  void showToolbar() => _delegate?.showToolbar();

  /// Hides the toolbar that's mounted to the top of the keyboard area.
  void hideToolbar() => _delegate?.hideToolbar();

  /// Opens the keyboard panel if the keyboard is open, or opens the keyboard
  /// if the keyboard panel is open.
  void toggleSoftwareKeyboardWithPanel() => _delegate?.toggleSoftwareKeyboardWithPanel();

  /// Shows the software keyboard, if it's hidden.
  void showSoftwareKeyboard() => _delegate?.showSoftwareKeyboard();

  /// Hides (doesn't close) the software keyboard, if it's open.
  void hideSoftwareKeyboard() => _delegate?.hideSoftwareKeyboard();

  /// Shows the keyboard panel, if it's closed, and hides (doesn't close) the
  /// software keyboard, if it's open.
  void showKeyboardPanel() => _delegate?.showKeyboardPanel();

  /// Hides the keyboard panel, if it's open.
  void hideKeyboardPanel() => _delegate?.hideKeyboardPanel();

  /// Closes the software keyboard if it's open, or closes the keyboard panel if
  /// it's open, and fully closes the keyboard (IME) connection.
  void closeKeyboardAndPanel() => _delegate?.closeKeyboardAndPanel();
}

abstract interface class KeyboardPanelScaffoldDelegate {
  /// Called on this delegate by the [KeyboardPanelController] when the controller
  /// attaches to the delegate.
  ///
  /// [onAttached] is used to pass critical dependencies from the controller to
  /// the delegate.
  void onAttached(SoftwareKeyboardController softwareKeyboardController);

  /// Called on this delegate by the [KeyboardPanelController] when the controller
  /// detaches from the delegate.
  ///
  /// Implementers should release any resources created/stored in [onAttached].
  void onDetached();

  /// The visibility policy for the toolbar that's docked to the top of the software keyboard.
  KeyboardToolbarVisibility get toolbarVisibility;
  set toolbarVisibility(KeyboardToolbarVisibility value);

  /// Shows the toolbar, if it's hidden, or hides the toolbar, if it's visible.
  void toggleToolbar();

  /// Shows the toolbar that's mounted to the top of the keyboard area.
  void showToolbar();

  /// Hides the toolbar that's mounted to the top of the keyboard area.
  void hideToolbar();

  /// Opens the keyboard panel if the keyboard is open, or opens the keyboard
  /// if the keyboard panel is open.
  void toggleSoftwareKeyboardWithPanel();

  /// Shows the software keyboard, if it's hidden.
  void showSoftwareKeyboard();

  /// Hides (doesn't close) the software keyboard, if it's open.
  void hideSoftwareKeyboard();

  /// Shows the keyboard panel, if it's closed, and hides (doesn't close) the
  /// software keyboard, if it's open.
  void showKeyboardPanel();

  /// Hides the keyboard panel, if it's open.
  void hideKeyboardPanel();

  /// Closes the software keyboard if it's open, or closes the keyboard panel if
  /// it's open, and fully closes the keyboard (IME) connection.
  void closeKeyboardAndPanel();
}

enum KeyboardToolbarVisibility {
  /// The toolbar should be hidden.
  hidden,

  /// The toolbar should be visible.
  visible,

  /// The toolbar should be visible only when the software keyboard is open,
  /// or the keyboard panel is open.
  auto,
}

/// Applies padding to the bottom of the child to avoid the software keyboard and
/// the above-keyboard toolbar.
///
/// [KeyboardScaffoldSafeArea] is separate from [KeyboardPanelScaffold] because any
/// widget might want to wrap itself with a [KeyboardPanelScaffold], but the
/// [KeyboardScaffoldSafeArea] needs to be added somewhere in the widget tree that
/// controls the size of the whole screen.
///
/// For example, imagine a social app, like Twitter, that has a text field at the
/// top of the screen to write a post, followed by a social feed below it. The
/// text field would wrap itself with a [KeyboardPanelScaffold] to add a toolbar
/// to the keyboard, but the [KeyboardScaffoldSafeArea] would need to go higher
/// up the widget tree to surround the whole screen.
///
/// The padding in [KeyboardScaffoldSafeArea] is set by a descendant [KeyboardPanelScaffold]
/// in the widget tree.
class KeyboardScaffoldSafeArea extends StatefulWidget {
  static KeyboardSafeAreaGeometry of(BuildContext context) {
    return maybeOf(context)!;
  }

  static KeyboardSafeAreaGeometry? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_InheritedKeyboardScaffoldSafeArea>()?.keyboardSafeAreaData;
  }

  const KeyboardScaffoldSafeArea({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<KeyboardScaffoldSafeArea> createState() => _KeyboardScaffoldSafeAreaState();
}

class _KeyboardScaffoldSafeAreaState extends State<KeyboardScaffoldSafeArea> {
  final KeyboardSafeAreaGeometry _keyboardSafeAreaData = KeyboardSafeAreaGeometry();

  @override
  Widget build(BuildContext context) {
    return _InheritedKeyboardScaffoldSafeArea(
      keyboardSafeAreaData: _keyboardSafeAreaData,
      child: ListenableBuilder(
        listenable: _keyboardSafeAreaData,
        builder: (context, _) {
          return Padding(
            padding: EdgeInsets.only(bottom: _keyboardSafeAreaData.bottomInsets),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _InheritedKeyboardScaffoldSafeArea extends InheritedWidget {
  const _InheritedKeyboardScaffoldSafeArea({
    required this.keyboardSafeAreaData,
    required super.child,
  });

  final KeyboardSafeAreaGeometry keyboardSafeAreaData;

  @override
  bool updateShouldNotify(covariant _InheritedKeyboardScaffoldSafeArea oldWidget) {
    return oldWidget.keyboardSafeAreaData != keyboardSafeAreaData;
  }
}

/// Insets applied by a [KeyboardPanelScaffold] to an ancestor [KeyboardScaffoldSafeArea]
/// to deal with the presence or absence of the software keyboard.
class KeyboardSafeAreaGeometry with ChangeNotifier {
  KeyboardSafeAreaGeometry({
    double bottomInsets = 0.0,
  }) : _bottomInsets = bottomInsets;

  double get bottomInsets => _bottomInsets;
  double _bottomInsets;
  set bottomInsets(double value) {
    _bottomInsets = value;
    notifyListeners();
  }
}
