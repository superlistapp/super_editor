import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'super_editor_spellcheck_method_channel.dart';

abstract class SuperEditorSpellcheckPlatform extends PlatformInterface {
  /// Constructs a SuperEditorSpellcheckPlatform.
  SuperEditorSpellcheckPlatform() : super(token: _token);

  static final Object _token = Object();

  static SuperEditorSpellcheckPlatform _instance = MethodChannelSuperEditorSpellcheck();

  /// The default instance of [SuperEditorSpellcheckPlatform] to use.
  ///
  /// Defaults to [MethodChannelSuperEditorSpellcheck].
  static SuperEditorSpellcheckPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SuperEditorSpellcheckPlatform] when
  /// they register themselves.
  static set instance(SuperEditorSpellcheckPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
