import 'package:flutter/material.dart';
import 'package:website/call_to_action.dart';
import 'package:website/editor_showcase.dart';
import 'package:website/features.dart';
import 'package:website/footer.dart';
import 'package:website/header.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperEditor - A supercharged rich text editor for Flutter',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Aeonik'),
      home: const _Home(),
    );
  }
}

// Should match whatever is in header.dart
const _breakpoint = 540;

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final isNarrowScreen = MediaQuery.of(context).size.width <= _breakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFF003F51),
      body: DrawerLayout(
        child: Scrollbar(
          child: SingleChildScrollView(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 18,
                height: 27 / 18,
                color: Colors.white.withOpacity(0.9),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/background.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 30),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Header(),
                      ),
                      SizedBox(height: isNarrowScreen ? 16 : 52),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: EditorShowcase(),
                      ),
                      SizedBox(height: isNarrowScreen ? 92 : 135),
                      const Features(),
                      const CallToAction(),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Footer(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
