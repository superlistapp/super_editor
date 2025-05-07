---
title: Export Super Editor to Quill Deltas
contentRenderers:
  - jinja
  - markdown
---
Super Editor supports exporting its document to the Quill Delta format. The process
of going from a Super Editor document to Quill Deltas is known as "serializing" your
Super Editor document.

To get started with serializing Quill documents, add the Super Editor Quill package:

```yaml
dependencies:
  super_editor: any
  super_editor_quill: ^{{ pub.super_editor_quill.version }}
```

The `super_editor_quill` package adds an extension method to `MutableDocument`s, which
serializes the document to Quill Deltas.

To serialize your document to Quill Deltas, call `toQuillDeltas()` on your document:

```dart
final MutableDocument mySuperEditorDocument = getMySuperEditorDocument();

final quillDocument = mySuperEditorDocument.toQuillDeltas();
```

## Custom Blocks, Attributes, and Inline Embeds
It's common among Quill use-cases to extend the Quill Delta format to include new types of
blocks, attributes, and inline embeds. Super Editor Quill allows you to provide your own such
serializers.

Pass your custom serializers to the `toQuillDeltas()` method:

```dart
final quillDocument = mySuperEditorDocument.toQuillDeltas(
  serializers: [
    const MyMathFormulaSerializer(),
    const MyUserTagSerializer(),
    ...defaultDeltaSerializers,
  ],
);
```

### Custom Block Serializers
To serialize a Super Editor `DocumentNode` into a Quill Delta block, implement a
`DeltaSerializer`.

The following hypothetical example implements a Quill serializer for a video block:

```dart
class VideoBlockSerializer implements DeltaSerializer {
  const VideoBlockSerializer();
  
  @override
  bool serialize(DocumentNode node, Delta deltas) {
    if (node is! VideoNode) {
      return false;
    }

    deltas.operations.add(
      Operation.insert({
        "video": node.url,
      }),
    );

    return true;
  }
}
```

### Custom Inline Serializers
Serializing text includes both the serialization of a block (the paragraph), as well as any number of
inline attributes (e.g., bold, italic, links). Therefore, there are no standalone inline serializers.
Instead, to serialize custom inline attributes, you should extend the existing text serializer.

The following hypothetical example extends `TextBlockDeltaSerializer` and adds support for a user tag:

```dart
class MyAppParagraphSerializer extends TextBlockDeltaSerializer {
  @override
  @protected
  Map<String, dynamic> getInlineAttributesFor(Set<Attribution> superEditorAttributions) {
    // Collect any standard Quill Delta attributes that exist in the current
    // span of text.
    final inlineAttributes = super.getInlineAttributesFor(superEditorAttribions);
    
    // This hypothetical example assumes that your editor has the concept
    // of a `UserTagAttribution`.
    final userTag = superEditorAttributions.whereType<UserTagAttribution>().firstOrNull;
    if (userTag != null) {
      // This inline span includes a user tag. Configure the Quill Delta attributes
      // based on our custom specifications.
      inlineAttributes['tag'] = {
        'userId': userTag.id,
        'userName': userTag.name,
      };
    }
    
    return inlineAttributes;
  }
}
```

### Custom Inline Embeds
Currently, Super Editor doesn't support the concept of inline widgets, which means there's no
structure that would yield inline embeds. Therefore, no support currently exists for serializing
inline embeds.

In the future, when Super Editor adjusts the definition of `AttributedText` to support inline
non-text content, `super_editor_quill` will be updated, accordingly.