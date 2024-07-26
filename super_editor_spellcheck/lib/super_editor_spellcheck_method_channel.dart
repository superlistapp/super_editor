import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'super_editor_spellcheck_platform_interface.dart';

/// An implementation of [SuperEditorSpellcheckPlatform] that uses method channels.
class MethodChannelSuperEditorSpellcheck extends SuperEditorSpellcheckPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('super_editor_spellcheck');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
