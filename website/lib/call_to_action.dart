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
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 51,
              height: 61 / 51,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 29),
          _BigButton(child: Text('Download now')),
          const SizedBox(height: 104),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  _BigButton({@required this.child}) : assert(child != null);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: const Color(0xFFFAE74F),
      onPressed: () {},
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 42,
      elevation: 0,
      child: DefaultTextStyle(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 29,
          height: 1.26,
          color: const Color(0xFF0D2C3A),
        ),
        child: child,
      ),
    );
  }
}
