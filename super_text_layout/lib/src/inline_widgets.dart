/// A placeholder to be given to an `AttributedText`, and later replaced
/// within an inline network image.
class InlineNetworkImagePlaceholder {
  const InlineNetworkImagePlaceholder(this.url);

  final String url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineNetworkImagePlaceholder && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// A placeholder to be given to an `AttributedText`, and later replaced
/// within an inline asset image.
class InlineAssetImagePlaceholder {
  const InlineAssetImagePlaceholder(this.assetPath);

  final String assetPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineAssetImagePlaceholder && runtimeType == other.runtimeType && assetPath == other.assetPath;

  @override
  int get hashCode => assetPath.hashCode;
}
