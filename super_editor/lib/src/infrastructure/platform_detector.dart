import '_platform_detector_unsupported.dart'
    if (dart.library.html) '_platform_detector_web.dart'
    if (dart.library.io) '_platform_detector_io.dart' as impl;

/// Interrogates the current platform this app is running on
/// and provides information that is relevant to Super Editor.
class Platform {
  static var _instance = Platform();
  static Platform get instance => _instance;

  /// Sets the [Platform] singleton so that tests can pretend
  /// to run on platforms other than the host machine that
  /// executes the tests.
  static void setTestInstance(Platform? testPlatform) {
    _instance = testPlatform ?? Platform();
  }

  bool get isMac => impl.isMac;
}
