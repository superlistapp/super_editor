import 'package:flutter/material.dart';
import 'package:super_editor/src/default_editor/document_ime/document_input_ime.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';

/// A widget that allows displaying an arbitrary widget occuping the space of the software keyboard.
///
/// A typical use case is a chat application switching between the software keyboard
/// and an emoji panel.
///
/// The widget returned by [keyboardPanelBuilder] is positioned at the bottom of the screen,
/// with its height constrained to be equal to the software keyboard height.
///
/// The widget returned by [aboveKeyboardBuilder] is positioned above the keyboard panel, when
/// visible, or above the software keyboard, when visible. If neither the keyboard panel nor
/// the software keyboard are visible, the widget is positioned at the bottom of the screen.
///
/// The widget returned by [contentBuilder] is positioned above the above-keyboard panel,
/// using all the remaining height.
///
/// Use the [controller] to show/hide the keyboard panel and software keyboard.
///
/// It is required that the enclosing [Scaffold] has `resizeToAvoidBottomInset` set to `false`,
/// otherwise we can't get the software keyboard height to size the keyboard panel. If
/// `resizeToAvoidBottomInset` is set to `true`, the panel won't be displayed.
///
/// Place a [KeyboardScaffoldSafeArea] higher in the widget tree to adjust the padding so
/// that the content is above the keyboard panel and software keyboard.
class KeyboardPanelScaffold extends StatefulWidget {
  const KeyboardPanelScaffold({
    super.key,
    required this.controller,
    required this.contentBuilder,
    required this.aboveKeyboardBuilder,
    required this.keyboardPanelBuilder,
  });

  /// Controls the visibility of the keyboard panel and software keyboard.
  final KeyboardPanelController controller;

  /// Builds the content that fills the available height.
  final Widget Function(BuildContext context, bool isKeyboardPanelVisible) contentBuilder;

  /// Builds the panel that is shown above the keyboard panel.
  final Widget Function(BuildContext context, bool isKeyboardPanelVisible) aboveKeyboardBuilder;

  /// Builds the keyboard panel.
  final WidgetBuilder keyboardPanelBuilder;

  @override
  State<KeyboardPanelScaffold> createState() => _KeyboardPanelScaffoldState();
}

class _KeyboardPanelScaffoldState extends State<KeyboardPanelScaffold> with SingleTickerProviderStateMixin {
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

    widget.controller.addListener(_onKeyboardPanelChanged);

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
      oldWidget.controller.removeListener(_onKeyboardPanelChanged);
      widget.controller.addListener(_onKeyboardPanelChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onKeyboardPanelChanged);
    _panelExitAnimation.removeListener(_updatePanelForExitAnimation);
    _panelExitAnimation.dispose();
    _overlayPortalController.hide();
    super.dispose();
  }

  void _onKeyboardPanelChanged() {
    if (!widget.controller.wantsToShowKeyboardPanel &&
        !widget.controller.wantsToShowSoftwareKeyboard &&
        _latestViewInsets.bottom == 0.0) {
      // The user wants to close both the software keyboard and the keyboard panel,
      // but the software keyboard is already closed. Animate the keyboard panel height
      // down to zero.
      _panelExitAnimation.reverse(from: 1.0);
      return;
    }

    setState(() {
      _updateKeyboardHeightForCurrentViewInsets();
    });
  }

  /// Updates the keyboard height based on the view insets of the enclosing `MediaQuery`.
  void _updateKeyboardHeightForCurrentViewInsets() {
    final newInsets = MediaQuery.of(context).viewInsets;
    final newBottomInset = newInsets.bottom;
    final isKeyboardCollapsing = newBottomInset < _latestViewInsets.bottom;

    _latestViewInsets = newInsets;

    if (newBottomInset > _maxBottomInsets) {
      // The keyboard is expanding.
      _maxBottomInsets = newBottomInset;
      _keyboardHeight.value = _maxBottomInsets;
      onNextFrame((ts) => _updateSafeArea());
      return;
    }

    if (isKeyboardCollapsing && !widget.controller.wantsToShowKeyboardPanel) {
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
    final wantsToShowKeyboardPanel = widget.controller.wantsToShowKeyboardPanel ||
        // The keyboard panel should be kept visible while the software keyboard is expanding
        // and the keyboard panel was previously visible. Otherwise, there will be an empty
        // region between the top of the software keyboard and the bottom of the above-keyboard panel.
        (widget.controller.wantsToShowSoftwareKeyboard && _latestViewInsets.bottom < _keyboardHeight.value);

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
                      child: widget.aboveKeyboardBuilder(
                        context,
                        widget.controller.wantsToShowKeyboardPanel,
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
        widget.controller.wantsToShowKeyboardPanel,
      ),
    );
  }
}

