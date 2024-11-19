import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
import 'package:super_editor/super_editor.dart';

final inputSourceVariant = ValueVariant({
  TextInputSource.keyboard,
  TextInputSource.ime,
});

final inputAndGestureVariants = ValueVariant<InputAndGestureTuple>(
  {
    const InputAndGestureTuple(TextInputSource.keyboard, DocumentGestureMode.mouse),
    const InputAndGestureTuple(TextInputSource.keyboard, DocumentGestureMode.iOS),
    const InputAndGestureTuple(TextInputSource.keyboard, DocumentGestureMode.android),
    const InputAndGestureTuple(TextInputSource.ime, DocumentGestureMode.mouse),
    const InputAndGestureTuple(TextInputSource.ime, DocumentGestureMode.iOS),
    const InputAndGestureTuple(TextInputSource.ime, DocumentGestureMode.android),
  },
);

/// A combination of an [inputSource] and a [gestureMode].
class InputAndGestureTuple {
  const InputAndGestureTuple(this.inputSource, this.gestureMode);

  final TextInputSource inputSource;
  final DocumentGestureMode gestureMode;

  @override
  String toString() {
    return '${inputSource.name} Input Source & ${gestureMode.name} Gesture Mode';
  }
}

/// A widget that simulates the software keyboard appearance and disappearance.
///
/// This works by listening to platform messages that show/hide the software keyboard
/// and animating the `MediaQuery` bottom insets to reflect the height of the keyboard.
///
/// Place this widget above the `Scaffold` in the widget tree.
class SoftwareKeyboardHeightSimulator extends StatefulWidget {
  const SoftwareKeyboardHeightSimulator({
    required this.tester,
    this.isEnabled = true,
    this.enableForAllPlatforms = false,
    this.keyboardHeight = 300,
    this.animateKeyboard = false,
    required this.child,
  });

  /// Flutter's [WidgetTester], which is used to intercept platform messages
  /// about opening/closing the keyboard.
  final WidgetTester tester;

  /// Whether or not to enable the simulated software keyboard insets.
  ///
  /// This property is provided so that clients don't need to conditionally add/remove
  /// this widget from the tree. Instead this flag can be flipped, as needed.
  final bool isEnabled;

  /// Whether to simulate software keyboard insets for all platforms (`true`), or whether to
  /// only simulate software keyboard insets for mobile platforms, e.g., Android, iOS (`false`).
  final bool enableForAllPlatforms;

  /// The vertical space, in logical pixels, to occupy at the bottom of the screen to simulate the appearance
  /// of a keyboard.
  final double keyboardHeight;

  /// Whether to simulate keyboard open/closing animations.
  ///
  /// These animations change the keyboard insets over time, similar to how a real
  /// software keyboard slides up/down. However, this also means that clients need to
  /// `pumpAndSettle()` to ensure the animation is complete. If you want to avoid `pumpAndSettle()`
  /// and you don't care about the animation, then pass `false` to disable the animations.
  final bool animateKeyboard;

  final Widget child;

  @override
  State<SoftwareKeyboardHeightSimulator> createState() => _SoftwareKeyboardHeightSimulatorState();
}

