import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';

/// Prevents a [PrioritizedIntents] from bubbling up if [intentFilter] returns
/// `true` for at least one of its `orderedIntents`.
///
/// Based on [PrioritizedAction].
class PreventPrioritizedIntentsFromBubblingUp extends Action<PrioritizedIntents> {
  PreventPrioritizedIntentsFromBubblingUp({
    required this.intentFilter,
  });

  /// Whether the [intent] should be prevented from bubbling up.
  final bool Function(Intent intent) intentFilter;

  @override
  bool consumesKey(Intent intent) => false;

  @override
  void invoke(Intent intent) {}

  @override
  bool isEnabled(PrioritizedIntents intent, [BuildContext? context]) {
    final FocusNode? focus = primaryFocus;
    if (focus == null || focus.context == null) {
      return false;
    }

    for (final Intent candidateIntent in intent.orderedIntents) {
      final Action<Intent>? candidateAction = Actions.maybeFind<Intent>(
        focus.context!,
        intent: candidateIntent,
      );
      if (candidateAction != null && _isActionEnabled(candidateAction, candidateIntent, context)) {
        // The corresponding Action for the Intent is enabled.
        // This is the Action that Flutter will execute.
        if (intentFilter(candidateIntent)) {
          return true;
        }

        // We don't care about the Intent that is going to have its corresponding Action executed.
        // Don't block it.
        return false;
      }
    }

    return false;
  }

  bool _isActionEnabled(Action action, Intent intent, BuildContext? context) {
    if (action is ContextAction<Intent>) {
      return action.isEnabled(intent, context);
    }
    return action.isEnabled(intent);
  }
}

/// Default shortcuts for Windows, Linux, Android and Fuchsia.
///
/// Copied from [WidgetsApp._defaultShortcuts].
const Map<ShortcutActivator, Intent> defaultShortcuts = <ShortcutActivator, Intent>{
  // Activation
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),

  // Dismissal
  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),

  // Keyboard traversal.
  SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
  SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
  SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),

  // Scrolling
  SingleActivator(LogicalKeyboardKey.arrowUp, control: true): ScrollIntent(direction: AxisDirection.up),
  SingleActivator(LogicalKeyboardKey.arrowDown, control: true): ScrollIntent(direction: AxisDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): ScrollIntent(direction: AxisDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight, control: true): ScrollIntent(direction: AxisDirection.right),
  SingleActivator(LogicalKeyboardKey.pageUp): ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
  SingleActivator(LogicalKeyboardKey.pageDown):
      ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
};

/// Default shortcuts for the Apple platforms.
///
/// Copied from [WidgetsApp._defaultAppleOsShortcuts].
const Map<ShortcutActivator, Intent> defaultAppleShortcuts = <ShortcutActivator, Intent>{
  // Activation
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),

  // Dismissal
  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),

  // Keyboard traversal
  SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
  SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
  SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),

  // Scrolling
  SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): ScrollIntent(direction: AxisDirection.up),
  SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): ScrollIntent(direction: AxisDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true): ScrollIntent(direction: AxisDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight, meta: true): ScrollIntent(direction: AxisDirection.right),
  SingleActivator(LogicalKeyboardKey.pageUp): ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
  SingleActivator(LogicalKeyboardKey.pageDown):
      ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
};

/// Default shortcuts for web.
///
/// Copied from [WidgetsApp._defaultWebShortcuts].
const Map<ShortcutActivator, Intent> defaultWebShortcuts = <ShortcutActivator, Intent>{
  // Activation
  SingleActivator(LogicalKeyboardKey.space): PrioritizedIntents(
    orderedIntents: <Intent>[
      ActivateIntent(),
      ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
    ],
  ),
  // On the web, enter activates buttons, but not other controls.
  SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ButtonActivateIntent(),

  // Dismissal
  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),

  // Keyboard traversal.
  SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
  SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),

  // Scrolling
  SingleActivator(LogicalKeyboardKey.arrowUp): ScrollIntent(direction: AxisDirection.up),
  SingleActivator(LogicalKeyboardKey.arrowDown): ScrollIntent(direction: AxisDirection.down),
  SingleActivator(LogicalKeyboardKey.arrowLeft): ScrollIntent(direction: AxisDirection.left),
  SingleActivator(LogicalKeyboardKey.arrowRight): ScrollIntent(direction: AxisDirection.right),
  SingleActivator(LogicalKeyboardKey.pageUp): ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
  SingleActivator(LogicalKeyboardKey.pageDown):
      ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
};

/// Generates the default shortcut key bindings based on the [defaultTargetPlatform].
///
/// Copied from [WidgetsApp.defaultShortcuts] to make it possible to force to use web shortcuts.
Map<ShortcutActivator, Intent> get defaultFlutterShortcuts {
  if (CurrentPlatform.isWeb) {
    return defaultWebShortcuts;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return defaultShortcuts;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return defaultAppleShortcuts;
  }
}
