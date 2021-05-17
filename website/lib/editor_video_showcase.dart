import 'package:flutter/material.dart';
import 'package:website/breakpoints.dart';

class EditorVideoShowcase extends StatelessWidget {
  const EditorVideoShowcase();

  @override
  Widget build(BuildContext context) {
    final singleColumnLayout = Breakpoints.singleColumnLayout(context);

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
        SizedBox(height: singleColumnLayout ? 22 : 37),
        Container(
          constraints: const BoxConstraints(maxWidth: 544)
              .tighten(height: singleColumnLayout ? 212 : 307),
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
