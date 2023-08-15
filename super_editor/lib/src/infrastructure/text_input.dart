import 'package:flutter/foundation.dart';

/// The mode of user text input.
enum TextInputSource {
  keyboard,
  ime,
}

/// Whether or not we are running on web.
///
/// By default this is the same as [kIsWeb].
///
/// [debugIsWebOverride] may be used to override the natural value of [isWeb].
bool get isWeb => debugIsWebOverride == null //
    ? kIsWeb
    : debugIsWebOverride == WebPlatformOverride.web;

/// Overrides the value of [isWeb].
///
/// This is intended to be used in tests.
///
/// Set it to `null` to use the default value of [isWeb].
///
/// Set it to [WebPlatformOverride.web] to configure to run as if we are on web.
///
/// Set it to [WebPlatformOverride.native] to configure to run as if we are NOT on web.
@visibleForTesting
WebPlatformOverride? debugIsWebOverride;

@visibleForTesting
enum WebPlatformOverride {
  /// Configuration to run the app as if we are a native app.
  native,

  /// Configuration to run the app as if we are on web.
  web,
}
