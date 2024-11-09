import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class MobileChatDemo extends StatefulWidget {
  const MobileChatDemo({super.key});

  @override
  State<MobileChatDemo> createState() => _MobileChatDemoState();
}

class _MobileChatDemoState extends State<MobileChatDemo> {
  late final Editor _editor;

  @override
  void initState() {
    super.initState();

    final document = MutableDocument.empty();
    final composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: document, composer: composer);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: Colors.white),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildCommentEditor(),
        ),
      ],
    );
  }

  Widget _buildCommentEditor() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(width: 1, color: Colors.grey),
              left: BorderSide(width: 1, color: Colors.grey),
              right: BorderSide(width: 1, color: Colors.grey),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.075),
                blurRadius: 8,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: SuperEditor(
            editor: _editor,
            shrinkWrap: true,
            stylesheet: _chatStylesheet,
          ),
        ),
      ],
    );
  }
}

final _chatStylesheet = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(
      BlockSelector.all,
      (doc, docNode) {
        return {
          Styles.maxWidth: null,
          Styles.padding: const CascadingPadding.symmetric(horizontal: 24),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.first(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(top: 12),
        };
      },
    ),
    StyleRule(
      BlockSelector.all.last(),
      (doc, docNode) {
        return {
          Styles.padding: const CascadingPadding.only(bottom: 12),
        };
      },
    ),
  ],
);
