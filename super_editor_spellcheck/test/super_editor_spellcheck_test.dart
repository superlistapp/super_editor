import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck_platform_interface.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSuperEditorSpellcheckPlatform
    with MockPlatformInterfaceMixin
    implements SuperEditorSpellcheckPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SuperEditorSpellcheckPlatform initialPlatform = SuperEditorSpellcheckPlatform.instance;

  test('$MethodChannelSuperEditorSpellcheck is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSuperEditorSpellcheck>());
  });

  test('getPlatformVersion', () async {
    SuperEditorSpellcheck superEditorSpellcheckPlugin = SuperEditorSpellcheck();
    MockSuperEditorSpellcheckPlatform fakePlatform = MockSuperEditorSpellcheckPlatform();
    SuperEditorSpellcheckPlatform.instance = fakePlatform;

    expect(await superEditorSpellcheckPlugin.getPlatformVersion(), '42');
  });
}
