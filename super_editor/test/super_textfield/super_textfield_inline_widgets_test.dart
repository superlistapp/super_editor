import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';

import 'super_textfield_inspector.dart';
import 'super_textfield_robot.dart';

void main() {
  group('SuperTextField > inline widgets >', () {
    testWidgetsOnAllPlatforms('renders single inline widget at beginning of the text', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'Hello',
          null,
          {
            0: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Ensure the widget was rendered.
      expect(
        find.byPlaceholderName('1'),
        findsOneWidget,
      );

      // Ensure the inline widget was rendered at the beginning of the textfield.
      final inlineWidgetRect = tester.getRect(find.byPlaceholderName('1'));
      expect(
        inlineWidgetRect.left,
        tester.getTopLeft(find.byType(SuperTextField)).dx,
      );
    });

    testWidgetsOnAllPlatforms('renders single inline widget at middle of the text', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'inline',
          null,
          {
            3: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Ensure the inline widget was rendered between characters at offsets
      // 2 and 3 of the original string.
      final inlineWidgetRect = tester.getRect(find.byPlaceholderName('1'));
      final (beforeInlineWidget, afterInlineWidget) = _getOffsetsAroundPosition(
        tester,
        const TextPosition(offset: 3),
      );
      expect(inlineWidgetRect.left, greaterThan(beforeInlineWidget.dx));
      expect(inlineWidgetRect.left, lessThan(afterInlineWidget.dx));
    });

    testWidgetsOnAllPlatforms('renders single inline widget at end of the text', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'Hello',
          null,
          {
            5: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Ensure the widget was rendered.
      expect(
        find.byPlaceholderName('1'),
        findsOneWidget,
      );

      // Ensure the inline widget was rendered at the end of the textfield.
      final inlineWidgetRect = tester.getRect(find.byPlaceholderName('1'));
      expect(
        inlineWidgetRect.left,
        _getOffsetAtPosition(tester, const TextPosition(offset: 5)).dx,
      );
    });

    testWidgetsOnAllPlatforms('renders multiple inline widgets', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'Hello',
          null,
          {
            0: const _NamedPlaceHolder('1'),
            6: const _NamedPlaceHolder('2'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Ensure the first widget was rendered.
      expect(
        find.byPlaceholderName('1'),
        findsOneWidget,
      );

      // Ensure the first inline widget was rendered at the beginning of the textfield.
      final firstInlineWidgetRect = tester.getRect(find.byPlaceholderName('1'));
      expect(
        firstInlineWidgetRect.left,
        tester.getTopLeft(find.byType(SuperTextField)).dx,
      );

      // Ensure the second widget was rendered.
      expect(
        find.byPlaceholderName('2'),
        findsOneWidget,
      );

      // Ensure the second inline widget was rendered at the end of the textfield.
      final secondInlineWidgetRect = tester.getRect(find.byPlaceholderName('2'));
      expect(
        secondInlineWidgetRect.left,
        _getOffsetAtPosition(tester, const TextPosition(offset: 6)).dx,
      );
    });

    testWidgetsOnAllPlatforms('places caret when tapping on inline widget', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'inline',
          null,
          {
            3: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Tap on the inline widget.
      await tester.tapAt(tester.getTopLeft(find.byPlaceholderName('1')));
      await tester.pump(kDoubleTapTimeout);

      // Ensure the caret is placed just before the inline widget.
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 3),
      );
    });

    testWidgetsOnDesktop('navigates using arrow keys', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'inline',
          null,
          {
            3: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Place caret at "in|line".
      await tester.placeCaretInSuperTextField(2);
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 2),
      );

      // Place RIGHT ARROW twice to move the caret to the position
      // immediately after the inline widget.
      await tester.pressRightArrow();
      await tester.pressRightArrow();

      // Ensure that the caret moved.
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 4),
      );

      // Place LEFT ARROW to move the caret back to the position
      // immediately before the inline widget.
      await tester.pressLeftArrow();

      // Ensure that the caret moved.
      expect(
        SuperTextFieldInspector.findSelection(),
        const TextSelection.collapsed(offset: 3),
      );
    });

    testWidgetsOnDesktop('deletes inline widget with backspace', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'inline',
          null,
          {
            3: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Ensure the widget is present.
      expect(
        find.byPlaceholderName('1'),
        findsOneWidget,
      );

      // Place the caret at the position immediately after the inline widget.
      await tester.placeCaretInSuperTextField(4);

      // Press backspace to remove the inline widget.
      await tester.pressBackspace();

      // Ensure the widget was not rendered.
      expect(
        find.byPlaceholderName('1'),
        findsNothing,
      );

      // Ensure the original text remains unmodified.
      expect(
        SuperTextFieldInspector.findText().toPlainText(),
        'inline',
      );
    });

    testWidgetsOnDesktop('deletes inline widget with delete', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'inline',
          null,
          {
            3: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Ensure the widget is present.
      expect(
        find.byPlaceholderName('1'),
        findsOneWidget,
      );

      // Place the caret before the inline widget.
      await tester.placeCaretInSuperTextField(3);

      // Press delete to remove the inline widget.
      await tester.pressDelete();

      // Ensure the widget was not rendered.
      expect(
        find.byPlaceholderName('1'),
        findsNothing,
      );

      // Ensure the original text remains unmodified.
      expect(
        SuperTextFieldInspector.findText().toPlainText(),
        'inline',
      );
    });

    testWidgetsOnDesktop('deletes inline widget inside expanded selection', (tester) async {
      final controller = AttributedTextEditingController(
        text: AttributedText(
          'before inline after',
          null,
          {
            10: const _NamedPlaceHolder('1'),
          },
        ),
      );

      await _pumpTestApp(tester, controller: controller);

      // Ensure the widget is present.
      expect(
        find.byPlaceholderName('1'),
        findsOneWidget,
      );

      // Place caret at "|inline".
      await tester.placeCaretInSuperTextField(7);

      // Press shift + right arrow to expand the selection to "|inl�ine|",
      // where "�" means the inline widget.
      await tester.pressShiftRightArrow();
      await tester.pressShiftRightArrow();
      await tester.pressShiftRightArrow();
      await tester.pressShiftRightArrow();
      await tester.pressShiftRightArrow();
      await tester.pressShiftRightArrow();
      await tester.pressShiftRightArrow();

      // Press backspace to remove the selected content.
      await tester.pressBackspace();

      // Ensure the widget was not rendered.
      expect(
        find.byPlaceholderName('1'),
        findsNothing,
      );

      // Ensure the text was updated.
      expect(
        SuperTextFieldInspector.findText().toPlainText(),
        'before  after',
      );
    });
  });
}

