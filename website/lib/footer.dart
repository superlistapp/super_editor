import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';

class Footer extends StatelessWidget {
  const Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 1113),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 539),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                            'Superlist is building a new task manager for individuals and teams and we\'re doing it all in Flutter. ',
                        children: [
                          WidgetSpan(
                            child: Transform.translate(
                              // A pretty ugly hack to align this to match the text vertically.
                              offset: const Offset(0, 2),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => launch(
                                      'https://superlist.recruitee.com/'),
                                  child: _UnderlinedText(
                                    'Join us',
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
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep up to date:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => launch('https://twitter.com/SuperlistHQ'),
                    child: _UnderlinedText('Twitter'),
                  ),
                ),
                const SizedBox(height: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => launch('https://superlist.com'),
                    child: _UnderlinedText('Superlist.com'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// A widget that allows specifying a margin between the provided text and the
// line that's drawn under it.
class _UnderlinedText extends StatelessWidget {
  const _UnderlinedText(
    this.text, {
    this.style,
    this.underlineColor = const Color(0xAAFFFFFF),
    this.underlineWidth = 1.5,
    this.underlineSpacing = 1,
  });

  final String text;
  final TextStyle style;
  final Color underlineColor;
  final double underlineWidth;
  final double underlineSpacing;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
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
    );
  }
}
