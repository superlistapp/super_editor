import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';

/// A button which displays a dropdown with a vertical list of items.
///
/// Unlike Flutter `DropdownButton`, which displays the dropdown in a separate route,
/// this widget displays its dropdown in an `Overlay`. By using an `Overlay`, focus can shared
/// with the [parentFocusNode]. This means that when the dropdown requests focus, [parentFocusNode]
/// still has non-primary focus.
///
/// The dropdown tries to fit all items on the available space. If there isn't enough room,
/// the list of items becomes scrollable with an always visible toolbar.
/// Provide [dropdownContraints] to enforce aditional constraints on the dropdown list.
///
/// The user can navigate between the options using the arrow keys, select an option with ENTER and
/// close the dropdown with ESC.
class SuperDropdownButton<T> extends StatefulWidget {
  const SuperDropdownButton({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.itemBuilder,
    required this.buttonBuilder,
    this.focusColor,
    required this.boundaryKey,
    required this.parentFocusNode,
    this.dropdownContraints,
    this.dropdownKey,
  });

  /// The items that will be displayed in the dropdown list.
  final List<T> items;

  /// The currently selected value or `null` if no item is selected.
  final T? value;

  /// Called when the user selects an item on the dropdown list.
  final ValueChanged<T?> onChanged;

  /// Builds each item in the dropdown list.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Builds the button that opens the dropdown.
  final Widget Function(BuildContext context, T? item) buttonBuilder;

  /// The background color of the focused list item.
  final Color? focusColor;

  /// A [GlobalKey] to a widget that determines the bounds where the dropdown can be displayed.
  ///
  /// Used to avoid the dropdown to be displayed off-screen.
  final GlobalKey boundaryKey;

  /// A [GlobalKey] bound to the dropdown list.
  final GlobalKey? dropdownKey;

  /// Constraints applied to the dropdown list.
  final BoxConstraints? dropdownContraints;

  /// [FocusNode] which will share focus with the dropdown list.
  final FocusNode parentFocusNode;

  @override
  State<SuperDropdownButton<T>> createState() => SuperDropdownButtonState<T>();
}

@visibleForTesting
class SuperDropdownButtonState<T> extends State<SuperDropdownButton<T>> with SingleTickerProviderStateMixin {
  final DropdownController _dropdownController = DropdownController();

  @visibleForTesting
  ScrollController get scrollController => _scrollController;
  final ScrollController _scrollController = ScrollController();

  @visibleForTesting
  int? get focusedIndex => _focusedIndex;
  int? _focusedIndex;

