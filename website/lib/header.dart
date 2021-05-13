import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

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
            'assets/images/logo.gif',
            width: 188,
            height: 44,
          ),
          Row(
            children: [
              _Link(
                url: 'https://github.com/superlistapp/super_editor',
                child: Text('Github'),
              ),
              const SizedBox(width: 8),
              _Link(
                url: 'https://github.com/superlistapp/super_editor/wiki',
                child: Text('Docs'),
              ),
              const SizedBox(width: 16),
              const _DownloadButton(),
            ],
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({@required this.url, @required this.child})
      : assert(url != null),
        assert(child != null);

  final String url;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => launch(url),
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.all(Colors.white),
        minimumSize: MaterialStateProperty.all(const Size(72, 48)),
        textStyle: MaterialStateProperty.all(
          TextStyle(
            fontFamily: 'Aeonik',
            fontSize: 16,
          ),
        ),
      ),
      child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 52,
      elevation: 0,
      child: Text(
        'Download',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: const Color(0xFF0D2C3A),
        ),
      ),
    );
  }
}
