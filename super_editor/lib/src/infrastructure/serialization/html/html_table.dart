import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/src/default_editor/table.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/serialization/html/html_inline_text_styles.dart';

String? defaultTableToHtmlSerializer(
  Document document,
  DocumentNode node,
  NodeSelection? selection,
  InlineHtmlSerializerChain inlineSerializers,
) {
  if (node is! TableBlockNode) {
    return null;
  }
  if (selection != null) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      // We don't know how to handle this selection type.
      return null;
    }
    if (selection.isCollapsed) {
      // This selection doesn't include the table - it's a collapsed selection
      // either on the upstream or downstream edge.
      return null;
    }
  }

  return node.toHtml(document, inlineSerializers);
}

extension TableBlockNodeToHtml on TableBlockNode {
  String toHtml(Document document, InlineHtmlSerializerChain inlineSerializers) {
    final htmlBuffer = StringBuffer();
    htmlBuffer.write('<table>');
    if (rows.isNotEmpty) {
      final headerRow = rows.first;
      htmlBuffer.write('<thead>');
      htmlBuffer.write('<tr>');
      for (final cell in headerRow) {
        final cellContent = cell.text.toHtml(
          serializers: inlineSerializers,
        );
        htmlBuffer.write('<th${_getTextAlignAttribute(cell)}>$cellContent</th>');
      }
      htmlBuffer.write('</tr>');
      htmlBuffer.write('</thead>');

      if (rows.length > 1) {
        htmlBuffer.write('<tbody>');
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          htmlBuffer.write('<tr>');
          for (final cell in row) {
            final cellContent = cell.text.toHtml(
              serializers: inlineSerializers,
            );
            htmlBuffer.write('<td${_getTextAlignAttribute(cell)}>$cellContent</td>');
          }
          htmlBuffer.write('</tr>');
        }
        htmlBuffer.write('</tbody>');
      }
    }
    htmlBuffer.write('</table>');
    return htmlBuffer.toString();
  }

  String _getTextAlignAttribute(TextNode cell) {
    final textAlign = cell.getMetadataValue('textAlign');
    if (textAlign == TextAlign.left) {
      // Default alignment is left, so we don't need to specify it.
      return '';
    }
    final textAlignString = switch (textAlign) {
      TextAlign.center => 'center',
      TextAlign.right => 'right',
      _ => 'left',
    };
    return textAlign != null ? ' style="text-align:$textAlignString"' : '';
  }
}
