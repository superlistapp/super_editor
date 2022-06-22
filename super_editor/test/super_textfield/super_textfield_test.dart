import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("SuperTextField", () {
    group("configures for", () {
      group("desktop", () {
        testWidgets("automatically", (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                lineHeight: 16,
              ),
            ),
          );

          expect(find.byType(SuperDesktopTextField), findsOneWidget);

          debugDefaultTargetPlatformOverride = null;
        });

        testWidgets("when requested", (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                configuration: SuperTextFieldPlatformConfiguration.desktop,
                lineHeight: 16,
              ),
            ),
          );

          expect(find.byType(SuperDesktopTextField), findsOneWidget);
        });
      });

      group("android", () {
        testWidgets("automatically", (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;

          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                lineHeight: 16,
              ),
            ),
          );

          expect(find.byType(SuperAndroidTextField), findsOneWidget);

          debugDefaultTargetPlatformOverride = null;
        });

        testWidgets("when requested", (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                configuration: SuperTextFieldPlatformConfiguration.android,
                lineHeight: 16,
              ),
            ),
          );

          expect(find.byType(SuperAndroidTextField), findsOneWidget);
        });
      });

      group("iOS", () {
        testWidgets("automatically", (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                lineHeight: 16,
              ),
            ),
          );

          expect(find.byType(SuperIOSTextField), findsOneWidget);

          debugDefaultTargetPlatformOverride = null;
        });

        testWidgets("when requested", (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                configuration: SuperTextFieldPlatformConfiguration.iOS,
                lineHeight: 16,
              ),
            ),
          );

          expect(find.byType(SuperIOSTextField), findsOneWidget);
        });
      });
    });

    group("tap & focus for", () {
      group("android", () {
        _testPaddingOnMobile(platform: TargetPlatform.android);
      });
      group("iOS", () {
        _testPaddingOnMobile(platform: TargetPlatform.iOS);
      });
    });
  });
}

Widget _buildScaffold({
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

Iterable<void> _testPaddingOnMobile({required TargetPlatform platform}) {
  return [
    testWidgets(
      'GIVEN Padding is default '
      'WHEN tap on SuperTextField '
      'THEN Focus is requested',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final focusNode = FocusNode(debugLabel: 'SuperTextField FocusNode');

        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: focusNode,
              lineHeight: 16,
            ),
          ),
        );

        final widgetFinder = find.byType(SuperTextField);
        final center = tester.getCenter(widgetFinder);

        expect(
          focusNode.hasPrimaryFocus,
          isFalse,
          reason: '`FocusNode` should NOT have focus yet',
        );

        await tester.tapAt(center);
        await tester.pumpAndSettle();

        expect(
          focusNode.hasPrimaryFocus,
          isTrue,
          reason: '`FocusNode` should receive focus',
        );

        debugDefaultTargetPlatformOverride = null;
      },
    ),
    testWidgets(
      'GIVEN Padding != zero ' 'WHEN tap in padded area ' 'THEN Focus is NOT requested',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;

        final focusNode = FocusNode(debugLabel: 'SuperTextField FocusNode');
        const padding = 20.0;

        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: focusNode,
              padding: const EdgeInsets.only(right: padding),
              lineHeight: 16,
            ),
          ),
        );

        final widgetFinder = find.byType(SuperTextField);
        final size = tester.getSize(widgetFinder);
        final center = tester.getCenter(widgetFinder);
        final centerOfPadding = (size.width - padding) / 2;
        final target = Offset(
          center.dx + centerOfPadding,
          center.dy,
        );

        expect(
          focusNode.hasPrimaryFocus,
          isFalse,
          reason: '`FocusNode` should NOT have focus yet',
        );

        await tester.tapAt(target);
        await tester.pumpAndSettle();

        expect(
          focusNode.hasPrimaryFocus,
          isFalse,
          reason: '`FocusNode` should NOT receive focus',
        );

        debugDefaultTargetPlatformOverride = null;
      },
    ),
    testWidgets(
      'GIVEN Padding != zero ' 'WHEN tap on Padding child ' 'THEN Focus is requested',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;

        final focusNode = FocusNode(debugLabel: 'SuperTextField FocusNode');
        const padding = 20.0;

        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: focusNode,
              padding: const EdgeInsets.only(right: padding),
              lineHeight: 16,
            ),
          ),
        );

        final widgetFinder = find.byType(SuperTextField);
        final center = tester.getCenter(widgetFinder);

        expect(
          focusNode.hasPrimaryFocus,
          isFalse,
          reason: '`FocusNode` should NOT have focus yet',
        );

        await tester.tapAt(center);
        await tester.pumpAndSettle();

        expect(
          focusNode.hasPrimaryFocus,
          isTrue,
          reason: '`FocusNode` should receive focus',
        );

        debugDefaultTargetPlatformOverride = null;
      },
    ),
    testWidgets(
      'GIVEN Padding any ' 'WHEN tap next to SuperTextField ' 'THEN Focus is NOT requested',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;

        final focusNode = FocusNode(debugLabel: 'SuperTextField FocusNode');
        const padding = 20.0;
        const justEnoughToTheSide = .1;

        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: focusNode,
              padding: const EdgeInsets.only(right: padding),
              lineHeight: 16,
            ),
          ),
        );

        final widgetFinder = find.byType(SuperTextField);
        final center = tester.getCenter(widgetFinder);
        final size = tester.getSize(widgetFinder);
        final tapRight = Offset(
          center.dx + size.width / 2 + justEnoughToTheSide,
          center.dy,
        );

        expect(
          focusNode.hasPrimaryFocus,
          isFalse,
          reason: '`FocusNode` should NOT have focus yet',
        );

        await tester.tapAt(tapRight);
        await tester.pumpAndSettle();

        expect(
          focusNode.hasPrimaryFocus,
          isFalse,
          reason: '`FocusNode` should NOT receive focus',
        );

        final tapLeft = Offset(
          center.dx - size.width / 2 - justEnoughToTheSide,
          center.dy,
        );

        await tester.tapAt(tapLeft);
        await tester.pumpAndSettle();

        expect(
          focusNode.hasPrimaryFocus,
          isFalse,
          reason: '`FocusNode` should NOT receive focus',
        );

        debugDefaultTargetPlatformOverride = null;
      },
    ),
  ];
}
