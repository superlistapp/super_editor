import 'package:super_editor/src/infrastructure/platform_detector.dart';

// TODO: get rid of this file and replace with defaultTargetPlatform checks

class MacPlatform implements Platform {
  @override
  bool get isMac => true;
}

class WindowsPlatform implements Platform {
  @override
  bool get isMac => false;
}

class LinuxPlatform implements Platform {
  @override
  bool get isMac => false;
}

class AndroidPlatform implements Platform {
  @override
  bool get isMac => false;
}

class IosPlatform implements Platform {
  @override
  bool get isMac => false;
}