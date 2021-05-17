import 'package:flutter/material.dart';

const _breakpoint = 768;

class CallToAction extends StatelessWidget {
  const CallToAction();

  @override
  Widget build(BuildContext context) {
    final isNarrowScreen = MediaQuery.of(context).size.width <= _breakpoint;

    return Container(
      color: const Color(0xFF14AEBE),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          SizedBox(height: isNarrowScreen ? 28 : 76),
          SelectableText(
            'Get started with SuperEditor',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isNarrowScreen ? 38 : 51,
              color: const Color(0xFF003F51),
            ),
          ),
          const SizedBox(height: 29),
          const _DownloadButton(),
          SizedBox(height: isNarrowScreen ? 60 : 104),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton();

  @override
  Widget build(BuildContext context) {
    final isNarrowScreen = MediaQuery.of(context).size.width <= _breakpoint;

    return MaterialButton(
      color: const Color(0xFFFAE74F),
      onPressed: () {},
      padding: isNarrowScreen
          ? const EdgeInsets.symmetric(horizontal: 32, vertical: 20)
          : const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 42,
      elevation: 0,
      child: const Text(
        'Download Now',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 29,
          color: Color(0xFF0D2C3A),
        ),
      ),
    );
  }
}
