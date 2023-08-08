import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/default_editor/super_editor.dart';
import 'package:super_editor/src/infrastructure/attribution_layout_bounds.dart';

class AttributedTextBoundsOverlay implements DocumentLayerBuilder {
  const AttributedTextBoundsOverlay({
    required this.selector,
    required this.builder,
  });

  final AttributionBoundsSelector selector;
  final AttributionBoundsBuilder builder;

  @override
  Widget build(BuildContext context, SuperEditorContext editContext) {
    return AttributionBounds(
      document: editContext.document,
      layout: editContext.documentLayout,
      selector: selector,
      builder: builder,
    );
  }
}
