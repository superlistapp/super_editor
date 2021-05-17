import 'package:flutter/material.dart';

const _breakpoint = 768;

class EditorVideoShowcase extends StatelessWidget {
  const EditorVideoShowcase();

  @override
  Widget build(BuildContext context) {
    final isNarrowScreen = MediaQuery.of(context).size.width <= _breakpoint;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: SelectableText(
            'See it in action',
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
          constraints: const BoxConstraints(maxWidth: 544)
              .tighten(height: isNarrowScreen ? 212 : 307),
          margin: const EdgeInsets.only(top: 44),
          decoration: BoxDecoration(
            color: const Color(0xFF053239),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Center(
            child: FlutterLogo(size: 64),
          ),
        ),
      ],
    );
  }
}
