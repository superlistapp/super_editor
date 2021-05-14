import 'package:flutter/material.dart';

const _breakpoint = 768;

class Features extends StatelessWidget {
  const Features();

  @override
  Widget build(BuildContext context) {
    final isNarrowScreen = MediaQuery.of(context).size.width <= _breakpoint;

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
                      child: _Feature(
                        image: Image.asset(
                          'assets/images/ic_customize.png',
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                        ),
                        title: 'Fully customizable',
                        description:
                            'Easy to extend and very detailed access to all component, designed to and build for developer, allow you to adjust the editor to your specific needs',
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 515),
                      child: _Feature(
                        image: Image.asset(
                          'assets/images/dart_logo.png',
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                        ),
                        title: 'Fully written in Dart',
                        description:
                            'A true cross platform editor written from scratch to deliver the performance and stability you expect',
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: isNarrowScreen ? 45 : 85,
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: SelectableText(
                            'Other great things about this babyyyyyy',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 38,
                              height: 46 / 38,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: isNarrowScreen ? 22 : 37),
                        Container(
                          constraints: BoxConstraints(maxWidth: 544)
                              .tighten(height: isNarrowScreen ? 212 : 307),
                          margin: const EdgeInsets.only(top: 44),
                          decoration: BoxDecoration(
                            color: const Color(0xFF053239),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: FlutterLogo(size: 64),
                          ),
                        ),
                        const SizedBox(height: 31),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 544),
                          child: SelectableText(
                            'Lorem ipsum home school stay-at-home order Blursday. Staycation stimulus essential. Dr. Fauci remote learning WHO isolation mail-in vote. Virtual happy hour Quibi four seasons total landscaping monolith home office.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 19),
                          ),
                        ),
                      ],
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
    @required this.image,
    @required this.title,
    @required this.description,
  })  : assert(image != null),
        assert(title != null),
        assert(description != null);

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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 38,
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
