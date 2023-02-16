import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/blinking_caret.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_inspector.dart';
import 'package:super_editor/src/test/super_editor_test/supereditor_robot.dart';

import '../test_tools.dart';
import 'document_test_tools.dart';

void main() {
  group('SuperEditor', () {
    group('floating cursor', () {
      testWidgetsOnIos('hides caret when over text (on iOS)', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(300, 300))
            .pump();

        // Place caret at "|This is a paragraph".
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 0);

        // Moves the floating cursor to a position that is over text.
        final floatingCursor = _FloatingCursorSimulator();
        await floatingCursor.start();
        await tester.pump();
        await floatingCursor.moveTo(const Offset(10, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);
      });

      testWidgetsOnIos('hides caret when near text (on iOS)', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(300, 300))
            .pump();

        // Place caret at "This is a| paragraph".
        // This is the last position of the first line.
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 9);

        // Moves the floating cursor to a position that is close to the text.
        final floatingCursor = _FloatingCursorSimulator();
        await floatingCursor.start();
        await tester.pump();
        await floatingCursor.moveTo(const Offset(10, 0));
        await tester.pump();

        // Ensure the caret isn't displayed.
        expect(_caretFinder(), findsNothing);
      });

      testWidgetsOnIos('shows grey caret when far from text (on iOS)', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('This is a paragraph')
            .withEditorSize(const Size(300, 300))
            .pump();

        // Place caret at "This is a paragraph|".
        await tester.placeCaretInParagraph(SuperEditorInspector.findDocument()!.nodes.first.id, 9);

        // Moves the floating cursor to a position that is far from text.
        final floatingCursor = _FloatingCursorSimulator();
        await floatingCursor.start();
        await tester.pump();
        await floatingCursor.moveTo(const Offset(60, 0));
        await tester.pump();

        // Ensure the caret is displayed.
        expect(_caretFinder(), findsOneWidget);

        // Ensure the caret is grey.
        final caret = tester.widget<BlinkingCaret>(_caretFinder());
        expect(caret.color, Colors.grey);
      });
    });
  });
}

Finder _caretFinder() {
  return find.byType(BlinkingCaret);
}

class _FloatingCursorSimulator {
  /// Simulates the user holding the spacebar and starting the floating cursor gesture.
  ///
  /// The initial offset is at (0,0).
  Future<void> start() async {
    await _updateFloatingCursor(action: "FloatingCursorDragState.start", offset: Offset.zero);
  }

  /// Simulates the user swiping the spacebar by [offset].
  ///
  /// (0,0) means the point where the user started the gesture.
  Future<void> moveTo(Offset offset) async {
    await _updateFloatingCursor(action: "FloatingCursorDragState.update", offset: offset);
  }

  /// Simulates the user releasing the spacebar and stopping the floating cursor gesture.
  Future<void> stop() async {
    await _updateFloatingCursor(action: "FloatingCursorDragState.end", offset: Offset.zero);
  }

  Future<void> _updateFloatingCursor({required String action, required Offset offset}) async {
    await TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          "TextInputClient.updateFloatingCursor",
          [
            -1,
            action,
            {"X": offset.dx, "Y": offset.dy}
          ],
        ),
      ),
      null,
    );
  }
}
