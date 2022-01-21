import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class TextInlineWidgetDemo extends StatefulWidget {
  @override
  _TextInlineWidgetDemoState createState() => _TextInlineWidgetDemoState();
}

class _TextInlineWidgetDemoState extends State<TextInlineWidgetDemo> {
  final _paragraphKey = GlobalKey();
  final _inlineCodeKey = GlobalKey();

  final _inlineCodePrefix = "Use the ";
  final _inlineCodePostfix = " widget to get started with Super Editor";
  void _onTextTapUp(TapUpDetails details) {
    print("Tap offset: ${details.localPosition}");
    final renderParagraph = _paragraphKey.currentContext!.findRenderObject() as RenderParagraph;
    final tapTextPosition = renderParagraph.getPositionForOffset(details.localPosition);
    print("Tap text position: $tapTextPosition");

    const inlineCodeTextOffset = 8; // Reminder: this means "8, downstream" and "9, upstream"
    final didTapInlineCodeSpan =
        (tapTextPosition.offset == inlineCodeTextOffset && tapTextPosition.affinity == TextAffinity.downstream) ||
            (tapTextPosition.offset == inlineCodeTextOffset + 1 && tapTextPosition.affinity == TextAffinity.upstream);

    if (!didTapInlineCodeSpan) {
      late String letter;
      if (tapTextPosition.offset < _inlineCodePrefix.length) {
        letter = tapTextPosition.affinity == TextAffinity.downstream
            ? _inlineCodePrefix[tapTextPosition.offset]
            : _inlineCodePrefix[tapTextPosition.offset - 1];
      } else {
        letter = tapTextPosition.affinity == TextAffinity.downstream
            ? _inlineCodePostfix[tapTextPosition.offset - _inlineCodePrefix.length - 1]
            : _inlineCodePostfix[tapTextPosition.offset - _inlineCodePrefix.length - 2];
      }
      print("You tapped '$letter'");
      return;
    }

    print("You tapped the inline code");
    final inlineCodeRenderParagraph = _inlineCodeKey.currentContext!.findRenderObject() as RenderParagraph;
    final inlineCodeOffset = inlineCodeRenderParagraph.globalToLocal(details.globalPosition);
    final inlineCodeTextPosition = inlineCodeRenderParagraph.getPositionForOffset(inlineCodeOffset);
    print("Inline code text position: $inlineCodeTextPosition");
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageExample(),
            const SizedBox(height: 24),
            _buildAvatarExample(),
            const SizedBox(height: 24),
            _buildProgressExample(),
            const SizedBox(height: 24),
            GestureDetector(
              onTapUp: _onTextTapUp,
              child: _buildInlineCodeExample(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageExample() {
    return SelectableText.rich(
      TextSpan(
        text: "Sponsored by ",
        style: const TextStyle(
          color: Colors.black,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            child: SizedBox(
              height: 22,
              child: Image.asset("assets/images/superlist_logo.png"),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }

  Widget _buildAvatarExample() {
    return SelectableText.rich(
      TextSpan(
        text: "We asked ",
        style: const TextStyle(
          color: Colors.black,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4, right: 8),
              decoration: const ShapeDecoration(
                shape: StadiumBorder(),
                color: Colors.yellow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.account_circle,
                    size: 14,
                    color: Colors.black,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "@SuprDeclarative",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TextSpan(text: " and he said we're good."),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }

  Widget _buildProgressExample() {
    return SelectableText.rich(
      TextSpan(
        text: "This is a multi-step item with progress",
        style: const TextStyle(
          color: Colors.black,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                SizedBox(width: 8),
                Icon(Icons.check_circle, color: Colors.green, size: 14),
                SizedBox(width: 4),
                Text(
                  "2/2",
                  style: TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }

  Widget _buildInlineCodeExample() {
    return SelectableText.rich(
      TextSpan(
        text: _inlineCodePrefix,
        style: const TextStyle(
          color: Colors.black,
        ),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF888888),
              ),
              child: Text(
                "super_editor",
                key: _inlineCodeKey,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'UbuntuMono',
                ),
              ),
            ),
          ),
          TextSpan(text: _inlineCodePostfix),
        ],
      ),
      key: _paragraphKey,
      textAlign: TextAlign.start,
    );
  }
}
