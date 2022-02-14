import 'package:flutter/widgets.dart';

import '_presenter.dart';

Widget newUnknownComponentBuilder(
    SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentMetadata) {
  return SizedBox(
    key: componentContext.componentKey,
    width: double.infinity,
    height: 100,
    child: const Placeholder(),
  );
}
