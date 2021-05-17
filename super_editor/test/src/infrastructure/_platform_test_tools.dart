import 'package:super_editor/src/infrastructure/platform_detector.dart';

class MacPlatform implements Platform {
  @override
  bool get isMac => true;
}

class WindowsPlatform implements Platform {
  @override
  bool get isMac => false;
}
