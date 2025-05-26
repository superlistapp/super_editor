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

  final Widget Function(BuildContext, MobileWindowGeometry) builder;

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
    print("iOS keyboard builder - will show");
    setState(() {});
  }

  @override
  void onKeyboardDidShow() {
    print("iOS keyboard builder - did show");
    setState(() {});
  }

  @override
  void onKeyboardWillHide() {
    print("iOS keyboard builder - will hide");
    setState(() {});
  }

  @override
  void onKeyboardDidHide() {
    print("iOS keyboard builder - did hide");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      SuperKeyboardIOS.instance.geometry.value,
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

  ValueListenable<MobileWindowGeometry> get geometry => _geometry;
  final _geometry = ValueNotifier<MobileWindowGeometry>(const MobileWindowGeometry());

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
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.opening,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        print("Reporting onKeyboardWillShow()");
        for (final listener in _listeners) {
          listener.onKeyboardWillShow();
        }
        break;
      case "keyboardDidShow":
        log.info("keyboardDidShow");
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.open,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        print("Reporting onkeyboardDidShow()");
        for (final listener in _listeners) {
          listener.onKeyboardDidShow();
        }
        break;
      case "keyboardWillChangeFrame":
        log.info("keyboardWillChangeFrame - keyboard type: ${message.arguments['keyboardType']}");
        break;
      case "keyboardWillHide":
        log.info("keyboardWillHide");
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.closing,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        print("Reporting onKeyboardWillHide()");
        for (final listener in _listeners) {
          listener.onKeyboardWillHide();
        }
        break;
      case "keyboardDidHide":
        log.info("keyboardDidHide");
        _geometry.value = _geometry.value.updateWith(
          MobileWindowGeometry(
            keyboardState: KeyboardState.closed,
            keyboardHeight: (message.arguments?["keyboardHeight"] as num?)?.toDouble(),
            bottomPadding: (message.arguments?["bottomPadding"] as num?)?.toDouble(),
          ),
        );

        print("Reporting onKeyboardDidHide()");
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
