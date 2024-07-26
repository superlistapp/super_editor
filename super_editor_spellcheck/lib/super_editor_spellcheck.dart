
import 'super_editor_spellcheck_platform_interface.dart';

class SuperEditorSpellcheck {
  Future<String?> getPlatformVersion() {
    return SuperEditorSpellcheckPlatform.instance.getPlatformVersion();
  }
}
