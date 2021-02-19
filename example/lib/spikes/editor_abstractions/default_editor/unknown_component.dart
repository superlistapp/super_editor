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
