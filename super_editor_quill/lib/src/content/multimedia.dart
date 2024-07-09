import 'package:flutter/cupertino.dart';
import 'package:super_editor/super_editor.dart';

/// [DocumentNode] that represents a video at a URL.
class VideoNode extends UrlMediaNode {
  static const videoAttribution = NamedAttribution("video");

  VideoNode({
    required super.id,
    required super.url,
    super.altText = '',
    super.blockAttribution = videoAttribution,
  });

  @override
  DocumentNode copy() {
    return VideoNode(id: id, url: url, altText: altText, blockAttribution: blockquoteAttribution);
  }
}

/// [DocumentNode] that represents an audio source at a URL.
class AudioNode extends UrlMediaNode {
  static const audioAttribution = NamedAttribution("audio");

  AudioNode({
    required super.id,
    required super.url,
    super.altText = '',
    super.blockAttribution = audioAttribution,
  });

  @override
  DocumentNode copy() {
    return AudioNode(id: id, url: url, altText: altText, blockAttribution: blockquoteAttribution);
  }
}

/// [DocumentNode] that represents a file at a URL.
class FileNode extends UrlMediaNode {
  static const fileAttribution = NamedAttribution("file");

  FileNode({
    required super.id,
    required super.url,
    super.altText = '',
    super.blockAttribution = fileAttribution,
  });

  @override
  DocumentNode copy() {
    return FileNode(id: id, url: url, altText: altText, blockAttribution: blockquoteAttribution);
  }
}

/// [DocumentNode] that represents a media source that exists a given [url].
class UrlMediaNode extends BlockNode with ChangeNotifier {
  UrlMediaNode({
    required this.id,
    required String url,
    String altText = '',
    required Attribution blockAttribution,
    Map<String, dynamic>? metadata,
  })  : _url = url,
        _altText = altText {
    this.metadata = metadata;
    putMetadataValue("blockType", blockAttribution);
  }

  @override
  final String id;

  String get url => _url;
  String _url;
  set url(String newUrl) {
    if (newUrl != _url) {
      _url = newUrl;
      notifyListeners();
    }
  }

  String get altText => _altText;
  String _altText;
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

    return !selection.isCollapsed ? _url : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is UrlMediaNode && url == other.url && altText == other.altText;
  }

  @override
  DocumentNode copy() {
    return UrlMediaNode(
      id: id,
      url: url,
      altText: altText,
      blockAttribution: getMetadataValue("blockType"),
      metadata: metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlMediaNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _url == other._url &&
          _altText == other._altText;

  @override
  int get hashCode => id.hashCode ^ _url.hashCode ^ _altText.hashCode;
}
