import 'package:flutter/painting.dart';
import 'package:super_editor/src/core/styles.dart';

import '../../core/document.dart';
import '_presenter.dart';

/// Style phase that applies a given [Stylesheet] to the document view model.
class SingleColumnStylesheetStyler extends SingleColumnLayoutStylePhase {
  SingleColumnStylesheetStyler({
    required Stylesheet stylesheet,
  }) : _stylesheet = stylesheet;

  final Stylesheet _stylesheet;

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    return SingleColumnLayoutViewModel(
      padding: _stylesheet.documentPadding ?? viewModel.padding,
      componentViewModels: [
        for (final componentViewModel in viewModel.componentViewModels)
          _styleComponent(
            document,
            document.getNodeById(componentViewModel.nodeId)!,
            componentViewModel.copy(),
          ),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _styleComponent(
      Document document,
      DocumentNode node,
      SingleColumnLayoutComponentViewModel viewModel,
      ) {
    // Combine all applicable style rules into a single set of styles
    // for this component.
    final aggregateStyles = <String, dynamic>{
      "inlineTextStyler": _stylesheet.inlineTextStyler,
    };
    for (final rule in _stylesheet.rules) {
      if (rule.selector.matches(document, node)) {
        _mergeStyles(
          existingStyles: aggregateStyles,
          newStyles: rule.styler(document, node),
        );
      }
    }

    viewModel.applyStyles(aggregateStyles);

    return viewModel;
  }

  void _mergeStyles({
    required Map<String, dynamic> existingStyles,
    required Map<String, dynamic> newStyles,
  }) {
    for (final entry in newStyles.entries) {
      if (existingStyles.containsKey(entry.key)) {
        // Try to merge. If we can't, then overwrite.
        final oldValue = existingStyles[entry.key];
        final newValue = entry.value;

        if (oldValue is TextStyle && newValue is TextStyle) {
          existingStyles[entry.key] = oldValue.merge(newValue);
        } else if (oldValue is CascadingPadding && newValue is CascadingPadding) {
          existingStyles[entry.key] = newValue.applyOnTopOf(oldValue);
        }
      } else {
        // This is a new entry, just set it.
        existingStyles[entry.key] = entry.value;
      }
    }
  }
}