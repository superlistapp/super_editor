import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:logging/logging.dart' as logging;
import 'package:meta/meta.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/text_input.dart';

@isTestGroup
void groupWithLogging(String description, logging.Level logLevel, Set<logging.Logger> loggers, VoidCallback body) {
  initLoggers(logLevel, loggers);

  group(description, body);

  deactivateLoggers(loggers);
}

/// A widget test that runs a variant for every desktop platform as native and web, e.g.,
/// Mac, Windows, Linux.
@isTestGroup
void testWidgetsOnDesktopAndWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnDesktop(description, test, skip: skip, variant: variant);
  testWidgetsOnWebDesktop(description, test, skip: skip, variant: variant);
}

/// A widget test that runs a variant for every desktop platform on web, e.g.,
/// Mac, Windows, Linux.
@isTestGroup
void testWidgetsOnWebDesktop(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnMacWeb("$description (on MAC Web)", test, skip: skip, variant: variant);
  testWidgetsOnWindowsWeb("$description (on Windows Web)", test, skip: skip, variant: variant);
  testWidgetsOnLinuxWeb("$description (on Linux Web)", test, skip: skip, variant: variant);
}

// A widget test that runs for macOS web.
@isTestGroup
void testWidgetsOnMacWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    debugIsWebOverride = WebPlatformOverride.web;

    tester.view
      ..devicePixelRatio = 1.0
      ..platformDispatcher.textScaleFactorTestValue = 1.0;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      debugIsWebOverride = null;
    }
  }, variant: variant, skip: skip);
}

// A widget test that runs for Windows web.
@isTestGroup
void testWidgetsOnWindowsWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    debugIsWebOverride = WebPlatformOverride.web;

    tester.view
      ..devicePixelRatio = 1.0
      ..platformDispatcher.textScaleFactorTestValue = 1.0;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      debugIsWebOverride = null;
    }
  }, variant: variant, skip: skip);
}

// A widget test that runs for Linux web.
@isTestGroup
void testWidgetsOnLinuxWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    debugIsWebOverride = WebPlatformOverride.web;

    tester.view
      ..devicePixelRatio = 1.0
      ..platformDispatcher.textScaleFactorTestValue = 1.0;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      debugIsWebOverride = null;
    }
  }, variant: variant, skip: skip);
}

/// A widget test that runs a variant for every desktop platform, e.g.,
/// Mac, Windows, Linux, and for all [TextInputSource]s.
@isTestGroup
void testAllInputsOnDesktop(
  String description,
  InputModeTesterCallback test, {
  bool skip = false,
}) {
  testWidgetsOnDesktop("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnDesktop("$description (IME)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.ime);
  }, skip: skip);
}

/// A widget test that runs as a Mac, and for all [TextInputSource]s.
@isTestGroup
void testAllInputsOnMac(
  String description,
  InputModeTesterCallback test, {
  bool skip = false,
}) {
  testWidgetsOnMac("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnMac("$description (IME)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.ime);
  }, skip: skip);
}

/// A widget test that runs a variant for Windows and Linux, and for all [TextInputSource]s.
@isTestGroup
void testAllInputsOnWindowsAndLinux(
  String description,
  InputModeTesterCallback test, {
  bool skip = false,
}) {
  testWidgetsOnWindowsAndLinux("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnWindowsAndLinux("$description (IME)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.ime);
  }, skip: skip);
}

typedef InputModeTesterCallback = Future<void> Function(
  WidgetTester widgetTester, {
  required TextInputSource inputSource,
});
