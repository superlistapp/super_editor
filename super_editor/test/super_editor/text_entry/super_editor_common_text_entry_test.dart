import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../supereditor_test_tools.dart';

void main() {
  group("SuperEditor common text entry >", () {
    testWidgetsOnDesktop("control keys don't impact content", (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withInputSource(_desktopInputSourceAndControlKeyVariant.currentValue!.inputSource)
          .pump();

      final initialParagraphText = SuperEditorInspector.findTextInParagraph("1");

      // Select some content -> "Lorem |ipsum| dolor sit..."
      await tester.doubleTapInParagraph("1", 8);
      const expectedSelection = DocumentSelection(
        base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 6)),
        extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
      );
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);

      // Press a control key.
      await tester.sendKeyEvent(
        _desktopInputSourceAndControlKeyVariant.currentValue!.controlKey,
        platform: _desktopInputSourceAndControlKeyVariant.currentValue!.platform,
      );

      // Make sure the content and selection remains the same.
      expect(SuperEditorInspector.findTextInParagraph("1"), initialParagraphText);
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);
    }, variant: _desktopInputSourceAndControlKeyVariant);

    testWidgetsOnMobile("control keys don't impact content", (tester) async {
      await tester //
          .createDocument()
          .withSingleParagraph()
          .withInputSource(_mobileInputSourceAndControlKeyVariant.currentValue!.inputSource)
          .pump();

      final initialParagraphText = SuperEditorInspector.findTextInParagraph("1");

      // Select some content -> "Lorem |ipsum| dolor sit..."
      await tester.doubleTapInParagraph("1", 8);
      const expectedSelection = DocumentSelection(
        base: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 6)),
        extent: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
      );
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);

      // Press a control key.
      await tester.sendKeyEvent(
        _mobileInputSourceAndControlKeyVariant.currentValue!.controlKey,
        platform: _mobileInputSourceAndControlKeyVariant.currentValue!.platform,
      );

      // Make sure the content and selection remains the same.
      expect(SuperEditorInspector.findTextInParagraph("1"), initialParagraphText);
      expect(SuperEditorInspector.findDocumentSelection(), expectedSelection);
    }, variant: _mobileInputSourceAndControlKeyVariant);
  });
}

final _mobileInputSourceAndControlKeyVariant = ValueVariant({
  for (final platform in _mobilePlatforms)
    for (final inputSource in TextInputSource.values)
      for (final controlKey in _allPlatformControlKeys) //
        _InputSourceAndControlKey(inputSource, controlKey, platform),
});

final _desktopInputSourceAndControlKeyVariant = ValueVariant({
  for (final platform in _desktopPlatforms)
    for (final inputSource in TextInputSource.values)
      for (final controlKey in _desktopControlKeys) //
        _InputSourceAndControlKey(inputSource, controlKey, platform),
});

// TODO: Replace raw strings with constants when Flutter offers them (https://github.com/flutter/flutter/issues/133295)
final _mobilePlatforms = ["android", "ios"];
final _desktopPlatforms = ["macos", "windows", "linux"];

class _InputSourceAndControlKey {
  _InputSourceAndControlKey(
    this.inputSource,
    this.controlKey,
    this.platform,
  );

  final TextInputSource inputSource;
  final LogicalKeyboardKey controlKey;
  final String platform;

  @override
  String toString() => "$inputSource, ${controlKey.keyLabel}, $platform";
}

final _allPlatformControlKeys = {
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
};

// Apparently Flutter blows up if you simulate certain keys on mobile. Those
// keys are separated here as desktop-only control keys.
final _desktopControlKeys = {
  ..._allPlatformControlKeys,
  LogicalKeyboardKey.f13,
  LogicalKeyboardKey.f14,
  LogicalKeyboardKey.f15,
  LogicalKeyboardKey.f16,
  LogicalKeyboardKey.f17,
  LogicalKeyboardKey.f18,
  LogicalKeyboardKey.f19,
  LogicalKeyboardKey.f20,
  // The following keys don't appear to be supported on desktop as of Aug 24, 2023.
  // LogicalKeyboardKey.f21,
  // LogicalKeyboardKey.f22,
  // LogicalKeyboardKey.f23,
  // LogicalKeyboardKey.f24,
};
