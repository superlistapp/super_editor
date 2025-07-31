import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_markdown/src/markdown_inline_parser.dart';

/// Converts a [md.Element] representing a table into a [MarkdownTable].
///
/// The [md.Element] must have a `table` tag.
///
/// Throws an exception if the element is not a valid table structure.
MarkdownTable convertTable(md.Element element) {
  if (element.tag != 'table') {
    throw Exception('Cannot parse a table from an element with tag "${element.tag}"');
  }

  if (element.children == null || element.children!.isEmpty) {
    throw Exception('A table must have at least one child element');
  }

  final headers = <MarkdownColumn>[];
  final rows = <List<AttributedText>>[];

  final headerElement = element.children![0];
  if (headerElement is! md.Element || headerElement.tag != 'thead') {
    throw Exception('Table header must be a <thead> element');
  }
  if (headerElement.children == null || headerElement.children!.isEmpty) {
    throw Exception('Table header must have a row');
  }

  final headerRow = headerElement.children![0];
  if (headerRow is! md.Element || headerRow.tag != 'tr') {
    throw Exception('Table header row must be a <tr> element');
  }

  for (final headerCell in headerRow.children!) {
    if (headerCell is! md.Element || headerCell.tag != 'th') {
      throw Exception('Table header cells must be <th> elements');
    }
    headers.add(
      MarkdownColumn(
        header: parseInlineMarkdown(headerCell.textContent).attributedText,
        textAlign: switch (headerCell.attributes['align']) {
          'left' => TextAlign.left,
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          _ => TextAlign.left,
        },
      ),
    );
  }

  if (element.children!.length >= 2) {
    // The table contains the table body element.
    final bodyElement = element.children![1];
    if (bodyElement is! md.Element || bodyElement.tag != 'tbody') {
      throw Exception('Table body must be a <tbody> element');
    }

    for (final rowElement in bodyElement.children!) {
      if (rowElement is! md.Element || rowElement.tag != 'tr') {
        throw Exception('Table body rows must be <tr> elements');
      }

      final row = <AttributedText>[];
      for (final cellElement in rowElement.children!) {
        if (cellElement is! md.Element || cellElement.tag != 'td') {
          throw Exception('Table body cells must be <td> elements');
        }
        row.add(parseInlineMarkdown(cellElement.textContent).attributedText);
      }
      rows.add(row);
    }
  }

  return MarkdownTable(
    headers: headers,
    rows: rows,
  );
}

class MarkdownTable {
  MarkdownTable({
    required this.headers,
    required this.rows,
  });

  final List<MarkdownColumn> headers;
  final List<List<AttributedText>> rows;

  @override
  String toString() {
    return '[MarkdownTable] - headers: $headers, rows: $rows';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownTable && //
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(headers, other.headers) &&
          const DeepCollectionEquality().equals(rows, other.rows);

  @override
  int get hashCode => headers.hashCode ^ rows.hashCode;
}

class MarkdownColumn {
  MarkdownColumn({
    required this.header,
    this.textAlign = TextAlign.left,
  });

  final AttributedText header;
  final TextAlign textAlign;

  @override
  String toString() {
    return '[MarkdownColumn] - header: $header, textAlign: $textAlign';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownColumn &&
          runtimeType == other.runtimeType &&
          header == other.header &&
          textAlign == other.textAlign;

  @override
  int get hashCode => header.hashCode ^ textAlign.hashCode;
}
