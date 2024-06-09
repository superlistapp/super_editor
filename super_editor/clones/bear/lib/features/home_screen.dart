import 'package:bear/infrastructure/editor/editor.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(),
          _buildNoteList(),
          _buildDivider(),
          Expanded(
            child: _buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      width: 180,
      color: const Color(0xFF303033),
    );
  }

  Widget _buildNoteList() {
    return Container(
      width: 285,
      color: Colors.white,
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      color: const Color(0xFFDDDDDD),
    );
  }

  Widget _buildEditor() {
    return TextEditor();
  }
}
