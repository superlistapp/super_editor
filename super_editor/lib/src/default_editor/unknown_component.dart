import 'package:flutter/widgets.dart';

/// Displays a `Placeholder` widget within a document layout.
///
/// An `UnknownComponent` is intended to represent any
/// `DocumentNode` for which there is no corresponding
/// component builder.
class UnknownComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 54,
      child: Placeholder(),
    );
  }
}
