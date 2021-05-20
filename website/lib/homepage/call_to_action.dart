import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:website/breakpoints.dart';

class CallToAction extends StatelessWidget {
  const CallToAction();

  @override
  Widget build(BuildContext context) {
    final singleColumnLayout = Breakpoints.singleColumnLayout(context);

    return Container(
      color: const Color(0xFF14AEBE),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          SizedBox(height: singleColumnLayout ? 28 : 76),
          SelectableText(
            'Get started with SuperEditor',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: singleColumnLayout ? 38 : 51,
              color: const Color(0xFF003F51),
            ),
          ),
          const SizedBox(height: 29),
          const _DocumentationButton(),
          SizedBox(height: singleColumnLayout ? 60 : 104),
        ],
      ),
    );
  }
}

class _DocumentationButton extends StatelessWidget {
  const _DocumentationButton();

  @override
  Widget build(BuildContext context) {
    final singleColumnLayout = Breakpoints.singleColumnLayout(context);

    return MaterialButton(
      color: const Color(0xFFFAE74F),
      onPressed: () => launch(
        'https://github.com/superlistapp/super_editor/blob/main/super_editor/README.md',
      ),
      padding: singleColumnLayout
          ? const EdgeInsets.symmetric(horizontal: 32, vertical: 20)
          : const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 42,
      elevation: 0,
      child: const Text(
        'Documentation',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 29,
          color: Color(0xFF0D2C3A),
        ),
      ),
    );
  }
}
