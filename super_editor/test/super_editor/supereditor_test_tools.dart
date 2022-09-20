import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';

/// A widget test that runs a variant for every desktop platform, e.g.,
/// Mac, Windows, Linux, and for all [DocumentInputSource]s.
void testSuperEditorOnDesktop(
  String description,
  SuperEditorTesterCallback test, {
  bool skip = false,
}) {
  testWidgetsOnDesktop("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: DocumentInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnDesktop("$description (IME)", (WidgetTester tester) async {
    await test(tester, inputSource: DocumentInputSource.ime);
  }, skip: skip);
}

/// A widget test that runs as a Mac, and for all [DocumentInputSource]s.
void testSuperEditorOnMac(
  String description,
  SuperEditorTesterCallback test, {
  bool skip = false,
}) {
  testWidgetsOnMac("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: DocumentInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnMac("$description (IME)", (WidgetTester tester) async {
    await test(tester, inputSource: DocumentInputSource.ime);
  }, skip: skip);
}

/// A widget test that runs a variant for Windows and Linux, and for all [DocumentInputSource]s.
void testSuperEditorOnWindowsAndLinux(
  String description,
  SuperEditorTesterCallback test, {
  bool skip = false,
}) {
  testWidgetsOnWindowsAndLinux("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: DocumentInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnWindowsAndLinux("$description (IME)", (WidgetTester tester) async {
    await test(tester, inputSource: DocumentInputSource.ime);
  }, skip: skip);
}

typedef SuperEditorTesterCallback = Future<void> Function(
  WidgetTester widgetTester, {
  required DocumentInputSource inputSource,
});
