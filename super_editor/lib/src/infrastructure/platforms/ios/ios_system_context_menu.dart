import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/src/infrastructure/flutter/flutter_scheduler.dart';

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
    required this.leaderLink,
    this.onSystemHide,
  });

  /// A [LeaderLink] attached to the widget that determines the position
  /// of the system context menu.
  final LeaderLink leaderLink;

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
    widget.leaderLink.addListener(_onLeaderChanged);
    onNextFrame((_) => _showSystemMenu());
  }

  @override
  void didUpdateWidget(IOSSystemContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaderLink != oldWidget.leaderLink) {
      oldWidget.leaderLink.removeListener(_onLeaderChanged);
      widget.leaderLink.addListener(_onLeaderChanged);
      onNextFrame((_) => _showSystemMenu());
    }
  }

  @override
  void dispose() {
    widget.leaderLink.removeListener(_onLeaderChanged);
    _systemContextMenuController.dispose();
    super.dispose();
  }

  void _onLeaderChanged() {
    if (widget.leaderLink.offset == null || widget.leaderLink.leaderSize == null) {
      return;
    }

    onNextFrame((_) {
      _showSystemMenu();
    });
  }

  void _showSystemMenu() {
    _systemContextMenuController.show(widget.leaderLink.offset! & widget.leaderLink.leaderSize!);
  }

  @override
  Widget build(BuildContext context) {
    assert(IOSSystemContextMenu.isSupported(context));
    return const SizedBox.shrink();
  }
}
