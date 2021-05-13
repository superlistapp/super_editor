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
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Aeonik'),
      home:  _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003F51),
      body: Scrollbar(
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
                  child: Image.asset(
                    'assets/images/background.png',
                    fit: BoxFit.contain,
                  ),
                ),
                Column(
                  children: [
                    SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Header(),
                    ),
                    SizedBox(height: 52),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: EditorShowcase(),
                    ),
                    SizedBox(height: 135),
                    Features(),
                    CallToAction(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Footer(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
