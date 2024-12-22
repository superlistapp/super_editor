import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:super_keyboard/src/keyboard.dart';

class SuperKeyboardAndroidBuilder extends StatefulWidget {
  const SuperKeyboardAndroidBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, KeyboardState) builder;

  @override
  State<SuperKeyboardAndroidBuilder> createState() => _SuperKeyboardAndroidBuilderState();
}

class _SuperKeyboardAndroidBuilderState extends State<SuperKeyboardAndroidBuilder>
    implements SuperKeyboardAndroidListener {
  @override
  void initState() {
    super.initState();
    SuperKeyboardAndroid.instance.addListener(this);
  }

  @override
  void dispose() {
    SuperKeyboardAndroid.instance.removeListener(this);
    super.dispose();
  }

  @override
  void onKeyboardOpen() {
    setState(() {});
  }

  @override
  void onKeyboardOpening() {
    setState(() {});
  }

  @override
  void onKeyboardClosing() {
    setState(() {});
  }

  @override
  void onKeyboardClosed() {
    setState(() {});
  }

  @override
  void onKeyboardHeightChange(double newHeight) {
    // no-op
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      SuperKeyboardAndroid.instance.keyboardState.value,
    );
  }
}

class SuperKeyboardAndroid {
  static SuperKeyboardAndroid? _instance;
  static SuperKeyboardAndroid get instance {
    _instance ??= SuperKeyboardAndroid._();
    return _instance!;
  }

  static final log = Logger("super_keyboard.android");

  SuperKeyboardAndroid._() {
    log.info("Initializing Android plugin for super_keyboard");
    assert(
      defaultTargetPlatform == TargetPlatform.android,
      "You shouldn't initialize SuperKeyboardAndroid when not on an Android platform. Current: $defaultTargetPlatform",
    );
    _methodChannel.setMethodCallHandler(_onPlatformMessage);
  }

  final _methodChannel = const MethodChannel('super_keyboard_android');

  ValueListenable<KeyboardState> get keyboardState => _keyboardState;
  final _keyboardState = ValueNotifier(KeyboardState.closed);

  ValueListenable<double> get keyboardHeight => _keyboardHeight;
  final _keyboardHeight = ValueNotifier(0.0);

  final _listeners = <SuperKeyboardAndroidListener>{};
  void addListener(SuperKeyboardAndroidListener listener) => _listeners.add(listener);
  void removeListener(SuperKeyboardAndroidListener listener) => _listeners.remove(listener);

  Future<void> _onPlatformMessage(MethodCall message) async {
    log.fine("Android platform message: '${message.method}', args: ${message.arguments}");
    switch (message.method) {
      case "keyboardOpening":
        if (_keyboardState.value == KeyboardState.opening) {
          return;
        }

        _keyboardState.value = KeyboardState.opening;

        for (final listener in _listeners) {
          listener.onKeyboardOpening();
        }
        break;
      case "keyboardOpened":
        if (_keyboardState.value == KeyboardState.open) {
          return;
        }

        _keyboardState.value = KeyboardState.open;

        for (final listener in _listeners) {
          listener.onKeyboardOpen();
        }
        break;
      case "keyboardClosing":
        if (_keyboardState.value == KeyboardState.closing) {
          return;
        }

        _keyboardState.value = KeyboardState.closing;

        for (final listener in _listeners) {
          listener.onKeyboardClosing();
        }
        break;
      case "keyboardClosed":
        if (_keyboardState.value == KeyboardState.closed) {
          return;
        }

        _keyboardState.value = KeyboardState.closed;

        for (final listener in _listeners) {
          listener.onKeyboardClosed();
        }
        break;
      case "onProgress":
        final keyboardHeight = message.arguments["keyboardHeight"] as num?;
        if (keyboardHeight == null) {
          break;
        }

        _keyboardHeight.value = keyboardHeight.toDouble();

        for (final listener in _listeners) {
          listener.onKeyboardHeightChange(keyboardHeight.toDouble());
        }
        break;
      default:
        log.warning("Unknown Android plugin platform message: $message");
    }
  }
}

abstract interface class SuperKeyboardAndroidListener {
  void onKeyboardOpening();
  void onKeyboardOpen();
  void onKeyboardClosing();
  void onKeyboardClosed();
  void onKeyboardHeightChange(double height);
}
