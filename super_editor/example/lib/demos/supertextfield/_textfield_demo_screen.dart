import 'package:flutter/material.dart';

class TextFieldDemoScreen extends StatelessWidget {
  const TextFieldDemoScreen({
    Key? key,
    this.menuItems = const [],
    this.child,
  }) : super(key: key);

  final List<DemoMenuItem> menuItems;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: child,
            ),
          ),
          Container(
            width: 250,
            height: double.infinity,
            color: Colors.redAccent,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    _buildTitle('SuperTextField'),
                    const SizedBox(height: 24),
                    for (final menuItem in menuItems) ...[
                      _buildButton(
                        label: menuItem.label,
                        onPressed: menuItem.onPressed,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class DemoMenuItem {
  DemoMenuItem({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;
}
