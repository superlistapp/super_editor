import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/attributed_text.dart';
import '../default_editor/text.dart';

/// Displays text in a document, and given `hintText` when there
/// is no content text and this component does not have the caret.
class TextWithHintComponent extends StatelessWidget {
  const TextWithHintComponent({
    Key key,
    @required this.documentComponentKey,
    this.text,
    this.textType,
    this.hintText,
    this.textAlign,
    this.textStyle = const TextStyle(),
    this.textSelection,
    this.hasCursor,
    this.highlightWhenEmpty,
    this.showDebugPaint,
  }) : super(key: key);

  final GlobalKey documentComponentKey;
  final AttributedText text;
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

    print('Building TextWithHintComponent with key: $documentComponentKey');
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Stack(
        children: [
          Text(
            hintText,
            textAlign: textAlign,
            style: style.copyWith(
              color: const Color(0xFFC3C1C1),
            ),
          ),
          Positioned.fill(
            child: TextComponent(
              key: documentComponentKey,
              text: text,
              textAlign: textAlign,
              textSelection: textSelection,
              hasCursor: hasCursor,
              textStyle: style,
              highlightWhenEmpty: highlightWhenEmpty,
              showDebugPaint: showDebugPaint,
            ),
          ),
        ],
      ),
    );
  }
}
