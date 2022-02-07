import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';

import '_presenter.dart';

Widget newUnknownComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, ComponentViewModel componentMetadata) {
  return SizedBox(
    key: componentContext.componentKey,
    width: double.infinity,
    height: 100,
    child: const Placeholder(),
  );
}
