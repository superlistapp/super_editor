import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:super_keyboard/src/keyboard.dart';
import 'package:super_keyboard/src/super_keyboard_android.dart';
import 'package:super_keyboard/src/super_keyboard_ios.dart';

class SuperKeyboardBuilder extends StatefulWidget {
  const SuperKeyboardBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, KeyboardState) builder;

  @override
  State<SuperKeyboardBuilder> createState() => _SuperKeyboardBuilderState();
}

class _SuperKeyboardBuilderState extends State<SuperKeyboardBuilder> {
  @override
  void initState() {
    super.initState();
    SuperKeyboard.instance.state.addListener(_onKeyboardStateChange);
  }

  @override
  void dispose() {
    SuperKeyboard.instance.state.removeListener(_onKeyboardStateChange);
    super.dispose();
  }

  void _onKeyboardStateChange() {
    setState(() {
      // Re-build.
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      SuperKeyboard.instance.state.value,
    );
  }
}

/// A unified API for tracking the software keyboard status, regardless
/// of platform.
class SuperKeyboard {
  static SuperKeyboard? _instance;
  static SuperKeyboard get instance {
    _instance ??= SuperKeyboard._();
    return _instance!;
  }

  @visibleForTesting
  static set testInstance(SuperKeyboard? testInstance) => _instance = testInstance;

  static final log = Logger("super_keyboard");

  static void initLogs([Level level = Level.ALL]) {
    hierarchicalLoggingEnabled = true;
    log.level = level;
    log.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time.toLogTime()}: ${record.message}');
    });
  }

  SuperKeyboard._() {
    _init();
  }

  void _init() {
    log.info("Initializing SuperKeyboard");
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      log.fine("SuperKeyboard - Initializing for iOS");
      SuperKeyboardIOS.instance.keyboardState.addListener(_onIOSKeyboardChange);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      log.fine("SuperKeyboard - Initializing for Android");
      SuperKeyboardAndroid.instance.keyboardState.addListener(_onAndroidKeyboardChange);
      SuperKeyboardAndroid.instance.keyboardHeight.addListener(_onAndroidKeyboardHeightChange);
    }
  }

  ValueListenable<KeyboardState> get state => _state;
  final _state = ValueNotifier(KeyboardState.closed);

  ValueListenable<double?> get keyboardHeight => _keyboardHeight;
  final _keyboardHeight = ValueNotifier<double?>(null);

  void _onIOSKeyboardChange() {
    _state.value = SuperKeyboardIOS.instance.keyboardState.value;
  }

  void _onAndroidKeyboardChange() {
    _state.value = SuperKeyboardAndroid.instance.keyboardState.value;
  }

  void _onAndroidKeyboardHeightChange() {
    _keyboardHeight.value = SuperKeyboardAndroid.instance.keyboardHeight.value;
  }
}

extension on DateTime {
  String toLogTime() {
    String h = _twoDigits(hour);
    String min = _twoDigits(minute);
    String sec = _twoDigits(second);
    String ms = _threeDigits(millisecond);
    if (isUtc) {
      return "$h:$min:$sec.$ms";
    } else {
      return "$h:$min:$sec.$ms";
    }
  }

  String _threeDigits(int n) {
    if (n >= 100) return "$n";
    if (n >= 10) return "0$n";
    return "00$n";
  }

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
}
