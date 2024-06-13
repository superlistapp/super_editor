import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Displays the iOS system context menu on top of the Flutter view.
///
/// This class was copied and adjusted from Flutter's [SystemContextMenu].
///
/// Currently, only supports iOS 16.0 and above.
///
/// The context menu is the menu that appears, for example, when doing text
/// selection. Flutter typically draws this menu itself, but this class deals
/// with the platform-rendered context menu instead.
///
/// There can only be one system context menu visible at a time. Building this
/// widget when the system context menu is already visible will hide the old one
/// and display this one. A system context menu that is hidden is informed via
/// [onSystemHide].
///
/// To check if the current device supports showing the system context menu,
/// call [isSupported].
///
/// See also:
///
///  * [SystemContextMenuController], which directly controls the hiding and
///    showing of the system context menu.
class IOSSystemContextMenu extends StatefulWidget {
  /// Whether the current device supports showing the system context menu.
  ///
  /// Currently, this is only supported on iOS 16.0 and above.
  static bool isSupported(BuildContext context) {
    return MediaQuery.maybeSupportsShowingSystemContextMenu(context) ?? false;
  }

  const IOSSystemContextMenu({
    super.key,
    required this.anchor,
    this.onSystemHide,
  });

  /// The [Rect] that the context menu should point to.
  final Rect anchor;

  /// Called when the system hides this context menu.
  ///
  /// For example, tapping outside of the context menu typically causes the
  /// system to hide the menu.
  ///
  /// This is not called when showing a new system context menu causes another
  /// to be hidden.
  final VoidCallback? onSystemHide;

  @override
  State<IOSSystemContextMenu> createState() => _IOSSystemContextMenuState();
}

class _IOSSystemContextMenuState extends State<IOSSystemContextMenu> {
  late final SystemContextMenuController _systemContextMenuController;

  @override
  void initState() {
    super.initState();
    _systemContextMenuController = SystemContextMenuController(
      onSystemHide: widget.onSystemHide,
    );
    _systemContextMenuController.show(widget.anchor);
  }

  @override
  void didUpdateWidget(IOSSystemContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anchor != oldWidget.anchor) {
      _systemContextMenuController.show(widget.anchor);
    }
  }

  @override
  void dispose() {
    _systemContextMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(IOSSystemContextMenu.isSupported(context));
    return const SizedBox.shrink();
  }
}
