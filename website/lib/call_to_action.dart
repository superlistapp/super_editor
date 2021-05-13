import 'package:flutter/material.dart';

class CallToAction extends StatelessWidget {
  const CallToAction();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF14AEBE),
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 76),
          Text(
            'Get started with SuperEditor',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 51,
              color: const Color(0xFF003F51),
            ),
          ),
          const SizedBox(height: 29),
          const _DownloadButton(),
          const SizedBox(height: 104),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton();

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: const Color(0xFFFAE74F),
      onPressed: () {},
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 42,
      elevation: 0,
      child: Text(
        'Download Now',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 29,
          color: const Color(0xFF0D2C3A),
        ),
      ),
    );
  }
}
