import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/default_editor/text.dart';

/// Delegate that may choose to react to user taps in a document.
abstract class DocumentTapDelegate {
  const DocumentTapDelegate();

  /// Called by the document's gesture system when the user taps on a
  /// piece of content.
  ///
  /// Return `true` to prevent standard gesture response, such as clearing
  /// an expanded selection, or moving the caret. Return `false` to let the
  /// standard gesture response occur. The delegate is permitted to take
  /// its own action, even if it allows the standard gesture response to occur.
  bool onTap({
    required Document document,
    required DocumentNode node,
    required DocumentComponent component,
    required Offset componentTapOffset,
  });
}

abstract class DocumentTapOnTextDelegate implements DocumentTapDelegate {
  const DocumentTapOnTextDelegate();

  @override
  bool onTap({
    required Document document,
    required DocumentNode node,
    required DocumentComponent component,
    required Offset componentTapOffset,
  }) {
    if (node is! TextNode) {
      return false;
    }

    final tappedTextPosition = component.getPositionAtOffset(componentTapOffset) as TextNodePosition?;
    if (tappedTextPosition == null) {
      return false;
    }

    final tappedAttributions = node.text.getAllAttributionsAt(tappedTextPosition.offset);

    return onTextTap(
      document: document,
      node: node,
      component: component,
      componentTapOffset: componentTapOffset,
      tappedTextPosition: tappedTextPosition,
      tappedAttributions: tappedAttributions,
    );
  }

  /// Called by the document gesture system when the user taps on text content.
  ///
  /// Return `true` to prevent standard gesture response, such as clearing
  /// an expanded selection, or moving the caret. Return `false` to let the
  /// standard gesture response occur. The delegate is permitted to take
  /// its own action, even if it allows the standard gesture response to occur.
  bool onTextTap({
    required Document document,
    required DocumentNode node,
    required DocumentComponent component,
    required Offset componentTapOffset,
    required TextPosition tappedTextPosition,
    required Set<Attribution> tappedAttributions,
  });
}
