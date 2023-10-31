import 'package:example/demos/supertextfield/demo_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_text_field.dart';

class TextFieldInsideSliversDemo extends StatefulWidget {
  const TextFieldInsideSliversDemo({super.key});

  @override
  State<TextFieldInsideSliversDemo> createState() => _TextFieldInsideSliversDemoState();
}

class _TextFieldInsideSliversDemoState extends State<TextFieldInsideSliversDemo> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            width: double.maxFinite,
            child: Placeholder(
              child: Center(
                child: Text("Content"),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SuperDesktopTextField(
              minLines: 5, // Provides sufficient space to test out textfields scrolling behaviour
              // properly.
              maxLines: 5,
              textStyleBuilder: demoTextStyleBuilder,
              decorationBuilder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: child,
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: double.maxFinite,
            child: Placeholder(
              child: Center(
                child: Text("Content"),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
