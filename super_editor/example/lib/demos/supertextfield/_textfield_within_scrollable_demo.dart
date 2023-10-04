import 'package:flutter/material.dart';
import 'package:super_editor/super_text_field.dart';

class TextFieldWithinScrollableDemo extends StatefulWidget {
  const TextFieldWithinScrollableDemo({super.key});

  @override
  State<TextFieldWithinScrollableDemo> createState() => _TextFieldWithinScrollableDemoState();
}

class _TextFieldWithinScrollableDemoState extends State<TextFieldWithinScrollableDemo> {
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
