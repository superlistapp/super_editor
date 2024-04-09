import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:overlord/overlord.dart';
import 'package:super_editor/super_editor.dart';

import 'theme.dart';

/// An application-level popup menu.
///
/// A menu button is displayed with the given [label].
///
/// When the user clicks the menu button, a popover appears, which displays the given [items] as
/// a vertical list. The popover is left-aligned with the menu button, and appears immediately below
/// the menu button.
///
/// The popover list height is based on the following rules:
///
///    1. The popover is displayed as tall as all items in the list, if there's enough room, or
///    2. The popover is displayed as tall as the available space and becomes scrollable.
///
/// The popover list includes keyboard selection behaviors:
///
///   * Pressing UP/DOWN moves the "active" item selection up/down.
///   * Pressing UP with the first item active moves the active item selection to the last item.
///   * Pressing DOWN with the last item active moves the active item selection to the first item.
///   * Pressing ENTER selects the currently active item and closes the popover list.
class DocsAppMenu extends StatefulWidget {
  const DocsAppMenu({
    super.key,
    this.parentFocusNode,
    this.boundaryKey,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  /// The [FocusNode], to which the popover list's [FocusNode] will be added as a child.
  ///
  /// In Flutter, [FocusNode]s have parents and children. This relationship allows an
  /// entire ancestor path to "have focus", but only the lowest level descendant
  /// in that path has "primary focus". This path is important because various
  /// widgets alter their presentation or behavior based on whether or not they
  /// currently have focus, even if they only have "non-primary focus".
  ///
  /// When the popover list of items is visible, that list will have primary focus.
  /// Moreover, because the popover list is built in an `Overlay`, none of your
  /// widgets are in the natural focus path for that popover list. Therefore, if you
  /// need your widget tree to retain focus while the popover list is visible, then
  /// you need to provide the [FocusNode] that the popover list should use as its
  /// parent, thereby retaining focus for your widgets.
  final FocusNode? parentFocusNode;

  /// A [GlobalKey] to a widget that determines the bounds where the popover list can be displayed.
  ///
  /// As the popover list follows the selected item, it can be displayed off-screen if this [DocsAppMenu]
  /// is close to the bottom of the screen.
  ///
  /// Passing a [boundaryKey] causes the popover list to be confined to the bounds of the widget
  /// bound to the [boundaryKey].
  ///
  /// If `null`, the popover list is confined to the screen bounds, defined by the result of `MediaQuery.sizeOf`.
  final GlobalKey? boundaryKey;

  /// The name of the menu, which is displayed on the menu button.
  final String label;

  /// The items that will be displayed in the popover list.
  ///
  /// For each item, its [DocsAppMenuItem.label] is displayed.
  final List<DocsAppMenuItem> items;

  /// Called when the user selects an item on the popover list.
  final void Function(DocsAppMenuItem? value) onSelected;

  @override
  State<DocsAppMenu> createState() => _DocsAppMenuState();
}

class _DocsAppMenuState extends State<DocsAppMenu> {
  /// Shows and hides the popover.
  final PopoverController _popoverController = PopoverController();

  /// The [FocusNode] of the popover list.
  final FocusNode _popoverFocusNode = FocusNode();

  @override
  void dispose() {
    _popoverController.dispose();
    _popoverFocusNode.dispose();
    super.dispose();
  }

  void _onItemSelected(DocsAppMenuItem? value) {
    _popoverController.close();
    widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    return PopoverScaffold(
      controller: _popoverController,
      buttonBuilder: _buildButton,
      popoverFocusNode: _popoverFocusNode,
      parentFocusNode: widget.parentFocusNode,
      boundaryKey: widget.boundaryKey,
      popoverGeometry: DocsAppMenuPopoverGeometry(),
      popoverBuilder: (context) => DocsAppMenuPopoverAppearance(
        child: ItemSelectionList<DocsAppMenuItem>(
          focusNode: _popoverFocusNode,
          value: null,
          items: widget.items,
          itemBuilder: _buildPopoverListItem,
          onItemSelected: _onItemSelected,
          onCancel: () => _popoverController.close(),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    return DocsMenuButton(
      label: widget.label,
      onTap: () => _popoverController.open(),
    );
  }

  Widget _buildPopoverListItem(BuildContext context, DocsAppMenuItem item, bool isActive, VoidCallback onTap) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? Colors.grey.withOpacity(0.2) : Colors.transparent,
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            item.label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// A [PopoverGeometry] designed for a Docs app menu.
///
/// This [PopoverGeometry] aligns the top-left corner of the popover with the bottom-left corner
/// of the menu button that launched it.
class DocsAppMenuPopoverGeometry extends PopoverGeometry {
  @override
  PopoverAligner get aligner => FunctionalPopoverAligner(
        (Rect globalLeaderRect, Size followerSize, Size screenSize, GlobalKey? boundaryKey) {
          final boundsBox = boundaryKey?.currentContext?.findRenderObject() as RenderBox?;
          final bounds = boundsBox != null
              ? Rect.fromPoints(
                  boundsBox.localToGlobal(Offset.zero),
                  boundsBox.localToGlobal(boundsBox.size.bottomRight(Offset.zero)),
                )
              : Offset.zero & screenSize;
          late FollowerAlignment alignment;

          if (globalLeaderRect.bottom + followerSize.height < bounds.bottom) {
            // The follower fits below the leader.
            alignment = const FollowerAlignment(
              leaderAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
            );
          } else if (globalLeaderRect.top - followerSize.height > bounds.top) {
            // The follower fits above the leader.
            alignment = const FollowerAlignment(
              leaderAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
            );
          } else {
            // There isn't enough room to fully display the follower below or above the leader.
            // Pin the popover list to the bottom, letting the follower cover the leader.
            alignment = const FollowerAlignment(
              leaderAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
            );
          }

          return alignment;
        },
      );

  @override
  BoxConstraints get constraints => const BoxConstraints.tightFor(width: 250);
}

/// The shape and color of a popover menu.
class DocsAppMenuPopoverAppearance extends StatefulWidget {
  const DocsAppMenuPopoverAppearance({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DocsAppMenuPopoverAppearance> createState() => _DocsAppMenuPopoverAppearanceState();
}

class _DocsAppMenuPopoverAppearanceState extends State<DocsAppMenuPopoverAppearance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _containerFadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _containerFadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      color: Colors.white,
      elevation: 8,
      child: FadeTransition(
        opacity: _containerFadeInAnimation,
        child: widget.child,
      ),
    );
  }
}

/// An app menu button, such as a button that reads "File" or "Edit" at the top of
/// an app.
class DocsMenuButton extends StatelessWidget {
  const DocsMenuButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  /// The text displayed on the button.
  final String label;

  /// Called when the user taps the button.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.black,
        surfaceTintColor: const Color(0xFFedf2fa),
        padding: const EdgeInsets.symmetric(horizontal: menuButtonHorizontalPadding, vertical: 12),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Text(label),
    );
  }
}

/// An item that's displayed within a popover app menu, such as when the user clicks on
/// an app's "File" menu.
///
/// Two [DocsAppMenuItem]s are considered to be equal if they have the same [id].
class DocsAppMenuItem {
  const DocsAppMenuItem({
    required this.id,
    required this.label,
  });

  /// The value that identifies this item.
  final String id;

  /// The text that is displayed.
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DocsAppMenuItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
