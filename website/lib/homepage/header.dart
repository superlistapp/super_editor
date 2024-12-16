import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Header extends StatelessWidget {
  const Header({required this.displayCollapsedNavigation});
  final bool displayCollapsedNavigation;

  @override
  Widget build(BuildContext context) {
    return Container(
      // TODO: move magic number to a named constant
      constraints: const BoxConstraints(maxWidth: 1113),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLogo(),
          if (!displayCollapsedNavigation) _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.gif',
      width: 188,
      height: 44,
    );
  }

  Widget _buildNavBar() {
    return const Row(
      children: [
        _Link(
          url: 'https://github.com/superlistapp/super_editor',
          child: Text('Github'),
        ),
        SizedBox(width: 8),
        _Link(
          url: 'https://github.com/superlistapp/super_editor/wiki',
          child: Text('Docs'),
        ),
        SizedBox(width: 16),
        _DownloadButton(),
      ],
    );
  }
}

class DrawerLayout extends StatefulWidget {
  const DrawerLayout({
    required this.isNavigationCollapsed,
    required this.child,
  });

  final bool isNavigationCollapsed;
  final Widget child;

  @override
  _DrawerLayoutState createState() => _DrawerLayoutState();
}

class _DrawerLayoutState extends State<DrawerLayout> {
  bool _open = false;

  void _toggle() {
    setState(() {
      _open = !_open;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!widget.isNavigationCollapsed) {
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
              color: Colors.black.withValues(alpha: _open ? 0.64 : 0),
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
        Positioned(
          top: 30,
          left: 20,
          right: 20,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_open,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              opacity: _open ? 1 : 0,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Image.asset(
                      'assets/images/logo_light_bg.gif',
                      width: 188,
                      height: 44,
                    ),
                  ),
                  const Column(
                    children: [
                      SizedBox(height: 16),
                      _Link(
                        url: 'https://github.com/superlistapp/super_editor',
                        child: Text('Github'),
                      ),
                      SizedBox(height: 8),
                      _Link(
                        url: 'https://github.com/superlistapp/super_editor/wiki',
                        child: Text('Docs'),
                      ),
                      SizedBox(height: 16),
                      _DownloadButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 30,
          right: 20,
          child: IconButton(
            icon: _open ? const Icon(Icons.close) : const Icon(Icons.menu_rounded),
            iconSize: 28,
            color: Colors.white,
            onPressed: _toggle,
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.url, required this.child});
  final String url;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => launchUrl(Uri.parse(url)),
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.all(Colors.white),
        minimumSize: MaterialStateProperty.all(const Size(72, 48)),
        textStyle: MaterialStateProperty.all(
          const TextStyle(
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
      onPressed: () => launchUrl(Uri.parse('https://pub.dev/packages/super_editor')),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
      height: 52,
      elevation: 0,
      child: const Text(
        'pub.dev',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF0D2C3A),
        ),
      ),
    );
  }
}