  late final AnimationController _animationController;
  late final Animation<double> _resizeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _resizeAnimation = CurvedAnimation(
      parent: _animationController,
      // The first half of the animation resizes the dropdown list.
      // The other half will fade in the items.
      curve: const Interval(0.0, 0.5),
    );
  }

  @override
  void dispose() {
    _dropdownController.dispose();
    _scrollController.dispose();

    _animationController.dispose();
    super.dispose();
  }

  void _onButtonTap() {
    _dropdownController.show();
    _animationController
      ..reset()
      ..forward();

    setState(() {
      _focusedIndex = null;
    });
  }

  /// Called when the user taps an item or presses ENTER with a focused item.
  void _submitItem(T item) {
    widget.onChanged(item);
    _dropdownController.hide();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (![
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.escape,
    ].contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _dropdownController.hide();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_focusedIndex == null) {
        _dropdownController.hide();
        return KeyEventResult.handled;
      }

      _submitItem(widget.items[_focusedIndex!]);

      return KeyEventResult.handled;
    }

    int? newFocusedIndex;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex == null || _focusedIndex! >= widget.items.length - 1) {
        // We don't have a focused item or we are at the end of the list. Focus the first item.
        newFocusedIndex = 0;
      } else {
        // Move the focus down.
        newFocusedIndex = _focusedIndex! + 1;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex == null || _focusedIndex! <= 0) {
        // We don't have a focused item or we are at the beginning of the list. Focus the last item.
        newFocusedIndex = widget.items.length - 1;
      } else {
        // Move the focus up.
        newFocusedIndex = _focusedIndex! - 1;
      }
    }

    setState(() {
      _focusedIndex = newFocusedIndex;
    });

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return RawDropdown(
      controller: _dropdownController,
      boundaryKey: widget.boundaryKey,
      dropdownBuilder: _buildDropDown,
      parentFocusNode: widget.parentFocusNode,
      onKeyEvent: _onKeyEvent,
      child: ConstrainedBox(
        // TODO: what value should we use?
        constraints: const BoxConstraints(maxHeight: 100),
        child: InkWell(
          onTap: _onButtonTap,
          child: Center(
            child: _buildSelectedItem(),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedItem() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: widget.buttonBuilder(context, widget.value),
        ),
        const Icon(Icons.arrow_drop_down),
      ],
    );
  }

  Widget _buildDropDown(BuildContext context, LeaderLink link, FollowerBoundary boundary) {
    final dropdownItems = <Widget>[];

    // The fade-in animation start at the middle of the animation.
    const fadeAnimationStart = 0.5;

    // The fade-in animation takes half of the animation duration.
    const fadeAnimationTotalDuration = 0.5;

    final animationPercentagePerItem = fadeAnimationTotalDuration / (widget.items.length);

    // The duration of the fade-in animation for each list item.
    final itemFadeInDuration = fadeAnimationTotalDuration * animationPercentagePerItem;

    for (int i = 0; i < widget.items.length; i++) {
      // Computes at which point of the animation each item starts/ends fading in.
      final start = clampDouble(fadeAnimationStart + (i + 1) * animationPercentagePerItem, 0.0, 1.0);
      final end = clampDouble(start + itemFadeInDuration, 0.0, 1.0);

      dropdownItems.add(
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _animationController,
            curve: Interval(start, end),
          ),
          child: Container(
            color: _focusedIndex == i ? widget.focusColor : null,
            child: _buildDropDownItem(context, widget.items[i]),
          ),
        ),
      );
    }

    return Follower.withOffset(
      link: link,
      leaderAnchor: Alignment.center,
      followerAnchor: Alignment.center,
      boundary: boundary,
      showWhenUnlinked: false,
      child: ConstrainedBox(
        constraints: widget.dropdownContraints ?? const BoxConstraints(),
        child: SizeTransition(
          sizeFactor: _resizeAnimation,
          axisAlignment: 1.0,
          fixedCrossAxisSizeFactor: 1.0,
          child: Material(
            key: widget.dropdownKey,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                overscroll: false,
                physics: const ClampingScrollPhysics(),
              ),
              child: PrimaryScrollController(
                controller: _scrollController,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    primary: true,
                    child: IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: dropdownItems,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropDownItem(BuildContext context, T item) {
    return InkWell(
      onTap: () => _submitItem(item),
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: widget.itemBuilder(context, item),
        ),
      ),
    );
  }
}

/// A widget which displays a dropdown linked to its child.
///
/// The dropdown is displayed in an `Overlay` and it can follow the [child]
/// by being wrapped with a [Follower]. The visibility of the dropdown
/// is changed by calling [DropdownController.show] or [DropdownController.hide].
/// The dropdown is automatically closed when the user taps outside of its bounds.
///
/// When the dropdown is displayed it requests focus to itself, so the user can
/// interact with the content using the keyboard. The focus is shared
/// with the [parentFocusNode]. Provide [onKeyEvent] to handle key presses
/// when the dropdown is visible.
///
/// This widget doesn't enforce any style, dropdown position or decoration.
class RawDropdown extends StatefulWidget {
  const RawDropdown({
    super.key,
    required this.controller,
    required this.boundaryKey,
    required this.dropdownBuilder,
    required this.parentFocusNode,
    this.onKeyEvent,
    required this.child,
  });

  /// Shows and hides the dropdown.
  final DropdownController controller;

  /// Builds the content of the dropdown.
  final DropdownBuilder dropdownBuilder;

  /// Called at each key press while the dropdown has focus.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// [FocusNode] which will share focus with the dropdown.
  final FocusNode parentFocusNode;

  /// A [GlobalKey] to a widget that determines the bounds where the dropdown can be displayed.
  ///
  /// Used to avoid the dropdown to be displayed off-screen.
  final GlobalKey boundaryKey;

  final Widget child;

  @override
  State<RawDropdown> createState() => _RawDropdownState();
}

class _RawDropdownState extends State<RawDropdown> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LeaderLink _dropdownLink = LeaderLink();
  final FocusNode _dropdownFocusNode = FocusNode();

  late FollowerBoundary _screenBoundary;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_onDropdownControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenBoundary = WidgetFollowerBoundary(
      boundaryKey: widget.boundaryKey,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void didUpdateWidget(covariant RawDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onDropdownControllerChanged);
      widget.controller.addListener(_onDropdownControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDropdownControllerChanged);
    _dropdownLink.dispose();

    super.dispose();
  }

  void _onDropdownControllerChanged() {
    if (widget.controller.shouldShow) {
      _overlayController.show();
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        // Wait until next frame to request focus, so that the parent relationship
        // can be established between our focus node and the parent focus node.
        _dropdownFocusNode.requestFocus();
      });
    } else {
      _overlayController.hide();
    }
  }

  void _onTapOutsideOfDropdown(PointerDownEvent e) {
    widget.controller.hide();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onKeyEvent != null) {
      return widget.onKeyEvent!(node, event);
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildDropdown,
      child: Leader(
        link: _dropdownLink,
        child: widget.child,
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    return TapRegion(
      onTapOutside: _onTapOutsideOfDropdown,
      child: SuperEditorPopover(
        popoverFocusNode: _dropdownFocusNode,
        editorFocusNode: widget.parentFocusNode,
        onKeyEvent: _onKeyEvent,
        child: widget.dropdownBuilder(context, _dropdownLink, _screenBoundary),
      ),
    );
  }
}

typedef DropdownBuilder = Widget Function(BuildContext context, LeaderLink link, FollowerBoundary boundary);

/// Controls the visibility of a dropdown.
class DropdownController with ChangeNotifier {
  /// Whether the dropdown should be displayed.
  bool get shouldShow => _shouldShow;
  bool _shouldShow = false;

  void show() {
    if (_shouldShow) {
      return;
    }
    _shouldShow = true;
    notifyListeners();
  }

  void hide() {
    if (!_shouldShow) {
      return;
    }
    _shouldShow = false;
    notifyListeners();
  }

  void toggle() {
    if (shouldShow) {
      hide();
    } else {
      show();
    }
  }
}
