import 'package:flutter/material.dart';

class Features extends StatelessWidget {
  const Features();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      child: Transform.translate(
        offset: const Offset(0, -49),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Wrap(
                  spacing: 64,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _Feature(
                        image: Image.asset(
                          'assets/images/ic_ready_to_go.png',
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                        ),
                        title: 'Ready to go!',
                        description: 'Want a typical editor experience? Drop in the default editor and go!',
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _Feature(
                        image: Image.asset(
                          'assets/images/ic_customize.png',
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                        ),
                        title: 'Customizable',
                        description: 'Your styles. Your interactions. Your editor. Compose it your way.',
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _Feature(
                        image: Image.asset(
                          'assets/images/dart_logo.png',
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                        ),
                        title: 'Pure Dart',
                        description:
                            'No plugins. No platform code. Anywhere you can take Flutter and Dart, you can take Super Editor',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.image,
    required this.title,
    required this.description,
  });

  final Widget image;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFF053239),
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: image,
        ),
        const SizedBox(height: 12),
        SelectableText(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 32,
            height: 46 / 38,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SelectableText(
          description,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