class _SoftwareKeyboardHeightSimulatorState extends State<SoftwareKeyboardHeightSimulator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    if (widget.isEnabled) {
      _setupPlatformMethodInterception();
    }
  }

  @override
  void didUpdateWidget(covariant SoftwareKeyboardHeightSimulator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tester != oldWidget.tester && widget.isEnabled) {
      _setupPlatformMethodInterception();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showKeyboard() {
    if (_animationController.isForwardOrCompleted) {
      // The keyboard is either fully visible or animating its entrance.
      return;
    }

    if (!widget.animateKeyboard) {
      _animationController.value = 1.0;
      return;
    }

    _animationController.forward();
  }

  void _hideKeyboard() {
    if (const [AnimationStatus.dismissed, AnimationStatus.reverse].contains(_animationController.status)) {
      // The keyboard is either hidden or animating its exit.
      return;
    }

    if (!widget.animateKeyboard) {
      _animationController.value = 0.0;
      return;
    }

    _animationController.reverse();
  }

  void _setupPlatformMethodInterception() {
    widget.tester.interceptChannel(SystemChannels.textInput.name) //
      ..interceptMethod(
        'TextInput.show',
        (methodCall) {
          _showKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.setClient',
        (methodCall) {
          _showKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.clearClient',
        (methodCall) {
          _hideKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.hide',
        (methodCall) {
          _hideKeyboard();
          return null;
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final realMediaQuery = MediaQuery.of(context);
        final isRelevantPlatform = widget.enableForAllPlatforms ||
            (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
        final shouldSimulate = widget.isEnabled && isRelevantPlatform;

        return MediaQuery(
          data: realMediaQuery.copyWith(
            viewInsets: realMediaQuery.viewInsets.copyWith(
              bottom: shouldSimulate
                  ? widget.keyboardHeight * _animationController.value
                  : realMediaQuery.viewInsets.bottom,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// A [TextInputConnection] that tracks the number of content updates, to verify
/// within tests.
class ImeConnectionWithUpdateCount extends TextInputConnectionDecorator {
  ImeConnectionWithUpdateCount(TextInputConnection client) : super(client);

  int get contentUpdateCount => _contentUpdateCount;
  int _contentUpdateCount = 0;

  @override
  void setEditingState(TextEditingValue value) {
    super.setEditingState(value);
    _contentUpdateCount += 1;
  }
}

/// An [AutomatedTestWidgetsFlutterBinding] with a fake [HardwareKeyboard], which can be used
/// to simulate keys being pressed while new keys are pressed, e.g., `CMD` being pressed when
/// the user then presses `C` to copy or `V` to paste.
///
/// When this binding is instantiated, it replaces the standard Flutter test binding. Once this
/// happens, this binding cannot be removed within the given test file. The binding won't be
/// reset until the next test file runs. Therefore, testers must ensure that the presence of this
/// binding throughout a test file won't impact other tests.
///
/// To help prevent issues with this binding being used in unrelated tests in the same file,
/// a concept of "activation" is included. When this binding is `activate()`d, fakes are
/// be used. When this binding is `deactivate()`d, the regular superclass behaviors are
/// used. A test can use these behaviors as follows:
///
/// ```dart
/// void main() {
///   final fakeServicesBinding = FakeServicesBinding();
///
///   testWidgets('my regular test', (tester) async {
///     // This test doesn't care about the binding.
///   });
///
///   testWidgets('my fake binding test', (tester) async {
///     // This test wants to use the fake binding. Activate it.
///     fakeServicesBinding.activate();
///
///     // Ensure we deactivate the fake services binding after this test.
///     addTearDown(() => fakeServicesBinding.deactivate());
///
///     // Use the binding
///     fakeServicesBinding.fakeKeyboard.isMetaPressed = true;
///   });
/// }
/// ```
class FakeServicesBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  void initInstances() {
    fakeKeyboard = FakeHardwareKeyboard();
    super.initInstances();
  }

  late final FakeHardwareKeyboard fakeKeyboard;

  void activate() => _isActive = true;
  bool _isActive = false;
  void deactivate() => _isActive = false;

  @override
  HardwareKeyboard get keyboard => _isActive ? fakeKeyboard : super.keyboard;
}

/// A fake [HardwareKeyboard], which can be used to simulate keys being pressed while new
/// keys are pressed, e.g., `CMD` being pressed when the user then presses `C` to copy
/// or `V` to paste.
class FakeHardwareKeyboard extends HardwareKeyboard {
  FakeHardwareKeyboard({
    this.isAltPressed = false,
    this.isControlPressed = false,
    this.isMetaPressed = false,
    this.isShiftPressed = false,
  });

  @override
  bool isMetaPressed;
  @override
  bool isControlPressed;
  @override
  bool isAltPressed;
  @override
  bool isShiftPressed;

  @override
  bool isLogicalKeyPressed(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.shift || LogicalKeyboardKey.shiftLeft || LogicalKeyboardKey.shiftRight => isShiftPressed,
      LogicalKeyboardKey.alt || LogicalKeyboardKey.altLeft || LogicalKeyboardKey.altRight => isAltPressed,
      LogicalKeyboardKey.control ||
      LogicalKeyboardKey.controlLeft ||
      LogicalKeyboardKey.controlRight =>
        isControlPressed,
      LogicalKeyboardKey.meta || LogicalKeyboardKey.metaLeft || LogicalKeyboardKey.metaRight => isMetaPressed,
      _ => super.isLogicalKeyPressed(key)
    };
  }
}

/// Generates the default shortcut key bindings based on the [defaultTargetPlatform].
///
/// Copied from [WidgetsApp.defaultShortcuts] to make it possible to force the usage of web shortcuts.
Map<ShortcutActivator, Intent> get defaultFlutterShortcuts {
  if (CurrentPlatform.isWeb) {
    return defaultWebShortcuts;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return defaultNonAppleShortcuts;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return defaultAppleShortcuts;
  }
}

/// Default shortcuts for Windows, Linux, Android and Fuchsia.
///
/// Copied from [WidgetsApp._defaultShortcuts] because Flutter doesn't expose it and
/// we need to provide these shortcuts during tests in order to be able to simulate
/// web platforms during tests.
///
/// This map must be kept up to date with [WidgetsApp._defaultShortcuts].
const Map<ShortcutActivator, Intent> defaultNonAppleShortcuts = <ShortcutActivator, Intent>{
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
/// Copied from [WidgetsApp._defaultAppleOsShortcuts] because Flutter doesn't expose it and
/// we need to provide these shortcuts during tests in order to be able to simulate
/// web platforms during tests.
///
/// This map must be kept up to date with [WidgetsApp._defaultAppleOsShortcuts].
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
/// Copied from [WidgetsApp._defaultWebShortcuts] because Flutter doesn't expose it and
/// we need to provide these shortcuts during tests in order to be able to simulate
/// web platforms during tests.
///
/// This map must be kept up to date with [WidgetsApp._defaultWebShortcuts].
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
