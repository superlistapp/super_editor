import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/actions.dart';

/// A popover that shares focus with a `SuperEditor`.
///
/// Popovers often need to handle keyboard input, such as arrow keys for
/// selection movement. But `SuperEditor` also needs to continue handling
/// keyboard input to move the caret, enter text, etc. In such a case, the
/// popover has primary focus, and `SuperEditor` has non-primary focus.
/// Due to the way that Flutter's `Actions` system works, along with
/// Flutter's default response to certain key events, a few careful
/// adjustments need to be made so that a popover works with
/// `SuperEditor` as expected. This widget handles those adjustments.
///
/// Despite this widget being a "Super Editor popover", this widget can be
/// placed anywhere in the widget tree, so long as it's able to share focus
/// with `SuperEditor`.
///
/// This widget is purely logical - it doesn't impose any particular layout
/// or constraints. It's up to you whether this widget tightly hugs your
/// popover [child], or whether it expands to fill a space.
///
/// It's possible to create a `SuperEditor` popover without this widget.
/// This widget doesn't have any special access to `SuperEditor`
/// properties or behavior. But, if you choose to display a popover
/// without using this widget, you'll likely need to re-implement this
/// behavior to avoid unexpected user interaction results.
class SuperEditorPopover extends StatelessWidget {
  const SuperEditorPopover({
    super.key,
    required this.popoverFocusNode,
    required this.editorFocusNode,
    this.onKeyEvent,
    required this.child,
  });

  /// The [FocusNode] attached to the popover.
  final FocusNode popoverFocusNode;

  /// The [FocusNode] attached to the editor.
  ///
  /// The [popoverFocusNode] will be reparented with this [FocusNode].
  final FocusNode editorFocusNode;

  /// Callback that notifies key events.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// The popover to display.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntentBlocker(
      intents: appleBlockedIntents,
      child: Focus(
        focusNode: popoverFocusNode,
        parentNode: editorFocusNode,
        onKeyEvent: onKeyEvent,
        child: child,
      ),
    );
  }
}
