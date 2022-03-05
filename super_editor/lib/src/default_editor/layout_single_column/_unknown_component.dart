import 'package:flutter/widgets.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

import '_presenter.dart';

Widget newUnknownComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
  editorLayoutLog.warning("Building component widget for unknown component: $componentViewModel");
  return SizedBox(
    key: componentContext.componentKey,
    width: double.infinity,
    height: 100,
    child: const Placeholder(),
  );
}