/// Shows and hides the keyboard panel and software keyboard.
class KeyboardPanelController with ChangeNotifier {
  KeyboardPanelController({
    required this.softwareKeyboardController,
  });

  final SoftwareKeyboardController softwareKeyboardController;

  bool get wantsToShowKeyboardPanel => _wantsToShowKeyboardPanel;
  bool _wantsToShowKeyboardPanel = false;

  bool get wantsToShowSoftwareKeyboard => _wantsToShowSoftwareKeyboard;
  bool _wantsToShowSoftwareKeyboard = false;

  KeyboardToolbarVisibility get toolbarVisibility => _toolbarVisibility;
  KeyboardToolbarVisibility _toolbarVisibility = KeyboardToolbarVisibility.auto;
  set toolbarVisibility(KeyboardToolbarVisibility value) {
    _toolbarVisibility = value;
    notifyListeners();
  }

  void showKeyboardPanel() {
    _wantsToShowKeyboardPanel = true;
    _wantsToShowSoftwareKeyboard = false;
    softwareKeyboardController.close();
    notifyListeners();
  }

  void showSoftwareKeyboard() {
    _wantsToShowKeyboardPanel = false;
    _wantsToShowSoftwareKeyboard = true;
    softwareKeyboardController.open();
    notifyListeners();
  }

  /// Switch between the software keyboard and the keyboar panel.
  void toggleKeyboard() {
    if (_wantsToShowKeyboardPanel) {
      showSoftwareKeyboard();
    } else {
      showKeyboardPanel();
    }
  }

  void closeKeyboardAndPanel() {
    _wantsToShowKeyboardPanel = false;
    _wantsToShowSoftwareKeyboard = false;
    softwareKeyboardController.close();
    notifyListeners();
  }

  void showAboveKeyboardPanel() {
    _toolbarVisibility = KeyboardToolbarVisibility.visible;
    notifyListeners();
  }

  void hideAboveKeyboardPanel() {
    _toolbarVisibility = KeyboardToolbarVisibility.hidden;
    notifyListeners();
  }

  void toggleAboveKeyboardPanel() {
    if (_toolbarVisibility == KeyboardToolbarVisibility.visible) {
      hideAboveKeyboardPanel();
    } else {
      showAboveKeyboardPanel();
    }
  }
}

enum KeyboardToolbarVisibility {
  /// The toolbar should stay hidden.
  hidden,

  /// The toolbar should be visible.
  visible,

  /// The toolbar should be visible only when the software keyboard is open.
  auto,
}

/// Applies padding to the bottom of the child to avoid the software keyboard and
/// the above-keyboard toolbar.
///
/// The padding is set by a [KeyboardPanelScaffold] widget in the subtree.
class KeyboardScaffoldSafeArea extends StatefulWidget {
  static KeyboardSafeAreaData of(BuildContext context) {
    return maybeOf(context)!;
  }

  static KeyboardSafeAreaData? maybeOf(BuildContext context) {
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
  final KeyboardSafeAreaData _keyboardSafeAreaData = KeyboardSafeAreaData();

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

  final KeyboardSafeAreaData keyboardSafeAreaData;

  @override
  bool updateShouldNotify(covariant _InheritedKeyboardScaffoldSafeArea oldWidget) {
    return oldWidget.keyboardSafeAreaData != keyboardSafeAreaData;
  }
}

class KeyboardSafeAreaData with ChangeNotifier {
  KeyboardSafeAreaData({
    double bottomInsets = 0.0,
  }) : _bottomInsets = bottomInsets;

  double get bottomInsets => _bottomInsets;
  double _bottomInsets;
  set bottomInsets(double value) {
    _bottomInsets = value;
    notifyListeners();
  }
}
