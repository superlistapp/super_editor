import 'package:flutter/foundation.dart';

/// The mode of user text input.
enum TextInputSource {
  keyboard,
  ime,
}

/// Overrides the value of [isWeb].
///
/// This is intended to be used in tests.
bool? debugIsWebOverride;

/// Whether or not we are running on web.
///
/// By default this is the same as [kIsWeb].
///
/// This is intended to be overriden in tests by setting [debugIsWebOverride].
bool get isWeb => debugIsWebOverride ?? kIsWeb;
