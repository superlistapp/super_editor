import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';
import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

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

    group("padding for ", () {
      group("mobile", () {
        testWidgetsOnMobile(
            'GIVEN Padding is default '
            'WHEN tap on SuperTextField '
            'THEN Focus is requested', (tester) async {
          final focusNode = FocusNode(debugLabel: 'SuperTextField FocusNode');

          await tester.pumpWidget(
            _buildScaffold(
              child: SuperTextField(
                focusNode: focusNode,
                lineHeight: 16,
              ),
            ),
          );

          expect(
            focusNode.hasPrimaryFocus,
            isFalse,
            reason: '`FocusNode` should NOT have focus yet',
          );

          await tester.tapSuperTextField();

          expect(
            focusNode.hasPrimaryFocus,
            isTrue,
            reason: '`FocusNode` should receive focus',
          );
        });

        testWidgetsOnMobile(
            'GIVEN Padding has Insets '
            'WHEN tap on Padding '
            'THEN Focus is requested', (tester) async {
          final focusNode = FocusNode(debugLabel: 'SuperTextField FocusNode');
          const padding = EdgeInsets.only(right: 20);

          await tester.pumpWidget(
            _buildScaffold(
              child: SuperTextField(
                focusNode: focusNode,
                padding: padding,
                lineHeight: 16,
              ),
            ),
          );

          final target = SuperTextFieldInspector.findPaddingRect(tester);

          expect(
            focusNode.hasPrimaryFocus,
            isFalse,
            reason: '`FocusNode` should NOT have focus yet',
          );

          await tester.tapSuperTextField(offset: target.center);

          expect(
            focusNode.hasPrimaryFocus,
            isTrue,
            reason: '`FocusNode` should receive focus',
          );
        });

        testWidgetsOnMobile(
            'GIVEN Padding has Insets '
            'WHEN tap on insets '
            'THEN Focus is  requested', (tester) async {
          final focusNode = FocusNode(debugLabel: 'SuperTextField FocusNode');
          const padding = EdgeInsets.only(right: 20);
          await tester.pumpWidget(
            _buildScaffold(
              child: SuperTextField(
                focusNode: focusNode,
                padding: padding,
                lineHeight: 16,
              ),
            ),
          );

          final insets = SuperTextFieldInspector.findPaddingInsetsRects(
            tester,
          );

          for (final inset in insets) {
            expect(
              focusNode.hasPrimaryFocus,
              isFalse,
              reason: '`FocusNode` should NOT have focus yet',
            );

            await tester.tapSuperTextField(offset: inset.center);

            expect(
              focusNode.hasPrimaryFocus,
              isTrue,
              reason: '`FocusNode` should receive focus',
            );

            focusNode.unfocus();
          }
        });
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
