// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:flutter/material.dart';
import 'package:website/shims/dart_ui.dart' as ui;

class EditorVideoShowcase extends StatefulWidget {
  const EditorVideoShowcase({required this.url, required this.isCompact});
  final String url;
  final bool isCompact;

  @override
  _EditorVideoShowcaseState createState() => _EditorVideoShowcaseState();
}

class _EditorVideoShowcaseState extends State<EditorVideoShowcase> {
  @override
  void initState() {
    super.initState();
    ui.platformViewRegistry.registerViewFactory('youtube-video', (viewId) {
      return IFrameElement()
        ..width = '560'
        ..height = '315'
        // ignore: unsafe_html
        ..src = widget.url
        ..title = "YouTube video player"
        ..style.border = 'none';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: SelectableText(
              'See it in action',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 38,
                height: 46 / 38,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: widget.isCompact ? 22 : 37),
          Container(
            constraints: const BoxConstraints(maxWidth: 544).tighten(height: widget.isCompact ? 212 : 307),
            margin: const EdgeInsets.only(top: 44),
            decoration: BoxDecoration(
              color: const Color(0xFF053239),
              borderRadius: BorderRadius.circular(30),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: const HtmlElementView(viewType: 'youtube-video'),
            ),
          ),
        ],
      ),
    );
  }
}
