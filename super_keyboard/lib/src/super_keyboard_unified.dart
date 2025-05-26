import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:super_keyboard/src/keyboard.dart';
import 'package:super_keyboard/src/super_keyboard_android.dart';
import 'package:super_keyboard/src/super_keyboard_ios.dart';

/// A widget that rebuilds whenever the window geometry changes in a way that's
/// relevant to the software keyboard.
class SuperKeyboardBuilder extends StatefulWidget {
  const SuperKeyboardBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, MobileWindowGeometry) builder;

  @override
  State<SuperKeyboardBuilder> createState() => _SuperKeyboardBuilderState();
}

class _SuperKeyboardBuilderState extends State<SuperKeyboardBuilder> {
  @override
  void initState() {
    super.initState();
    SuperKeyboard.instance.mobileGeometry.addListener(_onKeyboardStateChange);
  }

  @override
  void dispose() {
    SuperKeyboard.instance.mobileGeometry.removeListener(_onKeyboardStateChange);
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
      SuperKeyboard.instance.mobileGeometry.value,
    );
  }
}

/// A unified API for tracking the software keyboard status, regardless of platform.
class SuperKeyboard {
  static SuperKeyboard? _instance;
  static SuperKeyboard get instance {
    _instance ??= SuperKeyboard._();
    return _instance!;
  }

  @visibleForTesting
  static set testInstance(SuperKeyboard? testInstance) => _instance = testInstance;

  static final log = Logger("super_keyboard");

  static void startLogging([Level level = Level.ALL]) {
    hierarchicalLoggingEnabled = true;
    log.level = level;
    log.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time.toLogTime()}: ${record.message}');
    });
  }

  static void stopLogging() {
    log.level = Level.OFF;
  }

  SuperKeyboard._() {
    _init();
  }

  void _init() {
    log.info("Initializing SuperKeyboard");
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      log.fine("SuperKeyboard - Initializing for iOS");
      SuperKeyboardIOS.instance.geometry.addListener(_onIOSWindowGeometryChange);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      log.fine("SuperKeyboard - Initializing for Android");
      SuperKeyboardAndroid.instance.geometry.addListener(_onAndroidWindowGeometryChange);
    }
  }

  /// Enable/disable platform-side logging, e.g., Android or iOS logs.
  ///
  /// These logs are distinct from Flutter-side logs, which are controlled
  /// by [startLogging].
  Future<void> enablePlatformLogging(bool isEnabled) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      log.fine("SuperKeyboard - Tried to start logging for iOS, but it's not implemented yet.");
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      log.fine("SuperKeyboard - ${isEnabled ? "Enabling" : "Disabling"} logs for Android.");
      await SuperKeyboardAndroid.instance.enablePlatformLogging(isEnabled);
    }
  }

  ValueListenable<MobileWindowGeometry> get mobileGeometry => _mobileGeometry;
  final _mobileGeometry = ValueNotifier<MobileWindowGeometry>(const MobileWindowGeometry());

  void _onIOSWindowGeometryChange() {
    _mobileGeometry.value = SuperKeyboardIOS.instance.geometry.value;
  }

  void _onAndroidWindowGeometryChange() {
    _mobileGeometry.value = SuperKeyboardAndroid.instance.geometry.value;
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
