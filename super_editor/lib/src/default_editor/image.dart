import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'styles.dart';

/// [DocumentNode] that represents an image at a URL.
class ImageNode with ChangeNotifier implements DocumentNode {
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
  BinaryNodePosition get beginningPosition => BinaryNodePosition.included();

  @override
  BinaryNodePosition get endPosition => BinaryNodePosition.included();

  @override
  NodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position2 but received a ${position2.runtimeType}');
    }

    // BinaryNodePosition's don't disambiguate between upstream and downstream so
    // it doesn't matter which one we return.
    return position1;
  }

  @override
  NodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! BinaryNodePosition) {
      throw Exception('Expected a BinaryNodePosition for position2 but received a ${position2.runtimeType}');
    }

    // BinaryNodePosition's don't disambiguate between upstream and downstream so
    // it doesn't matter which one we return.
    return position1;
  }

  @override
  BinarySelection computeSelection({
    @required dynamic base,
    @required dynamic extent,
  }) {
    return BinarySelection.all();
  }

  @override
  String? copyContent(dynamic selection) {
    if (selection is! BinarySelection) {
      throw Exception('ImageNode can only copy content from a BinarySelection.');
    }

    return selection.position == BinaryNodePosition.included() ? _imageUrl : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is ImageNode && imageUrl == other.imageUrl && altText == other.altText;
  }
}

/// Displays an image in a document.
class ImageComponent extends StatelessWidget {
  const ImageComponent({
    Key? key,
    required this.componentKey,
    required this.imageUrl,
    this.selectionColor = Colors.blue,
    this.isSelected = false,
  }) : super(key: key);

  final GlobalKey componentKey;
  final String imageUrl;
  final Color selectionColor;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BoxComponent(
        key: componentKey,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              width: 1,
              color: isSelected ? selectionColor : Colors.transparent,
            ),
          ),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Component builder that returns an [ImageComponent] when
/// [componentContext.documentNode] is an [ImageNode].
Widget? imageBuilder(ComponentContext componentContext) {
  if (componentContext.documentNode is! ImageNode) {
    return null;
  }

  final selection =
      componentContext.nodeSelection == null ? null : componentContext.nodeSelection!.nodeSelection as BinarySelection;
  final isSelected = selection != null && selection.position.isIncluded;

  return ImageComponent(
    componentKey: componentContext.componentKey,
    imageUrl: (componentContext.documentNode as ImageNode).imageUrl,
    isSelected: isSelected,
    selectionColor: (componentContext.extensions[selectionStylesExtensionKey] as SelectionStyle).selectionColor,
  );
}
