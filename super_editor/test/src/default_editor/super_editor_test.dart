import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:super_editor/super_editor.dart';

void main() {
  group('SuperEditor', () {
    group('autofocus tests -', () {
      group('does not claim focus when autofocus = false -', () {
        testWidgets('Keyboard Input Source', (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: DocumentEditor(document: MutableDocument(nodes: [])),
                  focusNode: focusNode,
                  inputSource: DocumentInputSource.keyboard,
                  autofocus: false,
                ),
              ),
            ),
          );

          expect(focusNode.hasFocus, false);
        });

        testWidgets('IME Input Source', (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: DocumentEditor(document: MutableDocument(nodes: [])),
                  focusNode: focusNode,
                  inputSource: DocumentInputSource.ime,
                  autofocus: false,
                ),
              ),
            ),
          );

          expect(focusNode.hasFocus, false);
        });
      });

      group('claims focus when autofocus = true - ', () {
        testWidgets('Keyboard Input Source', (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: DocumentEditor(document: MutableDocument(nodes: [])),
                  focusNode: focusNode,
                  inputSource: DocumentInputSource.keyboard,
                  autofocus: true,
                ),
              ),
            ),
          );

          expect(focusNode.hasFocus, true);
        });

        testWidgets('IME Input Source', (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: DocumentEditor(document: MutableDocument(nodes: [])),
                  focusNode: focusNode,
                  inputSource: DocumentInputSource.ime,
                  autofocus: true,
                ),
              ),
            ),
          );

          expect(focusNode.hasFocus, true);
        });
      });

      group('claims focus by pointer when autofocus = false -', () {
        testWidgets('Mouse Gesture Mode', (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: DocumentEditor(document: MutableDocument(nodes: [])),
                  focusNode: focusNode,
                  gestureMode: DocumentGestureMode.mouse,
                  autofocus: false,
                ),
              ),
            ),
          );

          await tester.tap(find.byType(SuperEditor));
          await tester.pumpAndSettle();

          expect(focusNode.hasFocus, true);
        });
        testWidgets('Android Gesture Mode', (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: DocumentEditor(document: MutableDocument(nodes: [])),
                  focusNode: focusNode,
                  gestureMode: DocumentGestureMode.android,
                  inputSource: DocumentInputSource.ime,
                  autofocus: false,
                ),
              ),
            ),
          );

          await tester.tap(find.byType(SuperEditor));
          await tester.pumpAndSettle();

          expect(focusNode.hasFocus, true);
        });

        testWidgets('iOS Gesture Mode', (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: DocumentEditor(document: MutableDocument(nodes: [])),
                  focusNode: focusNode,
                  gestureMode: DocumentGestureMode.iOS,
                  inputSource: DocumentInputSource.ime,
                  autofocus: false,
                ),
              ),
            ),
          );

          await tester.tap(find.byType(SuperEditor));
          await tester.pumpAndSettle();

          expect(focusNode.hasFocus, true);
        });
      });
    });
  });
}
