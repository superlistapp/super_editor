import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_richtext/flutter_richtext.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'styles.dart';

/// [DocumentNode] that represents an image at a URL.
class ImageNode with ChangeNotifier implements DocumentNode {
  ImageNode({
    required this.id,
    required String imageUrl,
  }) : _imageUrl = imageUrl;

  final String id;

  String _imageUrl;
  String get imageUrl => _imageUrl;
  set imageUrl(String newImageUrl) {
    if (newImageUrl != _imageUrl) {
      _imageUrl = newImageUrl;
      notifyListeners();
    }
  }

  BinaryPosition get beginningPosition => BinaryPosition.included();

  BinaryPosition get endPosition => BinaryPosition.included();

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

    return selection.position == BinaryPosition.included() ? _imageUrl : null;
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
