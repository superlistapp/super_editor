import 'package:flutter/material.dart';
import 'package:website/homepage/home_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperEditor - A supercharged rich text editor for Flutter',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Aeonik'),
      home: const HomePage(),
    );
  }
}
