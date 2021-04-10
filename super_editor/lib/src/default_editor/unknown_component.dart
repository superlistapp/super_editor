import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_layout.dart';

/// Builds an `UnknownComponent` for any given `componentContext`.
///
/// This builder always returns an `UnknownComponent`. It never
/// returns `null`.
Widget unknownComponentBuilder(ComponentContext componentContext) {
  return SizedBox(
    key: componentContext.componentKey,
    width: double.infinity,
    height: 100,
    child: Placeholder(),
  );
}

/// Displays a `Placeholder` widget within a document layout.
///
/// An `UnknownComponent` is intended to represent any
/// `DocumentNode` for which there is no corresponding
/// component builder.
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
