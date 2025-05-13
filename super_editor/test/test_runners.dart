import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:logging/logging.dart' as logging;
import 'package:meta/meta.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/platforms/platform.dart';
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
  testWidgetsOnMacWeb(description, test, skip: skip, variant: variant);
  testWidgetsOnWindowsWeb(description, test, skip: skip, variant: variant);
  testWidgetsOnLinuxWeb(description, test, skip: skip, variant: variant);
}

/// A widget test that runs a variant for every mobile platform on web, e.g.,
/// iOS, Android.
@isTestGroup
void testWidgetsOnWebMobile(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnWebIos(description, test, skip: skip, variant: variant);
  testWidgetsOnWebAndroid(description, test, skip: skip, variant: variant);
}

@isTestGroup
void testWidgetsOnMacDesktopAndWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnMac(description, test, skip: skip, variant: variant);
  testWidgetsOnMacWeb(description, test, skip: skip, variant: variant);
}

@isTestGroup
void testWidgetsOnMacWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets("$description (on MAC Web)", (tester) async {
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

/// A widget test that runs a variant for Mac and iOS.
@isTestGroup
void testWidgetsOnApple(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnMac(description, test, variant: variant, skip: skip);
  testWidgetsOnIos(description, test, variant: variant, skip: skip);
}

@isTestGroup
void testWidgetsOnIosDeviceAndWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnIos(description, test, skip: skip, variant: variant);
  testWidgetsOnWebIos(description, test, skip: skip, variant: variant);
}

@isTestGroup
void testWidgetsOnWebIos(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets("$description (on iOS Web)", (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    debugIsWebOverride = WebPlatformOverride.web;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      debugIsWebOverride = null;
    }
  }, variant: variant, skip: skip);
}

@isTestGroup
void testWidgetsOnAndroidDeviceAndWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgetsOnAndroid(description, test, skip: skip, variant: variant);
  testWidgetsOnWebAndroid(description, test, skip: skip, variant: variant);
}

@isTestGroup
void testWidgetsOnWebAndroid(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets("$description (on Android Web)", (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    debugIsWebOverride = WebPlatformOverride.web;

    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      debugIsWebOverride = null;
    }
  }, variant: variant, skip: skip);
}

@isTestGroup
void testWidgetsOnWindowsWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets("$description (on Windows Web)", (tester) async {
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

@isTestGroup
void testWidgetsOnLinuxWeb(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets("$description (on Linux Web)", (tester) async {
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

/// A widget test that runs a variant for every platform
/// and for all [TextInputSource]s.
@isTestGroup
void testAllInputsOnAllPlatforms(
  String description,
  InputModeTesterCallback test, {
  bool skip = false,
}) {
  testWidgetsOnAllPlatforms("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnAllPlatforms("$description (IME)", (WidgetTester tester) async {
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

/// A widget test that runs as a Mac and iOS, and for all [TextInputSource]s.
@isTestGroup
void testAllInputsOnApple(
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

  testWidgetsOnIos("$description (keyboard)", (WidgetTester tester) async {
    await test(tester, inputSource: TextInputSource.keyboard);
  }, skip: skip);

  testWidgetsOnIos("$description (IME)", (WidgetTester tester) async {
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
