import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_keyboard/src/keyboard.dart';
import 'package:super_keyboard/src/super_keyboard_unified.dart';

/// A widget that simulates the software keyboard appearance and disappearance.
///
/// This works by listening to messages sent from Flutter to the platform that show/hide
/// the software keyboard. In response to those messages, [SuperKeyboard] emits
/// notifications for the keyboard opening, opened, closing, closed. The timing of those
/// messages are based on an animation in this widget, simulating actual keyboard expansion
/// and collapse. Similarly, this widget installs a `MediaQuery`, which sets its bottom
/// offsets equal to the simulated keyboard height, which reflects how Flutter actually
/// reports keyboard height to Flutter apps.
///
/// Place this widget above the `Scaffold` in the widget tree.
class SoftwareKeyboardHeightSimulator extends StatefulWidget {
  const SoftwareKeyboardHeightSimulator({
    super.key,
    required this.tester,
    this.isEnabled = true,
    this.enableForAllPlatforms = false,
    this.keyboardHeight = _defaultKeyboardHeight,
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
  ///
  /// The value for this property should remain constant within a single test. Don't
  /// attempt to enable and then disable keyboard simulation. That behavior is undefined.
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
  @override
  void initState() {
    super.initState();

    if (widget.isEnabled) {
      TestSuperKeyboard.install(
        widget.tester,
        fakeKeyboardHeight: widget.keyboardHeight,
        keyboardAnimationTime: widget.animateKeyboard ? const Duration(milliseconds: 600) : Duration.zero,
      );
    }
  }

  @override
  void didUpdateWidget(covariant SoftwareKeyboardHeightSimulator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animateKeyboard != oldWidget.animateKeyboard || widget.keyboardHeight != oldWidget.keyboardHeight) {
      TestSuperKeyboard.uninstall();

      TestSuperKeyboard.install(
        widget.tester,
        fakeKeyboardHeight: widget.keyboardHeight,
        keyboardAnimationTime: widget.animateKeyboard ? const Duration(milliseconds: 600) : Duration.zero,
      );
    }

    if (widget.isEnabled && !oldWidget.isEnabled) {
      throw Exception(
          "You initially built a SoftwareKeyboardHeightSimulator disabled, then you enabled it. This mode needs to remain constant throughout a test.");
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      throw Exception(
          "You initially built a SoftwareKeyboardHeightSimulator enabled, then you disabled it. This mode needs to remain constant throughout a test.");
    }
  }

  @override
  void dispose() {
    TestSuperKeyboard.uninstall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SuperKeyboard.instance.keyboardHeight,
      builder: (context, keyboardHeight, child) {
        final realMediaQuery = MediaQuery.of(context);
        final isRelevantPlatform = widget.enableForAllPlatforms ||
            (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
        final shouldSimulate = widget.isEnabled && isRelevantPlatform;
        if (!shouldSimulate) {
          return widget.child;
        }

        return Directionality(
          // For some reason a Stack needs Directionality.
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned.fill(
                child: MediaQuery(
                  data: realMediaQuery.copyWith(
                    viewInsets: realMediaQuery.viewInsets.copyWith(
                      bottom: keyboardHeight ?? 0.0,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
              // Display a placeholder where the keyboard would go so we
              // can verify the keyboard size in golden tests.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: keyboardHeight,
                child: const Placeholder(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TestSuperKeyboard implements SuperKeyboard {
  static void install(
    WidgetTester tester, {
    double fakeKeyboardHeight = _defaultKeyboardHeight,
    Duration keyboardAnimationTime = const Duration(milliseconds: 600),
  }) {
    if (_instance != null) {
      return;
    }

    _instance = TestSuperKeyboard(
      tester,
      fakeKeyboardHeight: fakeKeyboardHeight,
      keyboardAnimationTime: keyboardAnimationTime,
    );

    SuperKeyboard.testInstance = _instance;
  }

  static void uninstall() {
    if (_instance == null) {
      return;
    }

    _instance!.dispose();
    _instance = null;

    SuperKeyboard.testInstance = null;
  }

  static TestSuperKeyboard? _instance;

  TestSuperKeyboard(
    this.tester, {
    this.fakeKeyboardHeight = 400.0,
    Duration keyboardAnimationTime = const Duration(milliseconds: 600),
  }) {
    _interceptPlatformChannel();

    _keyboardHeightController = AnimationController(
      duration: keyboardAnimationTime,
      vsync: tester,
    )
      ..addListener(() {
        _keyboardHeight.value = _keyboardHeightController.value * fakeKeyboardHeight;
      })
      ..addStatusListener(_onKeyboardAnimationStatusChange);
  }

  void _interceptPlatformChannel() {
    tester.interceptChannel(SystemChannels.textInput.name) //
      ..interceptMethod(
        'TextInput.setClient',
        (methodCall) {
          _simulatePlatformOpeningKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.show',
        (methodCall) {
          _simulatePlatformOpeningKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.hide',
        (methodCall) {
          _simulatePlatformClosingKeyboard();
          return null;
        },
      )
      ..interceptMethod(
        'TextInput.clearClient',
        (methodCall) {
          _simulatePlatformClosingKeyboard();
          return null;
        },
      );
  }

  void dispose() {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(SystemChannels.textInput.name, null);
    _keyboardHeightController.dispose();
  }

  final WidgetTester tester;
  final double fakeKeyboardHeight;

  late final AnimationController _keyboardHeightController;

  @override
  ValueListenable<double?> get keyboardHeight => _keyboardHeight;
  final _keyboardHeight = ValueNotifier(0.0);

  @override
  ValueListenable<KeyboardState> get state => _state;
  final _state = ValueNotifier(KeyboardState.closed);

  void _simulatePlatformOpeningKeyboard() {
    _keyboardHeightController.forward();
  }

  void _simulatePlatformClosingKeyboard() {
    _keyboardHeightController.reverse();
  }

  void _onKeyboardAnimationStatusChange(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        _state.value = KeyboardState.opening;
      case AnimationStatus.completed:
        _state.value = KeyboardState.open;
      case AnimationStatus.reverse:
        _state.value = KeyboardState.closing;
      case AnimationStatus.dismissed:
        _state.value = KeyboardState.closed;
    }
  }
}

const _defaultKeyboardHeight = 300.0;
