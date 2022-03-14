import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '../core/document.dart';
import 'layout_single_column/layout_single_column.dart';

class UnknownComponentBuilder implements ComponentBuilder {
  const UnknownComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    return null;
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    editorLayoutLog.warning("Building component widget for unknown component: $componentViewModel");
    return SizedBox(
      key: componentContext.componentKey,
      width: double.infinity,
      height: 100,
      child: const Placeholder(),
    );
  }
}

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
