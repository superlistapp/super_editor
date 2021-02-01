import 'package:flutter/foundation.dart';

import 'rich_text_document.dart';

class TextNode with ChangeNotifier implements DocumentNode {
  TextNode({
    @required this.id,
    String text = '',
  }) : _text = text;

  final String id;

  String _text;
  String get text => _text;
  set text(String newText) {
    if (newText != _text) {
      print('Text changed. Notifying listeners.');
      _text = newText;
      notifyListeners();
    }
  }

  bool tryToCombineWithOtherNode(DocumentNode other) {
    // TODO: need to be able to list items into paragraphs somehow.
    if (other is! TextNode) {
      return false;
    }

    final otherParagraph = other as TextNode;
    this.text += otherParagraph.text;
    return true;
  }
}

class UnorderedListItemNode with ChangeNotifier implements DocumentNode {
  UnorderedListItemNode({
    @required this.id,
    String text = '',
    int indent = 0,
  })  : _text = text,
        _indent = indent;

  final String id;

  int _indent;
  int get indent => _indent;
  set indent(int newIndent) {
    if (newIndent != _indent) {
      _indent = newIndent;
      notifyListeners();
    }
  }

  String _text;
  String get text => _text;
  set text(String newText) {
    if (newText != _text) {
      print('Unordered list item changed. Notifying listeners.');
      _text = newText;
      notifyListeners();
    }
  }

  bool tryToCombineWithOtherNode(DocumentNode other) {
    // TODO: implement node combinations
    print('WARNING: UnorderedListItemNode combining is not yet implemented.');
    return false;
  }
}

class OrderedListItemNode with ChangeNotifier implements DocumentNode {
  OrderedListItemNode({
    @required this.id,
    String text = '',
    int indent = 0,
  })  : _text = text,
        _indent = indent;

  final String id;

  int _indent;
  int get indent => _indent;
  set indent(int newIndent) {
    if (newIndent != _indent) {
      _indent = newIndent;
      notifyListeners();
    }
  }

  String _text;
  String get text => _text;
  set text(String newText) {
    if (newText != _text) {
      print('Ordered list item changed. Notifying listeners.');
      _text = newText;
      notifyListeners();
    }
  }

  bool tryToCombineWithOtherNode(DocumentNode other) {
    // TODO: implement node combinations
    print('WARNING: OrderedListItemNode combining is not yet implemented.');
    return false;
  }
}

class ImageNode with ChangeNotifier implements DocumentNode {
  ImageNode({
    @required this.id,
    @required String imageUrl,
  }) : _imageUrl = imageUrl;

  final String id;

  String _imageUrl;
  String get imageUrl => _imageUrl;
  set imageUrl(String newImageUrl) {
    if (newImageUrl != _imageUrl) {
      print('Paragraph changed. Notifying listeners.');
      _imageUrl = newImageUrl;
      notifyListeners();
    }
  }

  bool tryToCombineWithOtherNode(DocumentNode other) {
    // Images can't be combined with anything else.
    return false;
  }
}
