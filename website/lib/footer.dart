import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
                        height: 21.6 / 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text:
                            'Superlist is building a new task manager for individuals and teams and we\'re doing it all in Flutter. ',
                        children: [
                          WidgetSpan(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => print('tappy tap'),
                                child: Text(
                                  'Join us',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    height: 20 / 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                        height: 20 / 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DefaultTextStyle.merge(
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 16,
              height: 20 / 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep up to date:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 21.6 / 18,
                  ),
                ),
                const SizedBox(height: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => print('twitter'),
                    child: Text(
                      'Twitter',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => print('twitter'),
                    child: Text(
                      'Superlist.com',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
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
