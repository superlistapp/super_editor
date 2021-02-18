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
    @required this.text,
    @required this.styleBuilder,
    this.metadata = const {},
    @required this.hintText,
    this.textAlign,
    this.textSelection,
    this.hasCursor,
    this.highlightWhenEmpty,
    this.showDebugPaint,
  }) : super(key: key);

  final GlobalKey documentComponentKey;
  final AttributedText text;
  final AttributionStyleBuilder styleBuilder;
  final Map<String, dynamic> metadata;
  final String hintText;
  final TextAlign textAlign;
  final TextSelection textSelection;
  final bool hasCursor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  Widget build(BuildContext context) {
    final blockType = metadata['blockType'];

    final blockLevelText = text
      ..copyText(0)
      ..addAttribution(blockType, TextRange(start: 0, end: text.text.length - 1));

    print('Building TextWithHintComponent with key: $documentComponentKey');
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Stack(
        children: [
          Text(
            hintText,
            textAlign: textAlign,
            style: styleBuilder({blockType}).copyWith(
              color: const Color(0xFFC3C1C1),
            ),
          ),
          Positioned.fill(
            child: TextComponent(
              key: documentComponentKey,
              text: blockLevelText,
              textAlign: textAlign,
              textSelection: textSelection,
              hasCaret: hasCursor,
              textStyleBuilder: styleBuilder,
              highlightWhenEmpty: highlightWhenEmpty,
              showDebugPaint: showDebugPaint,
            ),
          ),
        ],
      ),
    );
  }
}
