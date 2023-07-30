import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:meta/meta.dart';

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
