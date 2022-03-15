import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:website/breakpoints.dart';

class Footer extends StatelessWidget {
  const Footer();

  @override
  Widget build(BuildContext context) {
    final singleColumnLayout = Breakpoints.singleColumnLayout(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 1113),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: singleColumnLayout
          ? Column(
              children: const [
                _LeftPart(),
                SizedBox(height: 28),
                _RightPart(),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _LeftPart(),
                _RightPart(),
              ],
            ),
    );
  }
}

class _LeftPart extends StatelessWidget {
  const _LeftPart();

  @override
  Widget build(BuildContext context) {
    final singleColumnLayout = Breakpoints.singleColumnLayout(context);

    final Widget result = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 539),
      child: Column(
        crossAxisAlignment: singleColumnLayout ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          const SelectableText(
            'Sponsored by the Superlist Team',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text:
                  "Superlist is building a new task manager for individuals and teams and we're doing it all in Flutter. ",
              children: [
                WidgetSpan(
                  child: Transform.translate(
                    // A pretty ugly hack to align this to match the text vertically.
                    offset: const Offset(0, 2),
                    child: const _Link(
                      'Join us',
                      url: 'https://superlist.recruitee.com',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      underlineWidth: 2,
                      underlineColor: Colors.white,
                      underlineSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 16),
            textAlign: singleColumnLayout ? TextAlign.center : TextAlign.start,
          ),
        ],
      ),
    );

    return singleColumnLayout ? Center(child: result) : result;
  }
}

class _RightPart extends StatelessWidget {
  const _RightPart();

  @override
  Widget build(BuildContext context) {
    final singleColumnLayout = Breakpoints.singleColumnLayout(context);

    final Widget result = DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16),
      textAlign: singleColumnLayout ? TextAlign.center : TextAlign.start,
      child: Column(
        crossAxisAlignment: singleColumnLayout ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: const [
          SelectableText(
            'Keep up to date:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          _Link('Superlist.com', url: 'https://superlist.com'),
          SizedBox(height: 4),
          _Link('Twitter', url: 'https://twitter.com/SuperlistHQ'),
        ],
      ),
    );

    return singleColumnLayout ? Center(child: result) : result;
  }
}

// A widget that allows specifying a margin between the provided text and the
// line that's drawn under it.
class _Link extends StatelessWidget {
  const _Link(
    this.text, {
    required this.url,
    this.style,
    this.underlineColor = const Color(0xAAFFFFFF),
    this.underlineWidth = 1.5,
    this.underlineSpacing = 1,
  });

  final String text;
  final String url;
  final TextStyle? style;
  final Color underlineColor;
  final double underlineWidth;
  final double underlineSpacing;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => launch(url),
        child: IntrinsicWidth(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(text, style: style),
              Positioned(
                left: 0,
                right: 0,
                bottom: -underlineSpacing,
                height: underlineWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: underlineColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
