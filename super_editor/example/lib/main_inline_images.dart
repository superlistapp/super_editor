import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_text_layout/super_text_layout.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: _InlineImagePage(),
      ),
    ),
  );
}

class _InlineImagePage extends StatefulWidget {
  const _InlineImagePage();

  @override
  State<_InlineImagePage> createState() => _InlineImagePageState();
}

class _InlineImagePageState extends State<_InlineImagePage> {
  late final InlineSpan _richText;

  @override
  void initState() {
    super.initState();
    _styleText();
  }

  void _styleText() {
    final text = AttributedText(
      "Hello, World!",
      null,
      {
        5: InlineNetworkImagePlaceholder(
            "https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExb2gwd2J6bXp1dTRnbGg2MGcyMnF2c3lmNzBiNmo1eHV0MnkzMGZjbSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/F8rZBFylC2W1G/giphy.webp"),
        14: InlineNetworkImagePlaceholder(
            "https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExbDdwM2gwcjNnbGVycXVic2VnamNia2swem1seHNiODk0aXdoenZmcCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/cKKXtt4bzsWuon0EJJ/giphy.webp"),
      },
    );

    _richText = text.computeInlineSpan(
      context,
      (attributions) {
        return TextStyle(
          color: Colors.black,
          fontSize: 18,
        );
      },
      [
        (context, textStyle, placeholder) {
          if (placeholder is InlineNetworkImagePlaceholder) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Container(
                width: 24,
                height: 24,
                color: Colors.black,
                child: Image.network(placeholder.url),
              ),
            );
          }

          return const SizedBox();
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 800,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i <= 15; i += 1) //
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: SuperTextWithSelection.single(
                  richText: _richText,
                  userSelection: UserSelection(
                    selection: TextSelection(baseOffset: 0, extentOffset: i),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