/// Pump a test app with a [SuperTextField] that renders a [ColoredBox] for each
/// [_NamedPlaceHolder] in the text.
Future<void> _pumpTestApp(
  WidgetTester tester, {
  required AttributedTextEditingController controller,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: SuperTextField(
            textController: controller,
            inlineWidgetBuilders: const [
              _boxPlaceHolderBuilder,
            ],
          ),
        ),
      ),
    ),
  );
}

/// A builder that renders a [ColoredBox] for a [_NamedPlaceHolder].
Widget? _boxPlaceHolderBuilder(BuildContext context, TextStyle textStyle, Object placeholder) {
  if (placeholder is! _NamedPlaceHolder) {
    return null;
  }

  return KeyedSubtree(
    key: ValueKey('placeholder-${placeholder.name}'),
    child: LineHeight(
      style: textStyle,
      child: const SizedBox(
        width: 24,
        child: ColoredBox(
          color: Colors.yellow,
        ),
      ),
    ),
  );
}

/// Returns the [Offset] of the given [textPosition] in the [SuperTextField],
/// in global coordinates.
Offset _getOffsetAtPosition(WidgetTester tester, TextPosition textPosition) {
  final renderBox = tester.renderObject(find.byType(SuperTextField)) as RenderBox;
  final textLayout = SuperTextFieldInspector.findProseTextLayout();

  return renderBox.localToGlobal(textLayout.getOffsetAtPosition(textPosition));
}

/// Returns the [Offset]s of the positions before and after the given [textPosition]
/// in the [SuperTextField], in global coordinates.
///
/// For example, for the text "world" and the position 2, this method will return
/// the offsets for the letters "o" and "l".
///
/// This method assumes that there are characters before and after the given position.
(Offset offsetBefore, Offset offsetAfter) _getOffsetsAroundPosition(WidgetTester tester, TextPosition textPosition) {
  final renderBox = tester.renderObject(find.byType(SuperTextField)) as RenderBox;
  final textLayout = SuperTextFieldInspector.findProseTextLayout();

  final offsetBefore = textLayout.getOffsetAtPosition(TextPosition(offset: textPosition.offset - 1));
  final offsetAfter = textLayout.getOffsetAtPosition(TextPosition(offset: textPosition.offset + 1));

  return (renderBox.localToGlobal(offsetBefore), renderBox.localToGlobal(offsetAfter));
}

/// A placeholder that is identified by a name.
class _NamedPlaceHolder {
  const _NamedPlaceHolder(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _NamedPlaceHolder && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

extension _WidgetForPlaceholderFinder on CommonFinders {
  /// Finds a widget that represents a placeholder with the given name.
  Finder byPlaceholderName(String name) {
    return byKey(ValueKey('placeholder-$name'));
  }
}
