import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:super_keyboard/src/keyboard.dart';

class SuperKeyboardIOSBuilder extends StatefulWidget {
  const SuperKeyboardIOSBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, KeyboardState) builder;

  @override
  State<SuperKeyboardIOSBuilder> createState() => _SuperKeyboardIOSBuilderState();
}

class _SuperKeyboardIOSBuilderState extends State<SuperKeyboardIOSBuilder> implements SuperKeyboardIOSListener {
  @override
  void initState() {
    super.initState();
    SuperKeyboardIOS.instance.addListener(this);
  }

  @override
  void dispose() {
    SuperKeyboardIOS.instance.removeListener(this);
    super.dispose();
  }

  @override
  void onKeyboardWillShow() {
    setState(() {});
  }

  @override
  void onKeyboardDidShow() {
    setState(() {});
  }

  @override
  void onKeyboardWillHide() {
    setState(() {});
  }

  @override
  void onKeyboardDidHide() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      SuperKeyboardIOS.instance.keyboardState.value,
    );
  }
}

class SuperKeyboardIOS {
  static SuperKeyboardIOS? _instance;
  static SuperKeyboardIOS get instance {
    _instance ??= SuperKeyboardIOS._();
    return _instance!;
  }

  static final log = Logger("super_keyboard.ios");

  SuperKeyboardIOS._() {
    log.info("Initializing iOS plugin for super_keyboard");
    assert(
      defaultTargetPlatform == TargetPlatform.iOS,
      "You shouldn't initialize SuperKeyboardIOS when not on an iOS platform. Current: $defaultTargetPlatform",
    );
    _methodChannel.setMethodCallHandler(_onPlatformMessage);
  }

  final _methodChannel = const MethodChannel('super_keyboard_ios');

  ValueListenable<KeyboardState> get keyboardState => _keyboardState;
  final _keyboardState = ValueNotifier(KeyboardState.closed);

  final _listeners = <SuperKeyboardIOSListener>{};
  void addListener(SuperKeyboardIOSListener listener) => _listeners.add(listener);
  void removeListener(SuperKeyboardIOSListener listener) => _listeners.remove(listener);

  Future<void> _onPlatformMessage(MethodCall message) async {
    assert(() {
      log.fine("iOS platform message: '${message.method}', args: ${message.arguments}");
      return true;
    }());

    switch (message.method) {
      case "keyboardWillShow":
        log.info("keyboardWillShow");
        _keyboardState.value = KeyboardState.opening;

        for (final listener in _listeners) {
          listener.onKeyboardWillShow();
        }
        break;
      case "keyboardDidShow":
        log.info("keyboardDidShow");
        _keyboardState.value = KeyboardState.open;

        for (final listener in _listeners) {
          listener.onKeyboardDidShow();
        }
        break;
      case "keyboardWillChangeFrame":
        log.info("keyboardWillChangeFrame - keyboard type: ${message.arguments['keyboardType']}");
        break;
      case "keyboardWillHide":
        log.info("keyboardWillHide");
        _keyboardState.value = KeyboardState.closing;

        for (final listener in _listeners) {
          listener.onKeyboardWillHide();
        }
        break;
      case "keyboardDidHide":
        log.info("keyboardDidHide");
        _keyboardState.value = KeyboardState.closed;

        for (final listener in _listeners) {
          listener.onKeyboardDidHide();
        }
        break;
    }
  }
}

abstract interface class SuperKeyboardIOSListener {
  void onKeyboardWillShow();
  void onKeyboardDidShow();
  void onKeyboardWillHide();
  void onKeyboardDidHide();
}
