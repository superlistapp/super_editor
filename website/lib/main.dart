import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:website/homepage/home_page.dart';

void main() {
  setUrlStrategy(PathUrlStrategy());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperEditor - A supercharged rich text editor for Flutter',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Aeonik'),
      home: const HomePage(),
    );
  }
}
