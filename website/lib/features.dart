import 'package:flutter/material.dart';

class Features extends StatelessWidget {
  const Features();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF003F51),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      child: Transform.translate(
        offset: Offset(0, -49),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1113),
                child: Wrap(
                  spacing: 64,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 499),
                      child: const _Feature(
                        iconPath: 'assets/images/ic_customize.png',
                        title: 'Fully customizable',
                        description:
                            'Easy to extend and very detailed access to all component, designed to and build for developer, allow you to adjust the editor to your specific needs',
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 515),
                      child: const _Feature(
                        iconPath: 'assets/images/dart_logo.png',
                        title: 'Fully written in Dart',
                        description:
                            'A true cross platform editor written from scratch to deliver the performance and stability you expect',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 44),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 544),
                        child: Column(
                          children: [
                            Text(
                              'Other great things about this babyyyyyyyyyy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 38,
                                height: 46 / 38,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 37),
                            SizedBox(
                              width: 544,
                              height: 307,
                              child: Placeholder(),
                            ),
                            const SizedBox(height: 31),
                            Text(
                              'Lorem ipsum home school stay-at-home order Blursday. Staycation stimulus essential. Dr. Fauci remote learning WHO isolation mail-in vote. Virtual happy hour Quibi four seasons total landscaping monolith home office.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 19),
                            ),
                          ],
                        ),
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
    @required this.iconPath,
    @required this.title,
    @required this.description,
  })  : assert(iconPath != null),
        assert(title != null),
        assert(description != null);

  final String iconPath;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF053239),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(24),
          child: Image.asset(
            iconPath,
            width: 48,
            height: 48,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 38,
            height: 46 / 38,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
