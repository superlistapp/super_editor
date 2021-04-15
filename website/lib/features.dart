import 'package:flutter/material.dart';

class Features extends StatelessWidget {
  const Features();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF003F51),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(bottom: 80),
      child: Transform.translate(
        offset: Offset(0, -49),
        child: Center(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1112),
                child: Row(
                  children: [
                    Expanded(child: const _Feature()),
                    const SizedBox(width: 24),
                    Expanded(child: const _Feature()),
                  ],
                ),
              ),
              const SizedBox(height: 117),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 544),
                child: Column(
                  children: [
                    Text(
                      'other great things about this babyyyyyyyyyy',
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature();

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
            'assets/ic_customize.png',
            width: 48,
            height: 48,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Fully customizable',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 38,
            height: 46 / 38,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Easy to extend and very detailed access to all component, designed to and build for developer, allow you to adjust the editor to your specific needs',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
