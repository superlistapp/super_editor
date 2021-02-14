import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../core/document.dart';
import 'box_component.dart';

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

  BinaryPosition get beginningPosition => BinaryPosition.included();

  BinaryPosition get endPosition => BinaryPosition.included();

  BinarySelection computeSelection({
    @required dynamic base,
    @required dynamic extent,
  }) {
    return BinarySelection.all();
  }

  @override
  String copyContent(dynamic selection) {
    assert(selection is BinarySelection);

    return (selection as BinarySelection).position == BinaryPosition.included() ? _imageUrl : null;
  }
}

/// Displays an image in a document.
class ImageComponent extends StatelessWidget {
  const ImageComponent({
    Key key,
    @required this.componentKey,
    @required this.imageUrl,
    this.selectedColor = Colors.blue,
    this.isSelected = false,
  }) : super(key: key);

  final GlobalKey componentKey;
  final String imageUrl;
  final Color selectedColor;
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
              color: isSelected ? selectedColor : Colors.transparent,
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
