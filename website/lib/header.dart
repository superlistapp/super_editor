import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 1113),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/logo.gif',
            width: 188,
            height: 44,
          ),
          DefaultTextStyle(
            style: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 16,
              color: Colors.white,
            ),
            child: Row(
              children: [
                Text('Github'),
                const SizedBox(width: 26),
                Text('Docs'),
                const SizedBox(width: 26),
                _SmallButton(child: Text('Download')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  _SmallButton({@required this.child}) : assert(child != null);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      color: const Color(0xFFFAE74F),
      onPressed: () {},
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 42,
      elevation: 0,
      child: DefaultTextStyle(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          height: 1.4,
          color: const Color(0xFF0D2C3A),
        ),
        child: child,
      ),
    );
  }
}