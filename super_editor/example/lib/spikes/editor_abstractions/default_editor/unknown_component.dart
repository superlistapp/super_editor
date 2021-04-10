import 'package:example/spikes/editor_abstractions/core/document_layout.dart';
import 'package:flutter/widgets.dart';

Widget unknownComponentBuilder(ComponentContext componentContext) {
  return SizedBox(
    key: componentContext.componentKey,
    width: double.infinity,
    height: 100,
    child: Placeholder(),
  );
}

// TODO: turn into real component in default editor
class UnknownComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Placeholder(),
    );
  }
}
