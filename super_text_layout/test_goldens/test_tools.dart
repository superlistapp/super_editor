import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:meta/meta.dart';
import 'package:super_text_layout/super_text_layout.dart';

// Everything in this file is duplicated between /test and /test_goldens because
// imports can't cross those directories. When we get goldens working cross-platform,
// de-dup these definitions.

const defaultSelectionColor = Color(0xFFACCEF7);

/// A golden test that configures itself as a Android platform before executing the
/// given [test], and nullifies the Android configuration when the test is done.
@isTest
void testGoldensOnAndroid(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a iOS platform before executing the
/// given [test], and nullifies the iOS configuration when the test is done.
@isTest
void testGoldensOniOS(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a Mac platform before executing the
/// given [test], and nullifies the Mac configuration when the test is done.
@isTest
void testGoldensOnMac(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a Windows platform before executing the
/// given [test], and nullifies the Windows configuration when the test is done.
@isTest
void testGoldensOnWindows(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

/// A golden test that configures itself as a Linux platform before executing the
/// given [test], and nullifies the Linux configuration when the test is done.
@isTest
void testGoldensOnLinux(
  String description,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testGoldens(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await test(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

Future<void> pumpThreeLinePlainSuperText(
  WidgetTester tester, {
  SuperTextLayerBuilder? beneathBuilder,
  SuperTextLayerBuilder? aboveBuilder,
}) async {
  await tester.pumpWidget(
    buildTestScaffold(
      child: SuperText(
        key: superTextKey,
        richText: threeLineTextSpan,
        layerBeneathBuilder: beneathBuilder,
        layerAboveBuilder: aboveBuilder,
      ),
    ),
  );
}

Future<void> pumpEmptySuperText(
  WidgetTester tester, {
  SuperTextLayerBuilder? beneathBuilder,
  SuperTextLayerBuilder? aboveBuilder,
}) async {
  await tester.pumpWidget(
    buildTestScaffold(
      child: SuperText(
        key: superTextKey,
        richText: const TextSpan(text: "", style: _testTextStyle),
        layerBeneathBuilder: beneathBuilder,
        layerAboveBuilder: aboveBuilder,
      ),
    ),
  );
}

final superTextKey = GlobalKey(debugLabel: "super_text");

const threeLineTextSpan = TextSpan(
  text: "This is some text. It is explicitly laid out in\n" // Line indices: 0 -> 47/48 (upstream/downstream)
      "multiple lines so that we don't need to guess\n" // Line indices: 48 ->  93/94 (upstream/downstream)
      "where the layout forces a line break", // Line indices: 94 -> 130
  style: _testTextStyle,
);

const _testTextStyle = TextStyle(
  color: Color(0xFF000000),
  fontFamily: 'Roboto',
  fontSize: 20,
  height: 1.4,
);

Widget buildTestScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: child,
      ),
    ),
    debugShowCheckedModeBanner: false,
  );
}
