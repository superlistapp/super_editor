import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/core/document_render_pipeline.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("Document render pipeline", () {
    group("computes component metadata", () {
      test("without component configuration", () {
        final doc = _createSingleParagraphDocument();

        final pipeline = DocumentRenderPipeline(
          metadataFactory: _TestMetadataFactory(),
          metadataConfiguration: _NoComponentConfiguration(),
        );

        pipeline.pump(doc);

        final metadata = pipeline.componentsMetadata;
        expect(metadata.length, 1);
        expect(metadata.first, isA<_ParagraphComponentMetadata>());
        final paragraphComponentMetadata = metadata.first as _ParagraphComponentMetadata;
        expect(paragraphComponentMetadata.text, (doc.nodes.first as ParagraphNode).text);
      });

      test("with component configuration", () {
        final doc = _createSingleImageDocument();

        final pipeline = DocumentRenderPipeline(
          metadataFactory: _TestMetadataFactory(),
          metadataConfiguration: _TestComponentConfiguration(),
        );

        pipeline.pump(doc);

        final metadata = pipeline.componentsMetadata;
        expect(metadata.length, 1);
        expect(metadata.first, isA<_ImageComponentMetadata>());
        final imageComponentMetadata = metadata.first as _ImageComponentMetadata;
        expect(imageComponentMetadata.maxWidth, double.infinity);
      });

      test("with multiple pumps", () {
        final pipeline = DocumentRenderPipeline(
          metadataFactory: _TestMetadataFactory(),
          metadataConfiguration: _NoComponentConfiguration(),
        );

        // First pump
        pipeline.pump(
          _createSingleParagraphDocument(),
        );

        // Expect first pump to create a paragraph component metadata
        final metadata1 = pipeline.componentsMetadata;
        expect(metadata1.length, 1);
        expect(metadata1.first, isA<_ParagraphComponentMetadata>());

        // Second pump.
        pipeline.pump(
          _createSingleImageDocument(),
        );

        // Expect second pump to create an image component metadata
        final metadata2 = pipeline.componentsMetadata;
        expect(metadata2.length, 1);
        expect(metadata2.first, isA<_ImageComponentMetadata>());
      });

      // TODO:
    });

    group("notifies listeners", () {
      // TODO:
    });
  });
}

Document _createSingleParagraphDocument() => MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText(text: "Hello, world!")),
      ],
    );

Document _createSingleImageDocument() => MutableDocument(
      nodes: [
        ImageNode(id: "1", imageUrl: "http://fakeimage.com"),
      ],
    );

class _TestMetadataFactory implements ComponentMetadataFactory {
  @override
  ComponentMetadata createComponentConfig(DocumentNode node) {
    if (node is ParagraphNode) {
      return _ParagraphComponentMetadata(nodeId: node.id, text: node.text);
    }
    if (node is ImageNode) {
      return _ImageComponentMetadata(nodeId: node.id, url: node.imageUrl);
    }

    throw Exception("Unknown DocumentNode type: ${node.runtimeType}");
  }
}

class _NoComponentConfiguration implements ComponentConfiguration {
  @override
  ComponentMetadata configureComponentMetadata(
      Document document, DocumentNode node, ComponentMetadata componentMetadata) {
    return componentMetadata;
  }
}

class _TestComponentConfiguration implements ComponentConfiguration {
  @override
  ComponentMetadata configureComponentMetadata(
      Document document, DocumentNode node, ComponentMetadata componentMetadata) {
    if (componentMetadata is _ImageComponentMetadata) {
      return componentMetadata.copyWith(
        maxWidth: double.infinity,
      );
    }

    return componentMetadata;
  }
}

class _ParagraphComponentMetadata implements ComponentMetadata {
  const _ParagraphComponentMetadata({
    required this.nodeId,
    required this.text,
  });

  @override
  final String nodeId;

  final AttributedText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ParagraphComponentMetadata &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          text == other.text;

  @override
  int get hashCode => nodeId.hashCode ^ text.hashCode;
}

class _ImageComponentMetadata implements ComponentMetadata {
  const _ImageComponentMetadata({
    required this.nodeId,
    required this.url,
    this.maxWidth,
  });

  @override
  final String nodeId;

  final String url;

  final double? maxWidth;

  _ImageComponentMetadata copyWith({
    String? url,
    double? maxWidth,
  }) {
    return _ImageComponentMetadata(
      nodeId: nodeId,
      url: url ?? this.url,
      maxWidth: maxWidth ?? this.maxWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ImageComponentMetadata &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          url == other.url &&
          maxWidth == other.maxWidth;

  @override
  int get hashCode => nodeId.hashCode ^ url.hashCode ^ maxWidth.hashCode;
}
