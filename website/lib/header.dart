import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';

const _breakpoint = 530;

class Header extends StatelessWidget {
  const Header();

  @override
  Widget build(BuildContext context) {
    final isNarrowScreen = MediaQuery.of(context).size.width <= _breakpoint;

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
          if (isNarrowScreen)
            IconButton(
              icon: Icon(Icons.menu_rounded),
              iconSize: 28,
              color: Colors.white,
              onPressed: () => DrawerLayout.show(context),
            )
          else
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

class DrawerLayout extends StatefulWidget {
  DrawerLayout({@required this.child}) : assert(child != null);
  final Widget child;

  static void show(BuildContext context) {
    context.findAncestorStateOfType<_DrawerLayoutState>()._show();
  }

  @override
  _DrawerLayoutState createState() => _DrawerLayoutState();
}

class _DrawerLayoutState extends State<DrawerLayout> {
  bool _open = false;

  void _show() {
    setState(() {
      _open = true;
    });
  }

  void _hide() {
    setState(() {
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNarrowScreen = size.width <= _breakpoint;

    if (!isNarrowScreen) {
      _open = false;
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_open,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              color: Colors.black.withOpacity(_open ? 0.64 : 0),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.fastOutSlowIn,
          top: _open ? 0 : -size.height,
          left: 0,
          right: 0,
          height: size.height,
          child: Container(color: const Color(0xFF003F51)),
        ),
        if (_open) ...[
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            bottom: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo.gif',
                      width: 188,
                      height: 44,
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      iconSize: 28,
                      color: Colors.white,
                      onPressed: _hide,
                    )
                  ],
                ),
                const SizedBox(height: 16),
                _Link(
                  url: 'https://github.com/superlistapp/super_editor',
                  child: Text('Github'),
                ),
                const SizedBox(height: 8),
                _Link(
                  url: 'https://github.com/superlistapp/super_editor/wiki',
                  child: Text('Docs'),
                ),
                const SizedBox(height: 16),
                const _DownloadButton(),
              ],
            ),
          ),
        ],
      ],
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
