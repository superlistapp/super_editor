import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  runApp(ContentLayersDemoApp());
}

class ContentLayersDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Content Layers Demo App',
      home: ContentLayersDemoScreen(),
    );
  }
}

class ContentLayersDemoScreen extends StatefulWidget {
  const ContentLayersDemoScreen({Key? key}) : super(key: key);

  @override
  State<ContentLayersDemoScreen> createState() => _ContentLayersDemoScreenState();
}

class _ContentLayersDemoScreenState extends State<ContentLayersDemoScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..addStatusListener((status) {
        switch (status) {
          case AnimationStatus.dismissed:
            _animationController.forward();
            break;
          case AnimationStatus.completed:
            _animationController.reverse();
            break;
          case AnimationStatus.forward:
          case AnimationStatus.reverse:
            // no-op
            break;
        }
      });
    // ..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ContentLayers(
          content: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: lerpDouble(300, 600, _animationController.value),
                  height: lerpDouble(300, 600, _animationController.value),
                  color: Colors.red.withOpacity(0.5),
                );
              }),
          underlays: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.tealAccent,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.lightBlue,
                ),
              ),
            ),
          ],
          overlays: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.yellow,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purpleAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
