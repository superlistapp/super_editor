import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';

import '../core/document.dart';
import 'box_component.dart';
import 'layout_single_column/layout_single_column.dart';

/// [DocumentNode] that represents an image at a URL.
class ImageNode extends BlockNode with ChangeNotifier {
  ImageNode({
    required this.id,
    required String imageUrl,
    String altText = '',
    Map<String, dynamic>? metadata,
  })  : _imageUrl = imageUrl,
        _altText = altText {
    this.metadata = metadata;

    putMetadataValue("blockType", const NamedAttribution("image"));
  }

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

class ImageComponentBuilder implements ComponentBuilder {
  const ImageComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! ImageNode) {
      return null;
    }

    return ImageComponentViewModel(
      nodeId: node.id,
      imageUrl: node.imageUrl,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ImageComponentViewModel) {
      return null;
    }

    return ImageComponent(
      componentKey: componentContext.componentKey,
      imageUrl: componentViewModel.imageUrl,
      selection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
    );
  }
}

class ImageComponentViewModel extends SingleColumnLayoutComponentViewModel {
  ImageComponentViewModel({
    required String nodeId,
    double? maxWidth,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    required this.imageUrl,
    this.selection,
    required this.selectionColor,
  }) : super(nodeId: nodeId, maxWidth: maxWidth, padding: padding);

  String imageUrl;
  UpstreamDownstreamNodeSelection? selection;
  Color selectionColor;

  @override
  ImageComponentViewModel copy() {
    return ImageComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      imageUrl: imageUrl,
      selection: selection,
      selectionColor: selectionColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ImageComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          imageUrl == other.imageUrl &&
          selection == other.selection &&
          selectionColor == other.selectionColor;

  @override
  int get hashCode =>
      super.hashCode ^ nodeId.hashCode ^ imageUrl.hashCode ^ selection.hashCode ^ selectionColor.hashCode;
}

/// Displays an image in a document.
class ImageComponent extends StatelessWidget {
  const ImageComponent({
    Key? key,
    required this.componentKey,
    required this.imageUrl,
    this.selectionColor = Colors.blue,
    this.selection,
    this.imageBuilder,
  }) : super(key: key);

  final GlobalKey componentKey;
  final String imageUrl;
  final Color selectionColor;
  final UpstreamDownstreamNodeSelection? selection;

  /// Called to obtain the inner image for the given [imageUrl].
  ///
  /// This builder is used in tests to 'mock' an [Image], avoiding accessing the network.
  ///
  /// If [imageBuilder] is `null` an [Image] is used.
  final Widget Function(BuildContext context, String imageUrl)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      hitTestBehavior: HitTestBehavior.translucent,
      child: IgnorePointer(
        child: Center(
          child: SelectableBox(
            selection: selection,
            selectionColor: selectionColor,
            child: BoxComponent(
              key: componentKey,
              child: imageBuilder != null
                  ? imageBuilder!(context, imageUrl)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
