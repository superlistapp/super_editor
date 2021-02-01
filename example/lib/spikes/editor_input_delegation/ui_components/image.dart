import 'package:flutter/widgets.dart';

/// Displays an image in a document.
class ImageComponent extends StatelessWidget {
  const ImageComponent({
    Key key,
    @required this.imageUrl,
  }) : super(key: key);

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.network(
        imageUrl,
        key: key,
        fit: BoxFit.contain,
      ),
    );
  }
}
