import 'package:flutter/material.dart';
import 'package:super_editor/super_text_field.dart';

class TextFieldScrollableDemo extends StatefulWidget {
  const TextFieldScrollableDemo({super.key});

  @override
  State<TextFieldScrollableDemo> createState() => _TextFieldScrollableDemoState();
}

class _TextFieldScrollableDemoState extends State<TextFieldScrollableDemo> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(50),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SuperDesktopTextField(
              minLines: 5,
              maxLines: 5,
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
              textStyleBuilder: (attributions) {
                return TextStyle(
                  color: Colors.black,
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
        ),
        SliverList.builder(
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(index.toString()),
            );
          },
        ),
      ],
    );
  }
}
