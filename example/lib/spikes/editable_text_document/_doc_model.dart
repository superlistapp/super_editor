import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// A representation of a rich text document as a list of
/// `DocumentContent`s.

class Document {
  Document({
    List<DocumentContent> content,
  }) : _content = content != null ? List.from(content) : [];

  final List<DocumentContent> _content;
  List<DocumentContent> get content => _content;
}

abstract class DocumentContent {
  // Marker interface (for now)
}

class DocumentTitle implements DocumentContent {
  DocumentTitle({
    @required this.text,
  });

  final String text;
}

class DocumentParagraph implements DocumentContent {
  DocumentParagraph({
    @required this.text,
  });

  final String text;
}

class DocumentListItem implements DocumentContent {
  DocumentListItem({
    @required this.text,
  });

  final String text;
}

class DocumentImage implements DocumentContent {
  DocumentImage({
    @required this.imageProvider,
  });

  final ImageProvider imageProvider;
}

class DocumentHorizontalRule implements DocumentContent {}
