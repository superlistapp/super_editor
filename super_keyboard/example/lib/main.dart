import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_keyboard/super_keyboard.dart';

void main() {
  runApp(const SuperKeyboardDemoApp());
}

class SuperKeyboardDemoApp extends StatefulWidget {
  const SuperKeyboardDemoApp({super.key});

  @override
  State<SuperKeyboardDemoApp> createState() => _SuperKeyboardDemoAppState();
}

class _SuperKeyboardDemoAppState extends State<SuperKeyboardDemoApp> {
  bool _closeOnOutsideTap = true;

  @override
  void initState() {
    super.initState();

    initSuperKeyboard();
  }

  Future<void> initSuperKeyboard() async {
    SuperKeyboard.initLogs();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: defaultTargetPlatform != TargetPlatform.android,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildKeyboardStateIcon(),
                const SizedBox(height: 12),
                SuperKeyboardBuilder(
                  builder: (context, keyboardState) {
                    return Text("Keyboard state: $_keyboardState");
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder(
                  valueListenable: SuperKeyboard.instance.keyboardHeight,
                  builder: (context, value, child) {
                    return Text("Keyboard height: ${value != null ? "${value.toInt()}" : "???"}");
                  },
                ),
                const SizedBox(height: 48),
                TextField(
                  decoration: const InputDecoration(
                    hintText: "Type some text",
                  ),
                  onTapOutside: (_) {
                    if (_closeOnOutsideTap) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildCloseOnFocusOption(),
                ValueListenableBuilder(
                  valueListenable: SuperKeyboard.instance.keyboardHeight,
                  builder: (context, value, child) {
                    if (value == null) {
                      return const SizedBox();
                    }

                    return SizedBox(height: value / MediaQuery.of(context).devicePixelRatio);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardStateIcon() {
    return ValueListenableBuilder(
      valueListenable: SuperKeyboard.instance.state,
      builder: (context, value, child) {
        final icon = switch (value) {
          KeyboardState.closed => Icons.border_bottom,
          KeyboardState.opening => Icons.upload_sharp,
          KeyboardState.open => Icons.border_top,
          KeyboardState.closing => Icons.download_sharp,
        };

        return Icon(
          icon,
          size: 24,
        );
      },
    );
  }

  String get _keyboardState {
    return switch (SuperKeyboard.instance.state.value) {
      KeyboardState.closed => "Closed",
      KeyboardState.opening => "Opening",
      KeyboardState.open => "Open",
      KeyboardState.closing => "Closing",
    };
  }

  Widget _buildCloseOnFocusOption() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        const Text('Close keyboard on outside tap'),
        Switch(
          value: _closeOnOutsideTap,
          onChanged: (newValue) {
            setState(() {
              _closeOnOutsideTap = newValue;
            });
          },
        ),
      ],
    );
  }
}
