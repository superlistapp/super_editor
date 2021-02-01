import 'package:example/spikes/editor_abstractions/selectable_text/selectable_text.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Displays text in a document, and given `hintText` when there
/// is no content text and this component does not have the caret.
class TextWithHintComponent extends StatelessWidget {
  const TextWithHintComponent({
    Key key,
    this.textKey,
    this.text,
    this.textType,
    this.hintText,
    this.textAlign,
    this.textStyle,
    this.textSelection,
    this.hasCursor,
    this.highlightWhenEmpty,
    this.showDebugPaint,
  }) : super(key: key);

  final GlobalKey textKey;
  final String text;
  final String textType;
  final String hintText;
  final TextAlign textAlign;
  final TextStyle textStyle;
  final TextSelection textSelection;
  final bool hasCursor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    TextStyle style = textStyle;
    switch (textType) {
      case 'header1':
        style = textStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        );
        break;
      default:
        break;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Stack(
        children: [
          Text(
            'Enter your title',
            textAlign: textAlign,
            style: style.copyWith(
              color: const Color(0xFFC3C1C1),
            ),
          ),
          Positioned.fill(
            child: SelectableText(
              key: textKey,
              text: text,
              textAlign: textAlign,
              textSelection: textSelection,
              hasCursor: hasCursor,
              style: style,
              highlightWhenEmpty: highlightWhenEmpty,
              showDebugPaint: showDebugPaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays text in a document.
///
/// This is the standard component for text display.
class TextComponent extends StatelessWidget {
  const TextComponent({
    Key key,
    this.textKey,
    this.text,
    this.textType,
    this.textAlign,
    this.textStyle,
    this.textSelection,
    this.hasCursor,
    this.highlightWhenEmpty,
    this.showDebugPaint,
  }) : super(key: key);

  final GlobalKey textKey;
  final String text;
  final String textType;
  final TextAlign textAlign;
  final TextStyle textStyle;
  final TextSelection textSelection;
  final bool hasCursor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    TextStyle style = textStyle;
    switch (textType) {
      case 'header1':
        style = textStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        );
        break;
      default:
        break;
    }

    return SelectableText(
      key: textKey,
      text: text,
      textAlign: textAlign,
      textSelection: textSelection,
      hasCursor: hasCursor,
      style: style,
      highlightWhenEmpty: highlightWhenEmpty,
      showDebugPaint: showDebugPaint,
    );
  }
}
