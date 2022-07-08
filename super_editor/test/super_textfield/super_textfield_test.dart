import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

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
              child: const SuperTextField(),
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
              child: const SuperTextField(),
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
              child: const SuperTextField(),
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
              ),
            ),
          );

          expect(find.byType(SuperIOSTextField), findsOneWidget);
        });
      });
    });

    group("on mobile", () {
      group("configures inner textfield textInputAction for newline when it's multiline", () {
        testWidgetsOnAndroid('(on Android)', (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                minLines: 10,
                maxLines: 10,
              ),
            ),
          );
          
          final innerTextField = tester.widget<SuperAndroidTextField>(find.byType(SuperAndroidTextField).first);

          // Ensure inner textfield action is configured to newline
          // so we are able to receive new lines
          expect(innerTextField.textInputAction, TextInputAction.newline);
        });

        testWidgetsOnIos('(on iOS)', (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                minLines: 10,
                maxLines: 10,
              ),
            ),
          );
          final innerTextField = tester.widget<SuperIOSTextField>(find.byType(SuperIOSTextField).first);

          // Ensure inner textfield action is configured to newline
          // so we are able to receive new lines
          expect(innerTextField.textInputAction, TextInputAction.newline);
        });
      });

      group("configures inner textfield textInputAction for done when it's singleline", () {
        testWidgetsOnAndroid('(on Android)', (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                minLines: 1,
                maxLines: 1,
              ),
            ),
          );

          final innerTextField = tester.widget<SuperAndroidTextField>(find.byType(SuperAndroidTextField).first);

          // Ensure inner textfield action is configured to done
          // because we should NOT receive new lines
          expect(innerTextField.textInputAction, TextInputAction.done);
        });

        testWidgetsOnIos('(on iOS)', (tester) async {
          await tester.pumpWidget(
            _buildScaffold(
              child: const SuperTextField(
                minLines: 1,
                maxLines: 1,
              ),
            ),
          );
          final innerTextField = tester.widget<SuperIOSTextField>(find.byType(SuperIOSTextField).first);

          // Ensure inner textfield action is configured to done
          // because we should NOT receive new lines
          expect(innerTextField.textInputAction, TextInputAction.done);
        });
      });
    });

    group("selection", () {
      testWidgetsOnAllPlatforms("is inserted automatically when the field is initialized with focus", (tester) async {
        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: FocusNode()..requestFocus(),
            ),
          ),
        );
        await tester.pump();

        expect(_isCaretPresent(tester), isTrue);
      });

      testWidgetsOnAllPlatforms("is inserted automatically when the field is given focus", (tester) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          _buildScaffold(
            child: SuperTextField(
              focusNode: focusNode,
            ),
          ),
        );
        await tester.pump();

        expect(_isCaretPresent(tester), isFalse);

        focusNode.requestFocus();
        await tester.pumpAndSettle();

        expect(_isCaretPresent(tester), isTrue);
      });
    });

    group("padding for ", () {
      group("mobile ", () {
        testWidgetsOnMobile('receive focus on tap with default insets', (tester) async {
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

        testWidgetsOnMobile('receive focus on tap with custom insets', (tester) async {
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
      body: SizedBox(
        width: 300,
        child: child,
      ),
    ),
  );
}

bool _isCaretPresent(WidgetTester tester) {
  final caretMatches = find.byType(TextLayoutCaret).evaluate();
  if (caretMatches.isEmpty) {
    return false;
  }
  final caretState = (caretMatches.single as StatefulElement).state as TextLayoutCaretState;
  return caretState.isCaretPresent;
}
