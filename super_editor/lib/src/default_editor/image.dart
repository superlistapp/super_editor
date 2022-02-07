import 'package:flutter/material.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '../core/document.dart';
import 'box_component.dart';

/// [DocumentNode] that represents an image at a URL.
class ImageNode extends BlockNode with ChangeNotifier {
  ImageNode({
    required this.id,
    required String imageUrl,
    String altText = '',
  })  : _imageUrl = imageUrl,
        _altText = altText;

  @override
  final String id;

  String _imageUrl;
  String get imageUrl => _imageUrl;
  set imageUrl(String newImageUrl) {
    if (newImageUrl != _imageUrl) {
      _imageUrl = newImageUrl;
      notifyListeners();
    }
  }

  String _altText;
  String get altText => _altText;
  set altText(String newAltText) {
    if (newAltText != _altText) {
      _altText = newAltText;
      notifyListeners();
    }
  }

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception('ImageNode can only copy content from a UpstreamDownstreamNodeSelection.');
    }

    return !selection.isCollapsed ? _imageUrl : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is ImageNode && imageUrl == other.imageUrl && altText == other.altText;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _imageUrl == other._imageUrl &&
          _altText == other._altText;

  @override
  int get hashCode => id.hashCode ^ _imageUrl.hashCode ^ _altText.hashCode;
}

/// Displays an image in a document.
class ImageComponent extends StatelessWidget {
  const ImageComponent({
    Key? key,
    required this.componentKey,
    required this.imageUrl,
    this.selectionColor = Colors.blue,
    this.selection,
    required this.caretColor,
    this.showCaret = false,
  }) : super(key: key);

  final GlobalKey componentKey;
  final String imageUrl;
  final Color selectionColor;
  final UpstreamDownstreamNodeSelection? selection;
  final Color caretColor;
  final bool showCaret;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SelectableBox(
        selection: selection,
        selectionColor: selectionColor,
        caretColor: caretColor,
        showCaret: showCaret,
        child: BoxComponent(
          key: componentKey,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
